import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import ts from 'typescript';

// Pure production navigation/return logic: no network or internal-helper mocks.
function load(file) {
  const loaded = { exports: {} };
  const compiled = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } });
  vm.runInThisContext(`(function(module,exports){${compiled.outputText}\n})`, { filename: file })(loaded, loaded.exports);
  return loaded.exports;
}
const { workspaceAreas } = load('src/components/shell/navigation-model.ts');
const { safeReturn } = load('src/lib/return-to.ts');
const tenant = 'c4350000-0000-4000-8000-000000000001';
const home = `/tenant/${tenant}`;
const links = paths => paths.map(path => ({ href: `${home}/${path}`, label: path }));

test('team navigation prioritizes attendance and payroll overview regardless of input order', () => {
  const areas = workspaceAreas(home, links(['leave/settings', 'payroll/setup', 'attendance/sources', 'payroll/inputs', 'leave', 'payroll/runs', 'attendance/review', 'leave/balances', 'attendance', 'payroll', 'me']), [], 'tenant');
  assert.deepEqual(areas.find(area => area.key === 'time').links.map(link => link.label), ['attendance', 'attendance/review', 'leave', 'leave/balances', 'attendance/sources', 'leave/settings']);
  assert.deepEqual(areas.find(area => area.key === 'payroll').links.map(link => link.label), ['payroll', 'payroll/runs', 'payroll/inputs', 'payroll/setup']);
});

test('employee home is daily workspace and attendance history remains separate without inventing team access', () => {
  const areas = workspaceAreas(`${home}/me`, links(['me/attendance', 'me/leave', 'me']), [], 'tenant');
  assert.deepEqual(areas.map(area => [area.label, area.destination.href]), [['يومي', `${home}/me`], ['إجازاتي', `${home}/me/leave`], ['سجلي', `${home}/me/attendance`]]);
  const attendanceOnly = workspaceAreas(home, links(['me/attendance']), [], 'tenant');
  assert.equal(attendanceOnly[0].destination.href, home);
});

test('limited team roles expose only their authorized areas and retain team navigation with self service', () => {
  for (const [paths, expected] of [
    [['people'], ['today', 'people']],
    [['payroll/runs'], ['today', 'payroll']],
    [['attendance', 'leave'], ['today', 'time']],
    [['people', 'me', 'me/attendance', 'me/leave'], ['today', 'people']],
    [[], ['today']],
  ]) assert.deepEqual(workspaceAreas(home, links(paths), [], 'tenant').map(area => area.key), expected);
});

test('return context rejects tenant escapes and unsafe location syntax while preserving business context', () => {
  const valid = `${home}/payroll/runs?employer=${tenant}&period=${tenant}#review`;
  assert.equal(safeReturn(tenant, valid), valid);
  for (const raw of ['https://elsewhere.test', '//elsewhere.test', `${home}evil/people`, '/tenant/c4350000-0000-4000-8000-000000000002/people', `${home}/../../operator`, `${home}/%2e%2e/%2e%2e/operator`, `${home}/people%0d%0aLocation:evil`, `${home}/people\\evil`, `${home}/people?x=hello\nworld`, `${home}/people%2f..`]) {
    assert.equal(safeReturn(tenant, raw), null, raw);
  }
});

test('operator areas retain their accepted destinations and role-filtered inputs', () => {
  const admin = ['companies', 'invitations', 'team', 'statutory'].map(key => ({ href: `/operator/${key}`, label: key }));
  const areas = workspaceAreas('/operator', [], admin, 'operator');
  assert.deepEqual(areas.map(area => area.destination.href), ['/operator', ...admin.map(link => link.href)]);
  assert.deepEqual(workspaceAreas('/operator', [], [admin[0]], 'operator').map(area => area.key), ['today', 'companies']);
});
