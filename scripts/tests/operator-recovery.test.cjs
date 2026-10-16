/* eslint-disable @typescript-eslint/no-require-imports */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), ts = require('typescript');
const { renderToStaticMarkup } = require('react-dom/server');
const { createElement: h } = require('react');
const root = path.resolve(__dirname, '../..');
function load(file, dependencies = {}) {
  const code = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2017, jsx: ts.JsxEmit.ReactJSX } }).outputText;
  const m = { exports: {} };
  new Function('require', 'module', 'exports', code)(name => Object.hasOwn(dependencies, name) ? dependencies[name] : require(name), m, m.exports);
  return m.exports;
}
const tenant = 'a1000000-0000-4000-8000-000000000001', key = 'a1000000-0000-4000-8000-000000000002';
const { safeAuthNext } = load('src/app/auth/safe-next.ts');
const operatorRead = load('src/lib/operator-read.ts');
const ui = { Panel: ({ children }) => h('section', null, children), Banner: ({ children }) => h('p', null, children),
  PageHeader: ({ title }) => h('h1', null, title), ButtonLink: ({ href, children }) => h('a', { href }, children) };
const context = load('src/app/operator/companies/company-context.ts', {
  '../operator-list-controls': load('src/app/operator/operator-list-controls.tsx', { '@/components/ui': ui }) });
const recovery = load('src/app/operator/OperatorRecovery.tsx', { '@/components/ui': ui });
const authority = { active: true, onboard: true, commercial: true, lifecycle: true, userId: key, partial: false, session: 'verified' };
function page(area, state, result = { error: true }) {
  const reads = [];
  const client = { rpc: async name => { reads.push(name); return result; } };
  const dependencies = { '@/components/ui': ui, '@/lib/operator-authority': { readOperatorAuthority: async () => state },
    '@/lib/workspace-access': { getWorkspaceClient: async () => client }, '@/lib/operator-read': operatorRead,
    'next/navigation': { redirect: href => { throw Object.assign(Error('Redirect'), { href }); } },
    '../../OperatorRecovery': recovery, '../../../OperatorRecovery': recovery,
    '../../onboarding/OnboardingResult': {}, './CompanySetup': {}, './setup.css': {}, '../company-workspace.css': {},
    '../../company-context': context, '../CompanyHeader': {}, './ServiceManager': {}, './LimitManager': {}, './LifecycleManager': {},
    '@/lib/operator-services': { serviceSnapshot: () => false } };
  const file = area === 'new' ? 'src/app/operator/companies/new/page.tsx' : `src/app/operator/companies/[tenantId]/${area}/page.tsx`;
  return { run: query => load(file, dependencies).default({ params: Promise.resolve({ tenantId: tenant }), searchParams: Promise.resolve(query) }), reads };
}
test('login return preserves a known company attempt or company selection only', () => {
  for (const destination of ['/operator/companies/new', `/operator/companies/new?mode=existing&key=${key}`, '/operator/companies?q=%D8%B4%D8%B1%D9%83%D8%A9&page=2',
    ...['services', 'limits', 'status'].map(area => `/operator/companies/${tenant}/${area}?q=test&page=2`)]) assert.equal(safeAuthNext(destination), destination);
  for (const bad of ['https://external.invalid/operator/companies/new', '//external.invalid/operator/companies/new', '/operator/companies/new?mode=other',
    '/operator/companies/new?key=invalid', `/operator/companies/new?key=${key}&key=${key}`, '/operator/companies/new?next=https://external.invalid',
    '/operator/companies/new/../new', '/operator/companies/new#fragment', '/operator/companies?q=%0d%0a', '/operator/companies?q=%00',
    '/operator/companies?page=0', '/operator/companies?page=2&page=3', '/operator/companies?q='+ 'a'.repeat(121), '/operator/companies/%2f/new']) assert.equal(safeAuthNext(bad), '', bad);
});
test('signed-out creation carries the exact valid attempt through the real login allowlist', async () => {
  const p = page('new', { ...authority, session: 'signed-out' });
  await assert.rejects(() => p.run({ mode: 'existing', key }), error => {
    const url = new URL(error.href, 'https://workspace.invalid');
    assert.equal(url.pathname, '/auth/login'); assert.equal(safeAuthNext(url.searchParams.get('next')), `/operator/companies/new?mode=existing&key=${key}`); return true;
  });
  assert.deepEqual(p.reads, []);
});
test('denied creation offers an authorized exit without creating or reading an attempt', async () => {
  const p = page('new', { ...authority, active: false, onboard: false, commercial: false, lifecycle: false });
  const html = renderToStaticMarkup(await p.run({ mode: 'existing', key }));
  assert.match(html, /href="\/tenant\/select"/); assert.match(html, /العودة إلى مساحتي/); assert.doesNotMatch(html, /إعادة المحاولة/); assert.deepEqual(p.reads, []);
});
test('partial authority offers read retry retaining attempt and mode, never a write', async () => {
  for (const state of [{ ...authority, onboard: false, partial: true }, { ...authority, active: false, onboard: false, session: 'unconfigured' }]) {
    const p = page('new', state), html = renderToStaticMarkup(await p.run({ mode: 'existing', key }));
    assert.match(html, /إعادة المحاولة/); assert.match(html, new RegExp(`mode=existing&amp;key=${key}`)); assert.doesNotMatch(html, /هذا الحساب لا يملك/); assert.deepEqual(p.reads, []);
  }
});
test('invalid attempt has a clear recovery exit and does not generate a new setup', async () => {
  const p = page('new', authority);
  const html = renderToStaticMarkup(await p.run({ key: 'invalid' }));
  assert.match(html, /مرجع المحاولة غير صالح/); assert.match(html, /العودة إلى الشركات/); assert.deepEqual(p.reads, []);
});
test('services, limits and status failures retain company query and use read-only retries', async () => {
  for (const area of ['services', 'limits', 'status']) {
    const partial = page(area, { ...authority, commercial: false, lifecycle: false, partial: true });
    const html = renderToStaticMarkup(await partial.run({ q: 'company', page: '2' }));
    assert.match(html, new RegExp(`/${area}\\?q=company&amp;page=2`)); assert.match(html, /العودة إلى تشغيل المنصة/); assert.deepEqual(partial.reads, []);
    const failedRead = page(area, authority);
    const failedHtml = renderToStaticMarkup(await failedRead.run({ q: 'company', page: '2' }));
    assert.match(failedHtml, /لم تتأكد الحالة الحالية/); assert.match(failedHtml, /العودة إلى الشركات/); assert.equal(failedRead.reads.length, 1);
    assert.match(failedRead.reads[0], /^(platform_tenant_entitlement_snapshot|platform_tenant_commercial_snapshot|platform_tenant_lifecycle_get)$/);
  }
});
