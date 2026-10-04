// Narrow real two-session QA proof. Synthetic fixture is intentionally retained.
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
const database = 'business_platform_cube5_adam_channels_qa';
const args = ['exec', '-i', 'supabase_db_business-platform', 'psql', '-X', '-qAt', '-U', 'postgres', '-d', database, '-v', 'ON_ERROR_STOP=1'];
const lane=process.argv[2]??'f6';
assert.ok(['f6','f7'].includes(lane));
const operator = `${lane}000000-0000-4000-8000-000000000001`;
const employee = `${lane}000000-0000-4000-8000-000000000002`;
const tenant = `${lane}100000-0000-4000-8000-000000000001`;
const attemptId=`${lane}600000-0000-4000-8000-000000000001`;
const results = [];
function session() {
  const child = spawn('docker', args, { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
  let stdout = ''; let stderr = ''; const signals = [];
  child.stdout.on('data', chunk => { stdout += chunk.toString(); for (const signal of signals) if (stdout.includes(signal.marker)) signal.resolve(); });
  child.stderr.on('data', chunk => { stderr += chunk.toString(); });
  const completion = new Promise(resolve => child.on('close', code => resolve({ code, stdout, stderr })));
  return { child, completion, send: sql => child.stdin.write(sql + '\n'), end: sql => child.stdin.end(sql + '\n'), marker: marker => {
    if (stdout.includes(marker)) return Promise.resolve();
    return new Promise((resolve, reject) => { const timeout = setTimeout(() => reject(new Error(`No session signal ${marker}`)), 10000); signals.push({ marker, resolve: () => { clearTimeout(timeout); resolve(); } }); });
  } };
}
async function sql(text) { const s = session(); s.end(text); const result = await s.completion; assert.equal(result.code, 0, result.stderr); return result.stdout.trim(); }
async function assertBlocked(fragment) {
  for (let n=0;n<20;n++) {
    const count=await sql(`SELECT count(*) FROM pg_stat_activity WHERE datname='${database}' AND query LIKE '%${fragment}%' AND wait_event_type='Lock';`);
    if (Number(count)===1) return;
    await new Promise(resolve=>setTimeout(resolve,50));
  }
  assert.fail('Expected a real queued capture session for '+fragment);
}
const fixture = readFileSync('scripts/cube5-qa-fixture.sql', 'utf8').replaceAll('f51', `${lane}1`);
const fixtureResult = await sql(`BEGIN;
INSERT INTO auth.users(id,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,aud,role,created_at,updated_at) VALUES
('${operator}','cube5-race-${lane}-operator@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now()),
('${employee}','cube5-race-${lane}-employee@example.test','',now(),'{}','{}','authenticated','authenticated',now(),now());
${fixture}
SELECT pg_temp.seed_cube5_fixture('${operator}','${employee}');COMMIT;`);
const ids = JSON.parse(fixtureResult.split('\n').find(line => line.startsWith('{')));
const scope = `${tenant}:${employee}:` + await sql(`SELECT id FROM people.employee_user_links WHERE tenant_id='${tenant}' AND user_id='${employee}' AND unlinked_at IS NULL;`);
const attempt = JSON.stringify({ id: attemptId, direction: 'in', happened_at: new Date().toISOString(), scope, policy_version: 1, location: null });

// Submit is already executing and waiting; reconciliation commits a terminal receipt first.
const lock = session();
lock.send(`BEGIN;SELECT pg_advisory_xact_lock(hashtextextended('${tenant}:${employee}',505));SELECT 'CANCEL_LOCK_HELD';`);
await lock.marker('CANCEL_LOCK_HELD');
const delayed = session();
delayed.end(`BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${employee}',true);SELECT public.attendance_mobile_punch('${tenant}','${attempt}'::jsonb);COMMIT;`);
await assertBlocked('SELECT public.attendance_mobile_punch(');
lock.end(`SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${employee}',true);SELECT public.attendance_mobile_attempt('${tenant}','${attemptId}','${scope}');COMMIT;`);
const cancelled = await lock.completion;assert.equal(cancelled.code,0,cancelled.stderr);
const delayedResult = await delayed.completion;assert.equal(delayedResult.code,0,delayedResult.stderr);
assert.match(cancelled.stdout, /"reason": "cancelled"/);assert.match(delayedResult.stdout, /"reason": "cancelled"/);
assert.equal(await sql(`SELECT count(*) FROM time.manual_punches WHERE tenant_id='${tenant}';`),'0');
results.push({ name: 'executing delayed submit versus authoritative cancellation', waiting_sessions: 1, state: 'pass', canonical_events: 0 });

// A source update holds the existing tenant mutation lock. Capture queues, then rechecks enabled state.
const disable = session();
disable.send(`BEGIN;SELECT pg_advisory_xact_lock(hashtextextended('${tenant}',90427));SELECT 'DISABLE_LOCK_HELD';`);
await disable.marker('DISABLE_LOCK_HELD');
const capture = session();
capture.end(`BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${operator}',true);SELECT public.attendance_channel_submit('${tenant}','${ids.external_source_id}','disabled-race','unmapped-key',now(),'in');COMMIT;`);
await assertBlocked('SELECT public.attendance_channel_submit(%disabled-race');
disable.end(`SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${operator}',true);SELECT public.attendance_channel_save_source('${tenant}','${ids.external_source_id}','مصدر تجريبي','external','${ids.site_id}',false,'{}','Synthetic concurrent disable');COMMIT;`);
assert.equal((await disable.completion).code,0);
const disabledCapture = await capture.completion;assert.equal(disabledCapture.code,0,disabledCapture.stderr);assert.match(disabledCapture.stdout, /"reason": "disabled"/);
results.push({ name: 'queued source capture versus source disable', waiting_sessions: 1, state: 'pass' });

// Permission changes while an authorized capture is blocked on its scoped source row.
const revoke = session();
revoke.send(`BEGIN;SELECT pg_advisory_xact_lock(hashtextextended('${tenant}',90427));SELECT id FROM time.channel_sources WHERE tenant_id='${tenant}' AND id='${ids.external_source_id}' FOR UPDATE;SELECT 'REVOKE_SOURCE_HELD';`);
await revoke.marker('REVOKE_SOURCE_HELD');
const queued = session();
queued.end(`BEGIN;SET LOCAL ROLE authenticated;SELECT set_config('request.jwt.claim.sub','${operator}',true);SELECT public.attendance_channel_submit('${tenant}','${ids.external_source_id}','revoked-race','unmapped-key',now(),'in');COMMIT;`);
await assertBlocked('SELECT public.attendance_channel_submit(%revoked-race');
revoke.end(`UPDATE platform_core.tenant_memberships SET access_state='inactive' WHERE tenant_id='${tenant}' AND user_id='${operator}';COMMIT;`);
assert.equal((await revoke.completion).code,0);
const rejected = await queued.completion;assert.notEqual(rejected.code,0);assert.match(rejected.stderr,/channel_forbidden/);
assert.equal(await sql(`SELECT count(*) FROM time.channel_events WHERE tenant_id='${tenant}';`),'0');
results.push({ name: 'queued authorized capture versus membership revocation', waiting_sessions: 1, state: 'pass', source_events: 0 });
const manifest = { database, fixture: ids, results, runner_sha256: createHash('sha256').update(readFileSync('scripts/cube5-channel-concurrency.mjs')).digest('hex'), fixture_sha256: createHash('sha256').update(readFileSync('scripts/cube5-qa-fixture.sql')).digest('hex'), retained: 'Synthetic actors use empty unusable passwords; fixture and terminal receipt history intentionally retained.' };
writeFileSync('../cube5-qa/implementation-concurrency.json', JSON.stringify(manifest,null,2));
console.log(JSON.stringify(manifest,null,2));
