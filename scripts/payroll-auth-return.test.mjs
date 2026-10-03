import test from 'node:test';
import assert from 'node:assert/strict';
import {safeAuthNext} from '../src/app/auth/safe-next.ts';

const tenant='d2621000-0000-4000-8000-000000000001';
test('payroll session recovery preserves the exact internal selection',()=>{
  for(const page of ['', '/setup', '/inputs', '/runs', '/output', '/payments', '/advances', '/corrections', '/reports']){
    const next=`/tenant/${tenant}/payroll${page}?employer=d2623000-0000-4000-8000-000000000001&output=d2630000-0000-4000-8000-000000000001&case=7e7b3829-41b2-41e4-bf5d-05c79a361f93&q=%D8%A3%D8%AD%D9%85%D8%AF`;
    assert.equal(safeAuthNext(next),next,page||'overview');
  }
});
test('payroll return rejects external destinations, unknown routes and header controls',()=>{
  for(const next of ['https://example.invalid', '//example.invalid', `/tenant/${tenant}/payroll/../auth`, `/tenant/${tenant}/payroll/export`, `/tenant/${tenant}/payroll/reports/export`, `/tenant/${tenant}/payroll\\reports`, `/tenant/${tenant}/payroll?x=1\r\nLocation:https://example.invalid`, `/tenant/${tenant}/payroll?x=%0d%0a`, `/tenant/${tenant}/payroll?x=%00`, `/tenant/${tenant}/payroll#fragment`, `/tenant/${tenant}/payroll?q=${'a'.repeat(8192)}`]){
    assert.equal(safeAuthNext(next),'');
  }
});
test('existing supported login returns remain valid',()=>{
  for(const next of [`/tenant/${tenant}`, '/operator/onboarding', `/auth/invitations/accept?id=${tenant}&issuance=1`])assert.equal(safeAuthNext(next),next);
});
