// Explicit owned local QA only. Private append is a protocol fixture, never a public G6 bypass.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import pg from 'pg';

const [fixturePath, evidencePath, priorEvidencePath] = process.argv.slice(2);
assert(fixturePath && evidencePath, 'Pass retained private fixture and a new evidence path');
assert(!fs.existsSync(evidencePath), 'Evidence exists: inspect its stage; never rerun a money scenario');
const setup = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const priorEvidence = priorEvidencePath ? JSON.parse(fs.readFileSync(priorEvidencePath, 'utf8')) : null;
if (priorEvidence) {
  assert.equal(priorEvidence.status, 'FAIL_STOPPED');
  assert.equal(priorEvidence.error, 'payroll_payment_invalid');
  assert.equal(priorEvidence.scenarios.length, 1);
  assert.equal(priorEvidence.scenarios[0].winnerResult, undefined, 'Committed or successful winner requires read-only diagnosis');
}
assert.equal(setup.status, 'READY');
assert.equal(setup.fixtures.length, 4);
const databases = ['business_platform_cube4_upgrade_qa', 'business_platform_cube4_candidate_lf_fresh_qa'];
for (const f of setup.fixtures) {
  assert(databases.includes(f.database) && f.syntheticNonlegal === true);
  for (const key of ['tenant', 'employer', 'employment', 'actorAppend', 'actorPayment', 'originalOutput', 'caseId', 'amendmentRun', 'originalRun', 'period']) {
    assert(/^[0-9a-f-]{36}$/.test(f[key]), 'Malformed owned QA identity');
  }
  assert.notEqual(f.actorAppend, f.actorPayment);
  assert(['payment-first', 'amendment-first'].includes(f.order));
}
const inspect = spawnSync('docker', ['inspect', 'supabase_db_business-platform'], { encoding: 'utf8' });
assert.equal(inspect.status, 0, 'Owned local PostgreSQL container unavailable');
const container = JSON.parse(inspect.stdout)[0];
const env = Object.fromEntries(container.Config.Env.map(value => {
  const i = value.indexOf('='); return [value.slice(0, i), value.slice(i + 1)];
}));
const port = container.NetworkSettings.Ports['5432/tcp'].find(value => ['0.0.0.0', '127.0.0.1'].includes(value.HostIp));
assert(port && env.POSTGRES_PASSWORD, 'Owned local PostgreSQL configuration missing');
const configuration = database => ({ host: '127.0.0.1', port: Number(port.HostPort), database, user: 'postgres', password: env.POSTGRES_PASSWORD });
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const evidence = {
  status: 'RUNNING', atUTC: new Date().toISOString(), baseline: setup.baseline,
  fixtureSHA256: crypto.createHash('sha256').update(fs.readFileSync(fixturePath)).digest('hex'),
  scriptSHA256: crypto.createHash('sha256').update(fs.readFileSync(new URL(import.meta.url))).digest('hex'),
  scenarios: [],
  priorFailure: priorEvidencePath ? { path: priorEvidencePath, SHA256: crypto.createHash('sha256').update(fs.readFileSync(priorEvidencePath)).digest('hex'), reason: 'Future fixture payment date rejected before winner completed; transactions rolled back' } : null,
  limits: [
    'Prescribed SYNTHETIC_NONLEGAL candidate money supplies the trusted-adapter prerequisite; no legal pack verified',
    'Private atomic append versus supported payment RPC in real SQL sessions; public G6, Next Action loss and browser acceptance not claimed',
    'Fresh-origin database upgraded to this baseline; no full fresh-chain replay in this runner',
  ],
};
function save(stage) {
  evidence.stage = stage;
  fs.writeFileSync(evidencePath, JSON.stringify(evidence, null, 2));
  console.log(JSON.stringify({ stage, status: evidence.status }));
}
const row = async (client, sql, args = []) => (await client.query(sql, args)).rows[0];
const functionDigestSQL = "SELECT md5(string_agg(pg_get_functiondef(p.oid),'' ORDER BY p.oid)) digest FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN('payroll','time','leave','people','platform_core') OR(n.nspname='public' AND p.proname LIKE 'payroll%')";
const paymentSQL = 'SELECT public.payroll_record_payment($1,$2,$3,$4,\'allocations\',$5,$6,$7,$8,NULL,true,$9) value';
const amendmentSQL = 'SELECT payroll.append_correction_outputs($1,$2,$3,$4,$5) value';

async function retainedOutsideScenarios(admin, tenants) {
  const tables = (await admin.query("SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN('payroll','time','leave','people','platform_core') UNION SELECT 'auth','users' UNION SELECT 'auth','identities' ORDER BY 1,2")).rows;
  const values = [];
  for (const { schemaname, tablename } of tables) {
    assert(/^[a-z_]+$/.test(schemaname) && /^[a-z_]+$/.test(tablename));
    const result = await row(admin, `SELECT md5(COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]')) digest FROM ${schemaname}.${tablename} x WHERE NOT(COALESCE(to_jsonb(x)->>'tenant_id',CASE WHEN $2='platform_core.tenants' THEN to_jsonb(x)->>'id' END,'')=ANY($1::text[]))`, [tenants, `${schemaname}.${tablename}`]);
    values.push({ table: `${schemaname}.${tablename}`, digest: result.digest });
  }
  return values;
}

