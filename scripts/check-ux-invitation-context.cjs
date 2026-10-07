/* eslint-disable @typescript-eslint/no-require-imports -- Source characterization CLI, isolated SDK boundaries. */
// Actual actions; synthetic SDK responses; no network/environment/credential access.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const ts = require('typescript');
const file = 'src/app/auth/invitations/accept/actions.ts';
const baseline = execFileSync('git', ['show', `c19f054d1353de1b7f1bb885bf2d0206c9cb427a:${file}`], { encoding: 'utf8' });
const current = fs.readFileSync(file, 'utf8');
const invitationId = '11111111-1111-4111-8111-111111111111';
const tenantId = '22222222-2222-4222-8222-222222222222';
const input = { invitationId, issuance: '02', password: 'synthetic-test-only' };
const cases = [];
function load(source, scenario, trace) {
  const stop = name => { trace.push(name); if (scenario.throwAt === name) throw Error(`synthetic ${name}`); };
  const client = {
    auth: {
      getUser: async () => { stop('user'); return { data: { user: scenario.noUser ? null : { id: 'synthetic-user' } } }; },
      updateUser: async () => { stop('update'); return { error: scenario.updateError ? { message: 'synthetic' } : null }; },
    },
    rpc: async (name, params) => {
      stop(name); assert.equal(params.p_invitation_id, invitationId); assert.equal(params.p_issuance, 2);
      return name === 'validate_tenant_admin_invitation'
        ? { data: scenario.validation ?? 'password_required', error: scenario.validationError ? { message: 'synthetic' } : null }
        : { data: Object.hasOwn(scenario, 'result') ? scenario.result : { tenant_id: tenantId }, error: scenario.rpcError ? { message: scenario.rpcError } : null };
    },
  };
  const imports = {
    'next/navigation': { redirect: location => { throw Object.assign(Error('redirect'), { location }); } },
    '@/lib/supabase/server': { createSupabaseServerClient: async () => { stop('client'); return scenario.noClient ? null : client; } },
    '@/lib/supabase/admin': { createSupabaseAdminClient: () => { stop('admin'); return scenario.noAdmin ? null : { rpc: async (name, params) => { stop(name); assert.equal(params.p_user_id, 'synthetic-user'); return { error: scenario.markerError ? { message: 'synthetic' } : null }; } }; } },
  };
  const ctx = { exports: {}, require: name => { assert.ok(Object.hasOwn(imports, name)); return imports[name]; } };
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, ctx);
  return ctx.exports;
}
async function run(source, action, scenario) {
  const trace = [];
  const form = new FormData();
  for (const [key, value] of Object.entries({ ...input, ...scenario.input })) form.set(key, value);
  try { await load(source, scenario, trace)[action](form); throw Error('Missing redirect'); }
  catch (error) { return { location: error.location ?? null, error: error.location ? null : error.message, trace }; }
}
async function check(action, scenario, changed = false) {
  const before = await run(baseline, action, scenario);
  const after = await run(current, action, scenario);
  assert.deepEqual(after.trace, before.trace);
  assert.equal(after.error, before.error);
  if (changed) {
    const oldUrl = new URL(before.location, 'https://synthetic.invalid');
    const next = new URL(after.location, 'https://synthetic.invalid');
    assert.equal(next.pathname, oldUrl.pathname);
    assert.equal(next.searchParams.get('state'), oldUrl.searchParams.get('state'));
    assert.deepEqual([...next.searchParams.keys()].sort(), ['id', 'issuance', 'state']);
    assert.equal(next.searchParams.get('id'), invitationId);
    assert.equal(next.searchParams.get('issuance'), '02');
    assert.equal(oldUrl.searchParams.has('id'), false);
  } else assert.equal(after.location, before.location);
  if (after.location) assert.ok(!after.location.includes(input.password));
  cases.push({ action, scenario: scenario.id, contextChanged: changed, status: 'pass', calls: after.trace });
}
(async () => {
  const password = 'setInvitationPasswordAction';
  const accept = 'acceptInvitationAction';
  for (const action of [password, accept]) {
    for (const scenario of [{ id: 'setup', noClient: true }, { id: 'no-session', noUser: true }]) await check(action, scenario, true);
    for (const scenario of [{ id: 'invalid-reference', input: { invitationId: '../invalid' } }, { id: 'invalid-issuance', input: { issuance: '2&token=bad' } }, { id: 'success' }, { id: 'sdk-thrown', throwAt: 'user' }]) await check(action, scenario);
  }
  for (const scenario of [{ id: 'validation-error', validationError: true }, { id: 'validation-not-required', validation: 'ready' }]) await check(password, scenario, true);
  for (const scenario of [{ id: 'short-password', input: { password: 'short' } }, { id: 'update-error', updateError: true }, { id: 'missing-admin', noAdmin: true }, { id: 'marker-error', markerError: true }, { id: 'validation-thrown', throwAt: 'validate_tenant_admin_invitation' }, { id: 'update-thrown', throwAt: 'update' }]) await check(password, scenario);
  for (const code of ['issuer_authority_lost', 'identity_mismatch', 'expired', 'stale_issuance', 'password_required', 'identity_unverified', 'unknown']) await check(accept, { id: code, rpcError: code });
  for (const result of [null, [], 'bad', {}, { tenant_id: 'invalid' }]) await check(accept, { id: `unconfirmed-${JSON.stringify(result)}`, result });
  await check(accept, { id: 'accept-thrown', throwAt: 'accept_tenant_admin_invitation' });
  const report = { scope: 'Actual source actions with SDK stubs; not provider/SQL/runtime acceptance', redirectStatementsChanged: 5, cases };
  if (process.argv[2]) fs.writeFileSync(process.argv[2], JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ cases: cases.length, passed: cases.length, changedStatements: 5 }));
})().catch(error => { console.error(error); process.exitCode = 1; });
