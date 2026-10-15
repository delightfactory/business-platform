/* eslint-disable @typescript-eslint/no-require-imports */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), ts = require('typescript');
const root = path.resolve(__dirname, '../..');
process.env.NEXT_PUBLIC_SUPABASE_URL = 'http://127.0.0.1:56321';
process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = 'synthetic-test-key';
process.env.SUPABASE_SECRET_KEY = 'synthetic-test-secret';
process.env.NEXT_PUBLIC_APP_URL = 'http://127.0.0.1:61190';
delete process.env.SUPABASE_INTERNAL_URL;
function load(relativePath, dependencies = {}) {
  const source = fs.readFileSync(path.join(root, relativePath), 'utf8');
  const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
  const loadedModule = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(name => Object.hasOwn(dependencies, name) ? dependencies[name] : require(name), loadedModule, loadedModule.exports);
  return loadedModule.exports;
}
function setup({ creationError, existing = false, mailError = null, throwMail = false, recordError = null } = {}) {
  const calls = []; let emails = 0;
  const client = { rpc: async (name, args) => {
    calls.push({ name, args });
    if (name === 'create_tenant_admin_invitation') {
      if (creationError instanceof Error) throw creationError;
      return { error: creationError ?? null, data: creationError ? null : { id: 'a1000000-0000-4000-8000-000000000001', issuance: 1, target_email: 'first-admin@example.test', created: !existing, lifecycle_state: existing ? 'accepted' : 'pending', delivery_state: 'sent' } };
    }
    return { data: null, error: recordError };
  } };
  const server = load('src/lib/supabase/server.ts', { '@supabase/ssr': { createServerClient: () => client }, 'next/headers': { cookies: async () => ({ getAll: () => [], set: () => {} }) } });
  const admin = load('src/lib/supabase/admin.ts', { 'server-only': {}, '@supabase/supabase-js': { createClient: () => ({ auth: { admin: { inviteUserByEmail: async () => { emails++; if (throwMail) throw new Error('transport unavailable'); return { error: mailError }; } } } }) } });
  const actions = load('src/app/operator/invitations/actions.ts', { '@/lib/supabase/server': server, '@/lib/supabase/admin': admin,
    '@/lib/invitation-creation': load('src/lib/invitation-creation.ts'), 'next/cache': { revalidatePath: () => {} }, 'next/navigation': { redirect: () => { throw new Error('creation must return a receipt'); } } });
  const form = new FormData();
  for (const [key, value] of Object.entries({ idempotencyKey: 'a2000000-0000-4000-8000-000000000001', tenantName: 'Synthetic Company', entityName: '', siteName: 'Main', targetEmail: 'first-admin@example.test', seatsMode: 'limited', seatsLimit: '10', sitesMode: 'limited', sitesLimit: '10' })) form.set(key, value);
  return { run: () => actions.createInvitationAction({ attempt: 0 }, form), calls, emails: () => emails };
}
test('creation distinguishes rejected input, authority, conflict and unknown without sending email', async () => {
  for (const [error, expected] of [
    [{ code: '22023', message: 'onboarding_required_fields_invalid' }, 'invalid'],
    [{ code: '22023', message: 'onboarding_invalid_limit' }, 'invalid'],
    [{ code: '22023', message: 'tenant_admin_invite_invalid_request' }, 'invalid'],
    [{ code: 'P0001', message: 'onboarding_idempotency_conflict' }, 'conflict'],
    [{ code: 'P0001', message: 'tenant_admin_invite_idempotency_conflict' }, 'conflict'],
    [{ code: '42501', message: 'platform_operator_onboarding_forbidden' }, 'forbidden'],
    [{ code: '55000', message: 'unrecognized_failure' }, 'unknown'],
    [new Error('network interrupted'), 'unknown'],
  ]) {
    const system = setup({ creationError: error }); const result = await system.run();
    assert.equal(result.error, expected); assert.equal(result.receipt, undefined); assert.equal(system.emails(), 0); assert.equal(system.calls.length, 1);
  }
});
test('existing accepted intent returns its identity without sending another message', async () => {
  const system = setup({ existing: true }); const result = await system.run();
  assert.equal(result.error, null); assert.equal(result.receipt.created, false); assert.equal(result.receipt.lifecycle, 'accepted');
  assert.equal(system.emails(), 0); assert.equal(system.calls.length, 1);
});
test('known invitation receipt distinguishes provider acceptance, rejection and unrecorded delivery', async () => {
  for (const [options, delivery, succeeded] of [
    [{}, 'sent', true],
    [{ mailError: { code: 'provider_down', message: 'temporarily unavailable' } }, 'failed', false],
    [{ recordError: { code: '55000' } }, 'unknown', true],
  ]) {
    const system = setup(options); const result = await system.run();
    assert.equal(result.error, null); assert.equal(result.receipt.created, true); assert.equal(result.receipt.delivery, delivery);
    assert.equal(system.emails(), 1); assert.equal(system.calls[1].args.p_succeeded, succeeded);
  }
});
test('interrupted email does not erase the confirmed invitation or retry delivery', async () => {
  const system = setup({ throwMail: true }); const result = await system.run();
  assert.equal(result.receipt.id, 'a1000000-0000-4000-8000-000000000001'); assert.equal(result.receipt.delivery, 'unknown');
  assert.equal(system.emails(), 1); assert.equal(system.calls.length, 1);
});
