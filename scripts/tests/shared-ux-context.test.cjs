/* eslint-disable @typescript-eslint/no-require-imports */
const { test } = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), ts = require('typescript');
const root = path.resolve(__dirname, '../..');
function load(file, dependencies = {}) {
  const code = ts.transpileModule(fs.readFileSync(path.join(root, file), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2017, jsx: ts.JsxEmit.ReactJSX } }).outputText;
  const m = { exports: {} };
  new Function('require', 'module', 'exports', code)(name => Object.hasOwn(dependencies, name) ? dependencies[name] : require(name), m, m.exports);
  return m.exports;
}
const { safeAuthNext } = load('src/app/auth/safe-next.ts');
const id = 'a1000000-0000-4000-8000-000000000001';
test('all actual tenant page destinations remain reachable after authentication', () => {
  const folder = path.join(root, 'src/app/tenant');
  const files = fs.readdirSync(folder, { recursive: true }).filter(file => path.basename(file) === 'page.tsx');
  assert.ok(files.length > 50, 'Use the actual current route inventory');
  for (const file of files) {
    const route = '/tenant/' + path.dirname(file).replaceAll(path.sep, '/').replace('[kind]', 'departments').replace(/\[[^\]]+\]/g, id);
    assert.equal(safeAuthNext(route), route, file);
  }
});
test('task queries survive without permitting unknown pages, traversal, controls or external returns', () => {
  const tasks = [`/tenant/${id}/people/${id}?tab=account&return=${encodeURIComponent(`/tenant/${id}/people?q=EMP-7&page=2`)}`,
    `/tenant/${id}/leave/settings?choose_employer=1&q=${encodeURIComponent('شركة التدريب')}&after_name=Company&after_id=${id}`,
    `/tenant/${id}/payroll/setup/configuration?employer=${id}`, `/tenant/${id}/me/leave?page=2&bal=3`];
  for (const next of tasks) assert.equal(safeAuthNext(next), next);
  for (const next of [`https://external.invalid/tenant/${id}/people`, `//external.invalid/tenant/${id}/people`,
    `/tenant/${id}/people/../people`, `/tenant/${id}/people/%2f${id}`, `/tenant/${id}/people/api`, `/tenant/${id}/payroll/reports/export`,
    `/tenant/${id}/people?q=%0a`, `/tenant/${id}/leave/settings?q=%1f`, `/tenant/${id}/people?q=%7f`, `/tenant/${id}/people?q=has space`,
    `/tenant/${id}/people#fragment`, `/tenant/${id}/people?q=${'a'.repeat(8200)}`]) assert.equal(safeAuthNext(next), '', next);
});
test('settings links preserve custom styles and size without forwarding legacy button classes', () => {
  const ButtonLink = () => null, NativeLink = () => null;
  const { SettingsLink } = load('src/app/tenant/[tenantId]/leave/settings/SettingsLink.tsx', { '@/components/ui': { ButtonLink }, 'next/link': { default: NativeLink } });
  const button = SettingsLink({ href: '/task', className: 'primary-button ui-button-lg scoped_return', ariaLabel: 'عودة', children: 'عودة' });
  assert.equal(button.type, ButtonLink); assert.equal(button.props.variant, 'solid'); assert.equal(button.props.size, 'lg');
  assert.equal(button.props.className, 'scoped_return'); assert.equal(button.props['aria-label'], 'عودة');
  assert.equal(SettingsLink({ href: '/task', className: 'danger-button scoped_danger', children: 'عرض' }).props.variant, 'danger');
  const plain = SettingsLink({ href: '/task', className: 'module_primary-button_custom', children: 'عرض' });
  assert.equal(plain.type, NativeLink); assert.equal(plain.props.className, 'module_primary-button_custom');
});
test('chooser retries and real signed-out redirect retain explicit choice, search and cursor', async () => {
  const rules = load('src/app/tenant/[tenantId]/leave/settings/rules.ts');
  const query = { choose_employer: '1', q: 'Training', after_name: 'Company', after_id: id };
  let client = null;
  const page = load('src/app/tenant/[tenantId]/leave/settings/page.tsx', {
    '@/components/ui': {}, '@/components/context-navigation': {}, './SettingsLink': {}, './StatusCard': { StatusCard: () => null }, './settings.module.css': {}, './rules': rules,
    './access-gate': { GATE_TEXT: { 'no-client': { title: 'Unavailable', detail: 'Retry' } } },
    '@/lib/workspace-access': { getWorkspaceClient: async () => client, getWorkspaceUser: async () => ({ data: { user: null } }) },
    'next/navigation': { notFound: () => { throw Error('not found'); }, redirect: href => { throw Object.assign(Error('Redirect'), { href }); } },
  }).default;
  const retry = (await page({ params: Promise.resolve({ tenantId: id }), searchParams: Promise.resolve(query) })).props.retryPath;
  assert.equal(new URL(retry, 'https://workspace.invalid').searchParams.get('choose_employer'), '1');
  assert.equal(new URL(retry, 'https://workspace.invalid').searchParams.get('after_id'), id);
  client = {};
  await assert.rejects(() => page({ params: Promise.resolve({ tenantId: id }), searchParams: Promise.resolve(query) }), error => {
    const next = new URL(error.href, 'https://workspace.invalid').searchParams.get('next');
    assert.equal(next, retry); assert.equal(safeAuthNext(next), next); return true;
  });
});
