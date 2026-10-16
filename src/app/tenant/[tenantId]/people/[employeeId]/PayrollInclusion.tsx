'use client';

import { useActionState, useId, useRef } from 'react';
import { Button, ButtonLink, Message, Panel, Switch } from '@/components/ui';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { changePayrollInclusion } from './payroll-inclusion-actions';
import type { InclusionState, PayrollInclusion as Snapshot } from './payroll-inclusion-rules';

export function PayrollInclusion({ tenant, employment, employee, employer, active, snapshot }: { tenant: string; employment: string; employee: string; employer: string; active: boolean; snapshot: Snapshot }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineId = useId();
  const formRef = useRef<HTMLFormElement>(null);
  const inFlight = useRef(false);
  const request = useRef<{ attempt: string; stamp: string; included: boolean } | null>(null);
  async function submit(previous: InclusionState, form: FormData): Promise<InclusionState> {
    request.current ??= { attempt: crypto.randomUUID(), stamp: previous.snapshot.stamp, included: !previous.snapshot.included };
    for (const [key, value] of Object.entries(request.current)) form.set(key, String(value));
    try {
      const next = await changePayrollInclusion(previous, form);
      if (!next.uncertain) request.current = null;
      return next;
    } catch {
      return { ...previous, saved: false, uncertain: true, error: 'لم تصل نتيجة مؤكدة. استعد نتيجة التغيير بنفس الاختيار.' };
    } finally {
      inFlight.current = false;
    }
  }
  const [state, action, pending] = useActionState(submit, { snapshot, saved: false, error: '', uncertain: false, stale: false });
  const current = state.snapshot;
  return <Panel aria-label="إدراج الموظف في الرواتب">
    <h2>إدراج الموظف في الرواتب</h2>
    <p>{current.included ? 'مشمول في حساب الرواتب.' : current.can_manage ? 'غير مشمول في حساب الرواتب. فعّل الاختيار ليظهر في المسير.' : 'غير مشمول في حساب الرواتب.'}</p>
    {current.can_manage && <form ref={formRef} action={action} onSubmit={event => { if (blockOfflineSubmission(event)) return; if (inFlight.current || pending) { event.preventDefault(); return; } inFlight.current = true; }}>
      <input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employment" value={employment}/>
      <div className="workspace-form-actions"><Switch checked={current.included} pending={pending} label="مشمول في الرواتب" disabled={offline || state.stale || state.uncertain} onCheckedChange={() => formRef.current?.requestSubmit()} aria-describedby={offline ? offlineId : undefined}/><span>مشمول في الرواتب</span></div>
      {state.uncertain && <Button type="submit" disabled={offline || pending}>استعادة نتيجة التغيير</Button>}
      {offline && <OfflineSubmissionNotice id={offlineId} purpose={state.uncertain ? 'recovery' : 'continuation'}/>}
    </form>}
    {state.error && <Message tone="bad" role="alert">{state.error}</Message>}
    {state.saved && <Message tone="ok" role="status">حُفظ الاختيار. أعد حساب المسير لتطبيقه؛ لم يتغير الأجر أو يُسجل صرف. <ButtonLink variant="ghost" href={`/tenant/${tenant}/payroll/runs?employer=${employer}`}>مراجعة المسير وإعادة حسابه</ButtonLink></Message>}
    {state.stale && <a className="inline-action" href={`/tenant/${tenant}/people/${employee}`}>تحديث حالة الموظف</a>}
    {current.locked && <p>يرتبط التوظيف برواتب مقفلة. تغيير إدراجه يحتاج مراجعة أثره من <a href={`/tenant/${tenant}/payroll/corrections?person=${employee}`}>تصحيح الرواتب</a>.</p>}
    {!current.can_manage && !current.locked && <p>{active ? 'تعديل الاختيار يحتاج صلاحيات عرض وإدارة الموظفين وإدارة علاقة العمل.' : 'انتهت علاقة العمل؛ لا يمكن تغيير إدراجها من هنا. راجع سجل التوظيف.'}</p>}
  </Panel>;
}
