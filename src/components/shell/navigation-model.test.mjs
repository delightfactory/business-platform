import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const require = createRequire(import.meta.url);
const ts = require('typescript');
const source = readFileSync(new URL('./navigation-model.ts', import.meta.url), 'utf8');
const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
const exports = {};
runInNewContext(output, { exports, URLSearchParams });
const { workspaceMenu, payrollDestination, currentWorkspaceLocation } = exports;
const root = '/tenant/11111111-1111-4111-8111-111111111111';
const item = path => ({ href: `${root}/${path}`, label: path });
const flatten = menu => [...menu.areas.flatMap(area => [area.destination, ...area.links]), ...menu.settings, ...menu.personal];

test('current location distinguishes home, nested setup, unknown routes and operator aliases', () => {
  const menu = workspaceMenu(root, ['people','people/organization','attendance','attendance/sources'].map(item), [], 'tenant');
  assert.equal(currentWorkspaceLocation(root, root, menu, 'tenant').area.key, 'today');
  assert.equal(currentWorkspaceLocation(`${root}/unlisted`, root, menu, 'tenant').active, undefined);
  const setup = currentWorkspaceLocation(`${root}/people/organization/new`, root, menu, 'tenant');
  assert.equal(setup.active.href, `${root}/people/organization`);
  assert.equal(setup.area, undefined);
  const operator = workspaceMenu('/operator', [], [{href:'/operator/companies',label:'Companies'}], 'operator');
  assert.equal(currentWorkspaceLocation('/operator/tenants/123', '/operator', operator, 'operator').area.key, 'companies');
  assert.equal(currentWorkspaceLocation('/operator/unknown', '/operator', operator, 'operator').active, undefined);
});

const roles = [
  { name: 'team with setup and an unfamiliar authorized route', home: root, mode: 'tenant', business: ['people','people/organization','people/work-policies','attendance','attendance/sources','leave','leave/settings','payroll','payroll/setup','me','me/attendance','custom'].map(item), admin: ['users','entities-sites'].map(item) },
  { name: 'employee self service', home: `${root}/me`, mode: 'tenant', business: ['me','me/attendance','me/leave'].map(item), admin: [] },
  { name: 'settings only', home: root, mode: 'tenant', business: ['attendance/sources'].map(item), admin: ['users'].map(item) },
  { name: 'operator with unknown admin destination', home: '/operator', mode: 'operator', business: [], admin: ['companies','invitations','team','statutory','audit'].map(path => ({ href: `/operator/${path}`, label: path })) },
  { name: 'no granted destinations', home: root, mode: 'tenant', business: [], admin: [] },
];

for (const role of roles) test(`navigation keeps exactly the granted destinations: ${role.name}`, () => {
  const before = JSON.stringify(role);
  const menu = workspaceMenu(role.home, role.business, role.admin, role.mode);
  assert.deepEqual(new Set(flatten(menu).map(link => link.href)), new Set([role.home, ...role.business.map(link => link.href), ...role.admin.map(link => link.href)]));
  assert.equal(JSON.stringify(role), before, 'classification must not reorder the server input');
});

test('setup is separated from daily work and company setup is ordered first', () => {
  const menu = workspaceMenu(root, ['payroll/setup','attendance/sources','people','people/organization','leave/settings','payroll/runs'].map(item), ['users','entities-sites'].map(item), 'tenant');
  assert.equal(menu.settings[0].href, `${root}/entities-sites`);
  assert.equal(menu.settings[1].href, `${root}/users`);
  assert.ok(!menu.areas.flatMap(area => area.links).some(link => menu.settings.some(setting => setting.href === link.href)));
  assert.ok(menu.areas.some(area => area.links.some(link => link.href === `${root}/payroll/runs`)));
});

test('payroll navigation retains employer and period without replacing explicit destination context', () => {
  const employer = '22222222-2222-4222-8222-222222222222';
  const other = '33333333-3333-4333-8333-333333333333';
  const period = '44444444-4444-4444-8444-444444444444';
  const result = payrollDestination(`${root}/payroll/runs`, `${root}/payroll/inputs`, employer, period);
  assert.equal(result, `${root}/payroll/inputs?employer=${employer}&period=${period}`);
  const explicit = `${root}/payroll/inputs?employer=${other}`;
  assert.equal(payrollDestination(`${root}/payroll/runs`, explicit, employer, period), explicit);
  assert.equal(payrollDestination(`${root}/payroll/runs`, `${root}/payroll`, employer, period), `${root}/payroll?employer=${employer}`, 'the payroll menu opens the collection rather than forcing the previously selected run');
});

test('attendance, leave, payroll, advances and reports have direct independent entries',()=>{
  const menu=workspaceMenu(root,['attendance','attendance/calendar','leave','leave/balances','payroll','payroll/advances','payroll/reports'].map(item),[],'tenant');
  assert.deepEqual(Array.from(menu.areas,area=>area.key),['today','time','leave','payroll','advances','reports']);
  assert.equal(menu.areas.find(area=>area.key==='leave').destination.href,`${root}/leave`);
  assert.equal(menu.areas.find(area=>area.key==='payroll').destination.href,`${root}/payroll`);
});


test('attendance calendar keeps daily work destination and deepest active context',()=>{
 const menu=workspaceMenu(root,['attendance','attendance/calendar','attendance/review'].map(item),[],'tenant');
 assert.equal(currentWorkspaceLocation(`${root}/attendance/calendar`,root,menu,'tenant').active.href,`${root}/attendance/calendar`);
 assert.equal(currentWorkspaceLocation(`${root}/attendance/00000000-0000-4000-8000-000000000001`,root,menu,'tenant').active.href,`${root}/attendance`);
 assert.equal(menu.areas.find(area=>area.key==='time').destination.href,`${root}/attendance`);
});