try {
  for (const database of databases) {
    const admin = new pg.Client(configuration(database));
    const payment = new pg.Client(configuration(database));
    const amendment = new pg.Client(configuration(database));
    try {
      await admin.connect(); await payment.connect(); await amendment.connect();
      assert.equal(Number((await row(admin, 'SELECT count(*) FROM supabase_migrations.schema_migrations')).count), setup.baseline);
      const functionsBefore = (await row(admin, functionDigestSQL)).digest;
      const fixtures = setup.fixtures.filter(f => f.database === database);
      const untouchedBefore = await retainedOutsideScenarios(admin, fixtures.map(f => f.tenant));
      assert.equal((await row(admin, "SELECT has_function_privilege('authenticated','payroll.append_correction_outputs(uuid,uuid,integer,uuid,uuid)','EXECUTE') allowed")).allowed, false);
      await payment.query('SET ROLE authenticated');
      await payment.query("SET statement_timeout='15s'; SET lock_timeout='10s'");
      await amendment.query("SET statement_timeout='15s'; SET lock_timeout='10s'");
      for (const f of fixtures) {
        await payment.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [f.actorPayment]);
        await amendment.query("SELECT set_config('request.jwt.claim.sub',$1,false)", [f.actorAppend]);
        assert.equal((await row(admin, "SELECT platform_private.has_tenant_permission($1,$2,'payroll.payment_record') allowed", [f.tenant, f.actorPayment])).allowed, true);
        assert.equal((await row(admin, "SELECT platform_private.has_tenant_permission($1,$2,'payroll.lock') allowed", [f.tenant, f.actorAppend])).allowed, true);
        assert.deepEqual(await row(admin, 'SELECT status,revision FROM payroll.correction_cases WHERE tenant_id=$1 AND id=$2', [f.tenant, f.caseId]), { status: 'approved', revision: 3 });
        assert.equal((await row(admin, 'SELECT payroll.output_has_ever_paid($1,$2) paid', [f.tenant, f.originalOutput])).paid, false);
        const outputBefore = (await row(admin, 'SELECT to_jsonb(c) data FROM payroll.final_contexts c WHERE tenant_id=$1 AND id=$2', [f.tenant, f.originalOutput])).data;
        const employeesBefore = (await admin.query('SELECT to_jsonb(e) data FROM payroll.final_employees e WHERE tenant_id=$1 AND output_id=$2 ORDER BY employment_id', [f.tenant, f.originalOutput])).rows;
        const date = (await row(admin, "SELECT (clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date::text date")).date;
        const previous = priorEvidence?.scenarios.find(s => s.database === database && s.caseId === f.caseId && s.order === f.order);
        if (previous) assert.equal((await row(admin, 'SELECT count(*) FROM payroll.command_receipts WHERE tenant_id=$1 AND attempt_key=ANY($2::uuid[])', [f.tenant, [previous.paymentAttempt, previous.amendmentAttempt]])).count, '0');
        const paymentAttempt = previous?.paymentAttempt ?? crypto.randomUUID(), amendmentAttempt = previous?.amendmentAttempt ?? crypto.randomUUID();
        const scenario = { database, order: f.order, originalOutput: f.originalOutput, caseId: f.caseId, paymentActor: f.actorPayment, amendmentActor: f.actorAppend, paymentAttempt, amendmentAttempt, originalContextSHA256: hash(outputBefore), originalEmployeesSHA256: hash(employeesBefore) };
        evidence.scenarios.push(scenario);
        const paymentArgs = [f.tenant, f.employer, f.originalOutput, f.expectedPayment, date, `QA X03 ${f.order}`, 'SYNTHETIC_NONLEGAL payment versus amendment race', JSON.stringify([{ employment_id: f.employment, amount: '10.00' }]), paymentAttempt];
        const amendmentArgs = [f.tenant, f.caseId, f.expectedCase, f.actorAppend, amendmentAttempt];
        const paymentFirst = f.order === 'payment-first';
        const winner = paymentFirst ? payment : amendment, loser = paymentFirst ? amendment : payment;
        const winnerSQL = paymentFirst ? paymentSQL : amendmentSQL, loserSQL = paymentFirst ? amendmentSQL : paymentSQL;
        const winnerArgs = paymentFirst ? paymentArgs : amendmentArgs, loserArgs = paymentFirst ? amendmentArgs : paymentArgs;
        const winnerPid = (await row(winner, 'SELECT pg_backend_pid() pid')).pid, loserPid = (await row(loser, 'SELECT pg_backend_pid() pid')).pid;
        scenario.backendPids = { winner: winnerPid, loser: loserPid };
        save(`before-original-${database}-${f.order}`);
        await winner.query('BEGIN'); await loser.query('BEGIN');
        scenario.winnerResult = (await row(winner, winnerSQL, winnerArgs)).value;
        let losingResult;
        const pending = loser.query(loserSQL, loserArgs).then(result => { losingResult = { unexpectedSuccess: result.rows[0].value }; }, error => { losingResult = { code: error.code, message: error.message }; });
        let blockers = [];
        for (let check = 0; check < 20; check++) {
          blockers = (await row(admin, 'SELECT pg_blocking_pids($1) pids', [loserPid])).pids;
          if (blockers.includes(winnerPid)) break;
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        assert(blockers.includes(winnerPid), 'Actual competing lock not observed; preserve original scenario');
        scenario.observedBlocking = { winnerPid, loserPid, blockers };
        save(`observed-blocking-${database}-${f.order}`);
        await winner.query('COMMIT'); await pending; await loser.query('ROLLBACK');
        scenario.loserResult = losingResult;
        save(`winner-committed-${database}-${f.order}`);
        assert.deepEqual(losingResult, paymentFirst ? { code: 'PT409', message: 'payroll_source_stale' } : { code: '23514', message: 'payroll_output_superseded' });
        const originalReplay = (await row(winner, winnerSQL, winnerArgs)).value;
        assert.deepEqual(originalReplay, scenario.winnerResult);
        scenario.exactOriginalReceiptReplay = true;
        const losingActor = paymentFirst ? f.actorAppend : f.actorPayment, losingAttempt = paymentFirst ? amendmentAttempt : paymentAttempt;
        assert.equal((await row(admin, 'SELECT count(*) FROM payroll.command_receipts WHERE tenant_id=$1 AND actor_id=$2 AND attempt_key=$3', [f.tenant, losingActor, losingAttempt])).count, '0');
        assert.equal(hash((await row(admin, 'SELECT to_jsonb(c) data FROM payroll.final_contexts c WHERE tenant_id=$1 AND id=$2', [f.tenant, f.originalOutput])).data), scenario.originalContextSHA256);
        assert.equal(hash((await admin.query('SELECT to_jsonb(e) data FROM payroll.final_employees e WHERE tenant_id=$1 AND output_id=$2 ORDER BY employment_id', [f.tenant, f.originalOutput])).rows), scenario.originalEmployeesSHA256);
        const state = await row(admin, "SELECT (SELECT status FROM payroll.runs WHERE tenant_id=$1 AND id=$2) original_status,(SELECT amount::text FROM people.compensation_versions WHERE tenant_id=$1 AND employment_id=$3) compensation,(SELECT count(*) FROM payroll.output_successions WHERE tenant_id=$1 AND original_output=$4) successions,(SELECT count(*) FROM payroll.payment_events WHERE tenant_id=$1) payment_events,(SELECT count(*) FROM payroll.correction_source_effects WHERE tenant_id=$1 AND case_id=$5) source_effects,(SELECT count(*) FROM payroll.final_contexts WHERE tenant_id=$1) outputs", [f.tenant, f.originalRun, f.employment, f.originalOutput, f.caseId]);
        assert.deepEqual(state, paymentFirst ? { original_status: 'locked', compensation: '3000.00', successions: '0', payment_events: '1', source_effects: '0', outputs: '1' } : { original_status: 'superseded', compensation: '3300.00', successions: '1', payment_events: '0', source_effects: '1', outputs: '2' });
        const balance = await row(admin, 'SELECT sum(payable)::text payable,sum(paid)::text paid,sum(remaining)::text remaining FROM payroll.payment_balances($1,$2)', [f.tenant, f.originalOutput]);
        assert.equal(Number(balance.payable), 4000); assert.equal(Number(balance.paid), paymentFirst ? 10 : 0); assert.equal(Number(balance.remaining), paymentFirst ? 3990 : 4000);
        scenario.retainedOriginal = true; scenario.finalState = state; scenario.originalBalances = balance;
        scenario.status = 'PASS'; save(`completed-${database}-${f.order}`);
      }
      assert.equal((await row(admin, functionDigestSQL)).digest, functionsBefore);
      assert.deepEqual(await retainedOutsideScenarios(admin, fixtures.map(f => f.tenant)), untouchedBefore);
      for (const scenario of evidence.scenarios.filter(s => s.database === database)) {
        scenario.functionsUnchanged = true; scenario.unrelatedSetsRetained = untouchedBefore.length;
      }
    } finally {
      for (const client of [payment, amendment]) await client.query('ROLLBACK').catch(() => {});
      await Promise.allSettled([payment.end(), amendment.end(), admin.end()]);
    }
  }
  evidence.status = 'PASS'; save('completed-both-orders-on-both-retained-databases');
} catch (error) {
  evidence.status = 'FAIL_STOPPED'; evidence.error = String(error.message).split('\n')[0];
  save('stopped-preserve-original-attempts-and-committed-outcome'); process.exitCode = 1;
}
