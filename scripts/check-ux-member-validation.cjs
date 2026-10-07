/* eslint-disable @typescript-eslint/no-require-imports -- Actual-source SDK-stub characterization CLI. */
// No network, environment files, real credentials or project database.
const fs = require('node:fs');
const cp = require('node:child_process');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const ts = require('typescript');
const { renderToStaticMarkup } = require('react-dom/server');
const base = '29c249a39b328f21acfadadda6bd9a9f54d0605b';
const prefix = 'src/app/auth/membership-invitations/accept/';
const id = '11111111-1111-4111-8111-111111111111';
const tenant = '22222222-2222-4222-8222-222222222222';
const password = 'synthetic-only-password';
const cases = [];
function load(file, scenario, trace, baseline) {
  const source = baseline ? cp.execFileSync('git', ['show', `${base}:${file}`], { encoding: 'utf8' }) : fs.readFileSync(file, 'utf8');
  const touch = name => { trace.push(name); if (scenario.throwAt === name) throw Error(`synthetic ${name}`); };
  const client = {
    auth: {
      getUser: async () => { touch('user'); return { data: { user: scenario.noUser ? null : { id, email: 'synthetic@example.invalid' } } }; },
      updateUser: async () => { touch('update'); return { error: scenario.updateError ? {} : null }; },
    },
    rpc: async name => { touch(name); return name.startsWith('validate_') ? { data: Object.hasOwn(scenario, 'validation') ? scenario.validation : 'password_required', error: scenario.validationError ? {} : null } : { data: Object.hasOwn(scenario, 'result') ? scenario.result : { tenant_id: tenant }, error: scenario.acceptError ? { message: scenario.acceptError } : null }; },
  };
  const redirect = location => { throw Object.assign(Error('redirect'), { location }); };
  const forbidden = () => { throw Error('Render must not invoke actions'); };
  const imports = {
    'next/navigation': { redirect },
    '@/lib/supabase/server': { createSupabaseServerClient: async () => { touch('client'); return scenario.noClient ? null : client; } },
    '@/lib/supabase/admin': { createSupabaseAdminClient: () => { touch('admin'); return scenario.noAdmin ? null : { rpc: async name => { touch(name); return { error: scenario.markerError ? {} : null }; } }; } },
    '@/app/auth/actions': { signOutAction: forbidden },
    './actions': { acceptMemberInvitationAction: forbidden, setMemberInvitationPasswordAction: forbidden },
    '@/components/submit-button': { SubmitButton: props => require('react').createElement('button', { type: 'submit' }, props.label) },
  };
  const ctx = { exports: {}, require: name => Object.hasOwn(imports, name) ? imports[name] : ['react/jsx-runtime', 'next/link'].includes(name) ? require(name) : (() => { throw Error(`Unexpected import ${name}`); })() };
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX } }).outputText, ctx);
  return ctx.exports;
}
async function action(name, scenario, baseline) {
  const trace = [], form = new FormData();
  Object.entries({ invitationId: id, issuance: '1', password, ...scenario.input }).forEach(([k, v]) => form.set(k, v));
  try { await load(prefix + 'actions.ts', scenario, trace, baseline)[name](form); throw Error('Missing redirect'); }
  catch (error) { return { location: error.location ?? null, error: error.location ? null : error.message, trace }; }
}
async function checkAction(name, scenario, changed = false) {
  const before = await action(name, scenario, true), after = await action(name, scenario, false);
  if (changed) {
    assert.ok(before.trace.includes('update')); assert.ok(before.trace.includes('record_tenant_member_password_readiness'));
    assert.deepEqual(after.trace, ['client', 'user', 'validate_tenant_member_invitation']);
    assert.match(after.location, /state=unavailable$/); assert.match(after.location, new RegExp(id));
  } else assert.deepEqual(after, before);
  if (after.location) assert.ok(!after.location.includes(password));
  cases.push({ kind: name, case: scenario.id, before, after, status: 'pass' });
}
async function page(scenario, baseline) {
  const trace = [];
  try { const value = await load(prefix + 'page.tsx', scenario, trace, baseline).default({ searchParams: Promise.resolve({ id, issuance: '1', ...scenario.query }) }); return { html: renderToStaticMarkup(value), trace }; }
  catch (error) { if (!error.location) throw error; return { html: `REDIRECT:${error.location}`, trace }; }
}
(async () => {
  const set = 'setMemberInvitationPasswordAction', accept = 'acceptMemberInvitationAction';
  for (const name of [set, accept]) for (const scenario of [{ id: 'invalid-id', input: { invitationId: 'bad' } }, { id: 'invalid-issuance', input: { issuance: '1&token=bad' } }, { id: 'setup', noClient: true }, { id: 'no-user', noUser: true }, { id: 'success' }, { id: 'getUser-thrown', throwAt: 'user' }]) await checkAction(name, scenario);
  await checkAction(set, { id: 'contradictory-data-error', validation: 'password_required', validationError: true }, true);
  for (const scenario of [{ id: 'short-password', input: { password: 'short' } }, { id: 'ready-not-required', validation: 'ready' }, { id: 'unavailable', validation: 'unavailable' }, { id: 'null', validation: null }, { id: 'validation-error', validation: null, validationError: true }, { id: 'update-error', updateError: true }, { id: 'admin-missing', noAdmin: true }, { id: 'marker-error', markerError: true }, { id: 'validation-throw', throwAt: 'validate_tenant_member_invitation' }, { id: 'update-throw', throwAt: 'update' }]) await checkAction(set, scenario);
  for (const code of ['limit_full', 'issuer_authority_lost', 'identity_mismatch', 'identity_unverified', 'target_unavailable', 'password_required', 'stale_issuance', 'tenant_unavailable', 'unknown']) await checkAction(accept, { id: code, acceptError: code });
  for (const result of [null, [], {}, 'bad', { tenant_id: 'bad' }]) await checkAction(accept, { id: `malformed-${JSON.stringify(result)}`, result });
  await checkAction(accept, { id: 'accept-throw', throwAt: 'accept_tenant_member_invitation' });
  for (const scenario of [{ id: 'ready', validation: 'ready' }, { id: 'password', validation: 'password_required' }, { id: 'unknown', validation: null }, { id: 'issuer-denied', validation: 'issuer_authority_lost' }, { id: 'identity-denied', validation: 'identity_mismatch' }, { id: 'target-denied', validation: 'unavailable', query: { state: 'target-unavailable' } }, { id: 'unavailable', validation: 'unavailable' }, { id: 'error-ready', validation: 'ready', validationError: true }, { id: 'error-unavailable', validation: 'unavailable', validationError: true }, { id: 'coercible-ready', validation: { toString: () => 'ready' } }, { id: 'coercible-password', validation: { toString: () => 'password_required' } }, { id: 'array-ready', validation: ['ready'] }, { id: 'setup', noClient: true }, { id: 'no-user', noUser: true }, { id: 'target-unavailable', validation: 'ready', query: { state: 'target-unavailable' } }]) {
    const before = await page(scenario, true), after = await page(scenario, false);
    assert.deepEqual(after.trace, before.trace);
    if (scenario.id === 'ready' || scenario.id === 'target-unavailable') assert.match(after.html, /قبول الدعوة/);
    if (scenario.id === 'password') assert.match(after.html, /name="password"/);
    if (scenario.id.includes('coercible') || scenario.id === 'array-ready') { assert.match(before.html, /name="invitationId"/); assert.doesNotMatch(after.html, /name="invitationId"|name="password"/); }
    if (scenario.validationError) { assert.doesNotMatch(after.html, /name="password"|name="invitationId"|انتهت صلاحيتها/); assert.match(after.html, /قبل المتابعة/); }
    if (scenario.id === 'issuer-denied' || scenario.id === 'identity-denied') { assert.match(after.html, /قبل المتابعة/); assert.doesNotMatch(after.html, /name="invitationId"|name="password"/); }
    if (scenario.id === 'target-denied') { assert.match(after.html, /مراجعة الحساب المرتبط بالدعوة/); assert.doesNotMatch(after.html, /name="invitationId"|name="password"/); }
    if (scenario.id === 'unavailable') assert.match(after.html, /اطلب إعادة إرسالها/);
    if (scenario.id === 'target-unavailable') assert.match(after.html, /مراجعة الحساب المرتبط بالدعوة/);
    if (scenario.id === 'no-user') assert.match(decodeURIComponent(after.html), new RegExp(id));
    cases.push({ kind: 'page', case: scenario.id, status: 'pass', baselineHadMutationForm: before.html.includes('name="invitationId"'), afterHasMutationForm: after.html.includes('name="invitationId"') });
  }
  const report = { baseline: base, scope: 'Actual source with SDK/submit-button stubs, no real provider/browser/SQL acceptance', cases };
  if (process.argv[2]) fs.writeFileSync(process.argv[2], JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ passed: cases.length, cases: cases.length }));
})().catch(error => { console.error(error); process.exitCode = 1; });
