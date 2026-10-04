// P1-only real two-session proof; fresh blank-password fixture intentionally retained.
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
const database = 'business_platform_cube5_adam_channels_qa';
const args = ['exec', '-i', 'supabase_db_business-platform', 'psql', '-X', '-qAt', '-U', 'postgres', '-d', database, '-v', 'ON_ERROR_STOP=1'];
const operator = 'f9000000-0000-4000-8000-000000000001';
const employee = 'f9000000-0000-4000-8000-000000000002';
const tenant = 'f9100000-0000-4000-8000-000000000001';
const siteB = 'f9140000-0000-4000-8000-000000000002';
function session() {
  const child = spawn('docker', args, { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
  let stdout = ''; let stderr = ''; const signals = [];
  child.stdout.on('data', chunk => { stdout += chunk.toString(); for (const signal of signals) if (stdout.includes(signal.marker)) signal.resolve(); });
  child.stderr.on('data', chunk => { stderr += chunk.toString(); });
  const completion = new Promise(resolve => child.on('close', code => resolve({ code, stdout, stderr })));
  return { completion, send: sql => child.stdin.write(sql + '\n'), end: sql => child.stdin.end(sql + '\n'), marker: marker => {
    if (stdout.includes(marker)) return Promise.resolve();
    return new Promise((resolve, reject) => { const timeout = setTimeout(() => reject(new Error(`No session signal ${marker}`)), 10000); signals.push({ marker, resolve: () => { clearTimeout(timeout); resolve(); } }); });
  } };
}
async function sql(text) { const s = session(); s.end(text); const result = await s.completion; assert.equal(result.code, 0, result.stderr); return result.stdout.trim(); }
async function assertBlocked(attemptId) {
  for (let n = 0; n < 20; n++) {
    const count = await sql(`SELECT count(*) FROM pg_stat_activity WHERE datname='${database}' AND query LIKE '%attendance_mobile_punch%${attemptId}%' AND wait_event_type='Lock';`);
    if (Number(count) === 1) return;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  assert.fail('Expected executing capture waiting on a real lock: ' + attemptId);
}
function auth(actor) { return `SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${actor}',true);`; }
function jsonResult(output) { return JSON.parse(output.split('\n').findLast(line => line.startsWith('{'))); }
async function snapshot() { return jsonResult(await sql(`BEGIN;${auth(employee)}SELECT public.attendance_mobile_snapshot('${tenant}');ROLLBACK;`)); }
function attempt(snapshot, id) { return JSON.stringify({ id, direction: 'in', happened_at: new Date().toISOString(), scope: snapshot.scope, policy_version: snapshot.policy_version, location: null }); }
const fixture = readFileSync('scripts/cube5-qa-fixture.sql', 'utf8').replaceAll('f51', 'f91');
const setup = await sql(`BEGIN;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
('${operator}','cube5-p1-race-f9-operator@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now()),
('${employee}','cube5-p1-race-f9-employee@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now());
${fixture}
SELECT pg_temp.seed_cube5_fixture('${operator}','${employee}');
INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,required_minutes,earliest_punch,latest_punch,created_by)
VALUES('${tenant}','f9150000-0000-4000-8000-000000000001',2,'P1 race work context','flexible','Africa/Cairo',ARRAY[1,2,3,4,5,6,7]::smallint[],60,'00:00','23:59:59','${operator}');
UPDATE people.work_assignments SET work_policy_version=2 WHERE tenant_id='${tenant}';
INSERT INTO platform_core.tenant_sites(tenant_id,id,legal_entity_id,display_name,is_default,is_active)
VALUES('${tenant}','${siteB}','f9130000-0000-4000-8000-000000000001','P1 race Site B',false,true);
SELECT public.attendance_channel_save_source('${tenant}',NULL,'P1 race mobile B','mobile','${siteB}',true,'{"geofence":false,"retention_seconds":300}','P1 race fixture');COMMIT;`);
const ids = JSON.parse(setup.split('\n').find(line => line.startsWith('{')));
const sourceB = setup.split('\n').findLast(line => /^[0-9a-f-]{36}$/.test(line));
assert.ok(sourceB);
const results = [];
const before = await snapshot();
assert.equal(before.policy_version, 1);
const attemptAId = 'f9600000-0000-4000-8000-000000000001';
const attemptA = attempt(before, attemptAId);
// Follow the existing People tenant-before-employment protocol; capture rereads after waiting.
const transfer = session();
transfer.send(`BEGIN;SELECT pg_advisory_xact_lock(hashtextextended('${tenant}',90427));SELECT id FROM people.employments WHERE tenant_id='${tenant}' AND id='${ids.employment_id}' FOR UPDATE;SELECT 'EMPLOYMENT_HELD';`);
await transfer.marker('EMPLOYMENT_HELD');
const queuedA = session();
queuedA.end(`BEGIN;${auth(employee)}SELECT public.attendance_mobile_punch('${tenant}','${attemptA}'::jsonb);COMMIT;`);
await assertBlocked(attemptAId);
transfer.end(`${auth(operator)}SELECT public.schedule_people_work_assignment('${tenant}','${ids.employment_id}',(now() AT TIME ZONE 'Africa/Cairo')::date,'${siteB}',NULL,NULL,NULL);COMMIT;`);
const transferred = await transfer.completion;
assert.equal(transferred.code, 0, transferred.stderr);
assert.equal(jsonResult(transferred.stdout).state, 'transferred');
const staleA = await queuedA.completion;
assert.equal(staleA.code, 0, staleA.stderr);
assert.equal(jsonResult(staleA.stdout).reason, 'scope_changed');
const after = await snapshot();
assert.notEqual(after.scope, before.scope);
assert.equal(after.policy_version, 1);
assert.equal(after.site_name, 'P1 race Site B');
results.push({ name: 'executing A capture blocked by actual People employment transfer to B, both source version one', waiting_sessions: 1, outcome: jsonResult(staleA.stdout), state: 'pass' });
// Source policy change queues capture under the existing tenant/source lock order.
const update = session();
update.send(`BEGIN;SELECT pg_advisory_xact_lock(hashtextextended('${tenant}',90427));SELECT id FROM time.channel_sources WHERE tenant_id='${tenant}' AND id='${sourceB}' FOR UPDATE;SELECT 'SOURCE_HELD';`);
await update.marker('SOURCE_HELD');
const attemptBId = 'f9600000-0000-4000-8000-000000000002';
const queuedB = session();
queuedB.end(`BEGIN;${auth(employee)}SELECT public.attendance_mobile_punch('${tenant}','${attempt(after, attemptBId)}'::jsonb);COMMIT;`);
await assertBlocked(attemptBId);
update.end(`${auth(operator)}SELECT public.attendance_channel_save_source('${tenant}','${sourceB}','P1 race mobile B','mobile','${siteB}',true,'{"geofence":false,"retention_seconds":600}','P1 race policy update');COMMIT;`);
const updated = await update.completion;
assert.equal(updated.code, 0, updated.stderr);
const staleB = await queuedB.completion;
assert.equal(staleB.code, 0, staleB.stderr);
assert.equal(jsonResult(staleB.stdout).reason, 'policy_changed');
const final = await snapshot();
assert.equal(final.scope, after.scope);
assert.equal(final.policy_version, 2);
results.push({ name: 'executing B capture blocked by source policy update, exact identity unchanged', waiting_sessions: 1, outcome: jsonResult(staleB.stdout), state: 'pass' });
const counts = jsonResult(await sql(`SELECT jsonb_build_object('source_events',(SELECT count(*) FROM time.channel_events WHERE tenant_id='${tenant}'),'canonical_punches',(SELECT count(*) FROM time.manual_punches WHERE tenant_id='${tenant}'),'blank_password_actors',(SELECT count(*) FROM auth.users WHERE id IN ('${operator}','${employee}') AND encrypted_password=''));`));
assert.deepEqual(counts, { source_events: 0, canonical_punches: 0, blank_password_actors: 2 });
const manifest = { database, fixture: { ...ids, site_b_id: siteB, source_b_id: sourceB }, results, counts, runner_sha256: createHash('sha256').update(readFileSync('scripts/cube5-context-binding-concurrency.mjs')).digest('hex'), fixture_sha256: createHash('sha256').update(readFileSync('scripts/cube5-qa-fixture.sql')).digest('hex'), retained: 'Fresh f9 synthetic fixture, empty unusable passwords, no sign-in. Assignment/source version history intentionally retained.' };
writeFileSync('../cube5-qa/p1-context-concurrency-run-03.json', JSON.stringify(manifest, null, 2));
console.log(JSON.stringify(manifest, null, 2));
