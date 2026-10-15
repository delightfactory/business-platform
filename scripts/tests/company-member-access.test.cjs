/* eslint-disable @typescript-eslint/no-require-imports */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), ts = require('typescript');
const root = path.resolve(__dirname, '../..');
Object.assign(process.env, { NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:56321', NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: 'synthetic-key', SUPABASE_SECRET_KEY: 'synthetic-secret', NEXT_PUBLIC_APP_URL: 'http://127.0.0.1:61190' });
function load(file, dependencies = {}) {
  const compiled = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2017 } }).outputText;
  const loaded = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(name => Object.hasOwn(dependencies, name) ? dependencies[name] : require(name), loaded, loaded.exports);
  return loaded.exports;
}
const bundles = load('src/app/tenant/[tenantId]/users/bundles.ts');
const profileReturn = load('src/lib/profile-return.ts', { './return-to': load('src/lib/return-to.ts') });
const tenant = 'a1000000-0000-4000-8000-000000000001', invitation = 'a1000000-0000-4000-8000-000000000002', member = 'a1000000-0000-4000-8000-000000000003';
function setup({ writeError = null, mailError = null, throwMail = false, recordError = null } = {}) {
  const writes = [], records = []; let mails = 0;
  const client = { auth: { getUser: async () => ({ data: { user: { id: member } } }) }, rpc: async (name, args) => {
    writes.push({ name, args });
    return { error: writeError, data: writeError ? null : { id: invitation, issuance: 1, target_email: 'qa@example.test', created: true, state: 'updated' } };
  } };
  const server = load('src/lib/supabase/server.ts', { '@supabase/ssr': { createServerClient: () => client }, 'next/headers': { cookies: async () => ({ getAll: () => [], set: () => {} }) } });
  const admin = load('src/lib/supabase/admin.ts', { 'server-only': {}, '@supabase/supabase-js': { createClient: () => ({
    auth: { admin: { inviteUserByEmail: async () => { mails++; if (throwMail) throw Error('Transport interrupted'); return { error: mailError }; } } },
    rpc: async (name, args) => { records.push({ name, args }); return { error: recordError }; },
  }) } });
  const actions = load('src/app/tenant/[tenantId]/users/actions.ts', { './bundles': bundles, '@/lib/supabase/server': server, '@/lib/supabase/admin': admin, '@/lib/profile-return': profileReturn,
    'next/cache': { refresh: () => {} }, 'next/navigation': { redirect: href => { throw Object.assign(Error('Redirect'), { href }); } } });
  const form = new FormData(); for (const [key, value] of Object.entries({ tenantId: tenant, userId: member, memberEmail: 'qa@example.test', invitationId: invitation, invitationEmail: 'qa@example.test', email: 'qa@example.test', idempotencyKey: member })) form.set(key, value);
  const redirect = async (method, previous) => { try { if (previous) await actions[method](previous, form); else await actions[method](form); } catch (error) { if (error.href) return new URL(error.href, 'https://workspace.invalid'); throw error; } throw Error('Expected a review destination'); };
  return { form, redirect, writes, records, mails: () => mails };
}

test('no preset silently grants financial approval, finalization, export, payment or correction', () => {
  const critical = new Set(['payroll.input.approver.v1', 'payroll.finalizer.v1', 'payroll.exporter.v1', 'payroll.payment.recorder.v1', 'payroll.correction.requester.v1', 'employee_finance.approver.v1']);
  for (const preset of bundles.BUNDLE_PRESETS) for (const key of preset.keys) {
    assert.ok(bundles.bundleKeySet.has(key), key); assert.ok(!critical.has(key), `${preset.key}:${key}`);
  }
});

test('delivery rejection, interruption and unrecorded acceptance retain focused review without retry', async () => {
  for (const [options, state, recordSucceeded] of [
    [{ mailError: { code: 'provider_down', message: 'Unavailable' } }, 'created-failed', false],
    [{ throwMail: true }, 'created-unknown', undefined],
    [{ recordError: { code: '55000' } }, 'created-unknown', true],
  ]) {
    const system = setup(options), url = await system.redirect('inviteMemberAction');
    assert.equal(url.searchParams.get('state'), state); assert.equal(url.searchParams.get('view'), 'invitations');
    assert.equal(url.searchParams.get('invitation'), invitation); assert.equal(url.searchParams.get('q'), 'qa@example.test');
    assert.equal(system.mails(), 1); assert.equal(system.writes.length, 1); assert.equal(system.records[0]?.args.p_succeeded, recordSucceeded);
  }
});

test('lost issuer authority does not send mail and retains the invitation for review', async () => {
  const system = setup({ writeError: { code: '42501', message: 'tenant_member_invite_issuer_authority_lost' } });
  const url = await system.redirect('reissueMemberInvitationAction');
  assert.equal(url.searchParams.get('state'), 'issuer-lost'); assert.equal(url.searchParams.get('invitation'), invitation); assert.equal(system.mails(), 0);
});

test('stale member editing carries observed selection once and returns to the current member', async () => {
  const system = setup({ writeError: { code: 'PT409', message: 'tenant_people_role_bundle_stale' } });
  system.form.append('bundleKey', 'payroll.reader.v1'); system.form.append('bundleKey', 'employee.leave.self.v1'); system.form.append('expectedBundleKey', 'employee.leave.self.v1');
  const url = await system.redirect('setTenantMemberPeopleBundlesAction');
  assert.equal(url.searchParams.get('state'), 'bundles-stale'); assert.equal(url.searchParams.get('member'), member); assert.equal(url.searchParams.get('q'), 'qa@example.test');
  assert.equal(system.writes.length, 1); assert.deepEqual(system.writes[0].args.p_expected_bundle_keys, ['employee.leave.self.v1']);
});
test('employee invitation completion returns to the same task without altering invitation semantics', async () => {
  const system = setup(), task = `/tenant/${tenant}/payroll?employer=${member}`;
  system.form.set('employeeId', member); system.form.set('profileReturn', task);
  const result = await system.redirect('inviteMemberFormAction', { email: '', idempotencyKey: member, error: '', attempt: 0 });
  assert.equal(result.pathname, `/tenant/${tenant}/people/${member}`);
  assert.equal(result.searchParams.get('return'), task); assert.equal(result.searchParams.get('userLink'), 'invite-sent');
  assert.equal(system.writes.length, 1); assert.equal(system.mails(), 1);
});
