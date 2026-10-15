import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import test from 'node:test';
import ts from 'typescript';
const require = createRequire(import.meta.url);
const cache = new Map();
function load(file) {
  file = path.resolve(file);
  if (cache.has(file)) return cache.get(file).exports;
  const loaded = { exports: {} }; cache.set(file, loaded);
  const compiled = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true } });
  const localRequire = name => {
    // Client construction is a network boundary; all actual reads use the SDK
    // transport fixture supplied below. Internal workspace/cache/parsers are real.
    if (name === '@/lib/supabase/server') return { createSupabaseServerClient: () => { throw Error('Unexpected client construction'); } };
    if (name.startsWith('@/')) return load(`src/${name.slice(2)}.ts`);
    if (name.startsWith('.')) return load(path.resolve(path.dirname(file), `${name}.ts`));
    return require(name);
  };
  vm.runInThisContext(`(function(require,module,exports){${compiled.outputText}\n})`, { filename: file })(localRequire, loaded, loaded.exports);
  return loaded.exports;
}
const { readCompanyReadiness } = load('src/app/tenant/[tenantId]/company-readiness.ts');
const tenant = 'c4350000-0000-4000-8000-000000000001', employer = 'c4350000-0000-4000-8000-000000000002';
const basic = { default_legal_entity: { id: employer }, default_site: { id: employer } };
const today = overrides => ({ work: [], own: [], followUp: [], unavailable: [], date: '2026-10-15', tenantId: tenant, mobile: null, payrollSetup: null, ...overrides });
const transport = responses => ({ rpc: async name => {
  if (!(name in responses)) return { data: null, error: { code: '42501' } };
  const result = responses[name]; if (result instanceof Error) throw result;
  return { data: result, error: null };
} });

test('unavailable optional reads stay unknown while verified basic setup survives', async () => {
  const rpcNames = ['people_access_snapshot', 'leave_access_snapshot', 'attendance_channel_access', 'tenant_entities_sites_snapshot', 'payroll_access_snapshot'];
  const items = await readCompanyReadiness(transport(Object.fromEntries(rpcNames.map(name => [name, Error('Offline')]))), tenant, 'qa@example.test', basic, today({ unavailable: ['الحضور'] }));
  assert.equal(items.find(item => item.title === 'الجهة والفرع الأساسيان').state, 'done');
  assert.ok(items.filter(item => item.title !== 'الجهة والفرع الأساسيان').every(item => item.state === 'unknown'));
  assert.ok(items.every(item => !/0 موظف|لا توجد أرصدة/.test(item.detail)));
});

test('denied setup domains hand off to responsible roles without exposing their actions', async () => {
  const items = await readCompanyReadiness(transport({}), tenant, 'qa@example.test', basic, today());
  for (const title of ['الموظفون', 'الإجازات', 'الرواتب', 'وسائل الحضور']) {
    const item = items.find(item => item.title === title);
    assert.equal(item.state, 'other-role'); assert.ok(item.owner); assert.equal(item.action, undefined);
  }
});

test('leave setup uses its actual next step only while enabled and payroll viewer gets no setup authority', async () => {
  for (const enabled of [true, false]) {
    const client = transport({
      people_access_snapshot: { can_view: true }, attendance_channel_access: { can_view: true },
      tenant_entities_sites_snapshot: { entities: [{ id: employer, is_active: true }] },
      leave_access_snapshot: { can_view: true, can_manage: true, new_work_enabled: enabled },
      leave_configuration_snapshot: { calendars: [], year_periods: [], types: [] },
      payroll_access_snapshot: { can_view: true, can_manage: false },
    });
    const items = await readCompanyReadiness(client, tenant, 'qa@example.test', basic, today({ work: [{ title: 'الموظفون' }], payrollSetup: { employerId: employer, name: 'QA', configured: false, canManage: false, enabled: true } }));
    const leave = items.find(item => item.title === 'الإجازات');
    assert.equal(leave.state, enabled ? 'todo' : 'other-role');
    assert.equal(leave.action.href.endsWith('/calendars/new'), enabled);
    const payroll = items.find(item => item.title === 'الرواتب');
    assert.equal(payroll.state, 'other-role'); assert.equal(payroll.owner, 'مدير دورة الرواتب');
    assert.equal(payroll.action.label, 'راجع دورة الرواتب');
    assert.equal(items.find(item => item.title === 'وسائل الحضور').state, 'unknown');
  }
});
