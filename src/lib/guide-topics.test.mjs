import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';
const ts = createRequire(import.meta.url)('typescript');
const exports = {};
runInNewContext(ts.transpileModule(readFileSync(new URL('./guide-topics.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText, { exports });
const { tenantGuideTopics, operatorGuideTopics } = exports;
const snapshot = data => ({ data });
const list = value => Array.from(value).sort();

test('employee finance roles receive the direct-entry guide without payroll preparation authority',()=>{
  for(const flag of ['employee_finance.view','employee_finance.manage','employee_finance.approve'])
    assert.deepEqual(list(tenantGuideTopics({inputs:snapshot({[flag]:true})})),['employee-finance']);
});

test('read-only payroll and people accounts do not receive mutation task recommendations', () => {
  assert.deepEqual(list(tenantGuideTopics({ people: snapshot({ can_view: true }), runs: snapshot({ can_view: true, can_prepare: false }), payments: snapshot({ can_record: false }) })), ['payroll-view', 'people-view']);
});
test('self service topics stay separate from managing the team', () => {
  assert.deepEqual(list(tenantGuideTopics({ employee: snapshot({ employee: {} }), mobile: snapshot({}), leave: snapshot({ self_access: true, can_view: false }) })), ['profile', 'self-attendance', 'self-leave']);
});
test('finance-only reports recommend advances without the payroll calculation path', () => {
  assert.deepEqual(list(tenantGuideTopics({ navigation: snapshot({ can_view_advances: true, can_view_reports: true, report_kind: 'advances' }) })), ['advances']);
});
test('independent prepare, approve, payment and correction grants combine without inventing grants', () => {
  assert.deepEqual(list(tenantGuideTopics({ runs: snapshot({ can_prepare: true }), inputs: snapshot({ 'payroll.approve': true }), payments: snapshot({ can_record: true }), corrections: snapshot({ can_correct: false }) })), ['payroll-approve', 'payroll-payments', 'payroll-prepare']);
});
test('failed snapshots cannot recommend tasks even if stale data contains true', () => {
  assert.deepEqual(list(tenantGuideTopics({ people: { data: { can_manage: true }, error: { code: '42501' } }, payments: { data: { can_record: true }, error: 'network' } })), []);
  assert.deepEqual(list(tenantGuideTopics({})), []);
});
test('closing and approval follow separate run access flags', () => {
  assert.deepEqual(list(tenantGuideTopics({ runs: snapshot({ can_view: true, can_lock: true, can_approve: false }) })), ['payroll-close', 'payroll-view']);
});
test('operator tasks follow the actual independent authority flags', () => {
  const authority = { active: true, lifecycle: false, commercial: true, onboard: false, manage: false, statutory: false };
  assert.deepEqual(list(operatorGuideTopics(authority)), ['operator-commercial', 'operator-companies']);
  assert.deepEqual(list(operatorGuideTopics({ ...authority, active: false, manage: true })), []);
});

