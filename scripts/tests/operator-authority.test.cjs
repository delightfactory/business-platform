/* eslint-disable @typescript-eslint/no-require-imports */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

const root = path.resolve(__dirname, '../..');
process.env.NEXT_PUBLIC_SUPABASE_URL = 'http://127.0.0.1:55321';
process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = 'synthetic-test-key';
delete process.env.SUPABASE_INTERNAL_URL;
function loadSource(relativePath, dependencies) {
  const source = fs.readFileSync(path.join(root, relativePath), 'utf8');
  const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
  const loaded = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(name => dependencies[name] ?? require(name), loaded, loaded.exports);
  return loaded.exports;
}

// Run the real workspace/server wrappers; substitute only the external SDK and request cookies.
function authorityWithResponses({ status = { data: 'active', error: null }, replies = {}, identity } = {}) {
  const requested = [];
  const client = { auth: { getUser: async () => identity ?? { data: { user: { id: 'synthetic-operator' } }, error: null } }, rpc: async name => {
    requested.push(name);
    const response = name === 'current_platform_operator_status' ? status : replies[name] ?? { data: true, error: null };
    if (response instanceof Error) throw response;
    return response;
  } };
  const server = loadSource('src/lib/supabase/server.ts', {
    '@supabase/ssr': { createServerClient: () => client },
    'next/headers': { cookies: async () => ({ getAll: () => [], set: () => {} }) },
  });
  const workspace = loadSource('src/lib/workspace-access.ts', { '@/lib/supabase/server': server });
  const permission = loadSource('src/lib/operator-access.ts', {});
  const authority = loadSource('src/lib/operator-authority.ts', {
    './workspace-access': workspace, './operator-access': permission,
  });
  return { read: authority.readOperatorAuthority, requested };
}

test('inactive or unverifiable operator never receives task access', async () => {
  for (const status of [{ data: 'revoked', error: null }, { data: null, error: { message: 'unavailable' } }]) {
    const { read, requested } = authorityWithResponses({ status });
    const authority = await read();
    assert.equal(authority.active, false);
    assert.deepEqual([authority.manage, authority.onboard, authority.lifecycle, authority.commercial, authority.statutory], [false, false, false, false, false]);
    assert.deepEqual(requested, ['current_platform_operator_status']);
  }
});

test('failed permission closes only that task and keeps confirmed commercial access', async () => {
  const { read } = authorityWithResponses({ replies: {
    current_operator_can_manage_operators: new Error('network interruption'),
    current_operator_can_manage_tenant_lifecycle: { data: true, error: { message: 'RPC failed' } },
    current_operator_can_onboard_tenants: { data: 'true', error: null },
  } });
  const authority = await read();
  assert.equal(authority.active, true);
  assert.equal(authority.partial, true);
  assert.equal(authority.manage, false);
  assert.equal(authority.lifecycle, false);
  assert.equal(authority.onboard, false);
  assert.equal(authority.commercial, true);
  assert.equal(authority.statutory, true);
});

test('missing session returns sign-in recovery without checking operator permissions', async () => {
  const { read, requested } = authorityWithResponses({ identity: {
    data: { user: null }, error: { name: 'AuthSessionMissingError' },
  } });
  assert.equal((await read()).session, 'signed-out');
  assert.equal(requested.length, 0);
});

test('authentication failure is unavailable rather than successful or signed out', async () => {
  const { read, requested } = authorityWithResponses({ identity: {
    data: { user: null }, error: { name: 'AuthRetryableFetchError' },
  } });
  const authority = await read();
  assert.equal(authority.session, 'unavailable');
  assert.equal(authority.active, false);
  assert.equal(requested.length, 0);
});
