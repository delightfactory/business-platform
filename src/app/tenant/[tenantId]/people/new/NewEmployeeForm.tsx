'use client';
import { Button, ButtonLink, Checkbox, EmptyState, Field, Input, Message, Select } from '@/components/ui';
import { useId, useRef, useSyncExternalStore } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { createEmployeeAction, type NewEmployeeState } from '../actions';
import styles from '../people.module.css';

type Named = { id: string; name: string };
type Site = Named & { employer_id: string };
type Job = Named & { department_id: string | null };
export type OnboardingOptions = { employers: Named[]; sites: Site[]; departments: Named[]; jobs: Job[] };
const subscribe = () => () => {};
const steps = ['بيانات الموظف', 'العمل والفرع', 'الراتب', 'المراجعة والإضافة'];

export function NewEmployeeForm({ tenantId, options, suggestedCode }: { tenantId: string; options: OnboardingOptions; suggestedCode: string }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const employers = Array.isArray(options.employers) ? options.employers : [];
  const sites = Array.isArray(options.sites) ? options.sites : [];
  const departments = Array.isArray(options.departments) ? options.departments : [];
  const jobs = Array.isArray(options.jobs) ? options.jobs : [];
  const initial: NewEmployeeState = { code: suggestedCode, name: '', employerId: employers[0]?.id ?? '',
    siteId: sites.find((site) => site.employer_id === employers[0]?.id)?.id ?? '',
    departmentId: '', jobId: '', startDate: new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date()),
    payBasis: 'monthly', amount: '', payrollEligible: true, error: '', attempt: 0 };
  const [state, action, actionPending] = useActionState(createEmployeeAction, initial);
  const [employerChoice, setEmployerChoice] = useState<string | null>(null);
  const [departmentChoice, setDepartmentChoice] = useState<string | null>(null);
  const [step, setStep] = useState(0);
  const [review, setReview] = useState<Record<string, string>>({});
  const form = useRef<HTMLFormElement>(null);
  const ready = useSyncExternalStore(subscribe, () => true, () => false);
  const employerId = employerChoice ?? state.employerId;
  const departmentId = departmentChoice ?? state.departmentId;
  const visibleSites = sites.filter((site) => site.employer_id === employerId);
  const visibleJobs = jobs.filter((job) => !job.department_id || job.department_id === departmentId);
  function goTo(next: number) {
    if (actionPending) return;
    if (next > step) {
      const controls = form.current?.querySelectorAll<HTMLInputElement | HTMLSelectElement>(`[data-step="${step}"] input, [data-step="${step}"] select`);
      for (const control of controls ?? []) if (!control.reportValidity()) return;
    }
    if (next === 3 && form.current) {
      const data = new FormData(form.current);
      setReview(Object.fromEntries(Array.from(data.entries()).filter((entry): entry is [string, string] => typeof entry[1] === 'string')));
    }
    setStep(next);
    requestAnimationFrame(() => form.current?.querySelector<HTMLElement>(`[data-step="${next}"] legend, [data-step="${next}"] h2`)?.focus());
  }
  if (employers.length === 0 || sites.length === 0) return <div ><EmptyState title={<>أكمل إعداد الشركة أولًا</>} description={<>يلزم وجود جهة توظيف وفرع نشط قبل إضافة موظف.</>} action={<><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/entities-sites`}>الجهات والفروع</ButtonLink></>} /></div>;

  const showOffline0 = offline && !actionPending;
  return <form ref={form} key={state.attempt} action={action} className="auth-form compact-form" aria-busy={actionPending}
    onKeyDown={(event) => { if (ready && step < 3 && event.key === 'Enter' && event.target instanceof HTMLInputElement) { event.preventDefault(); goTo(step + 1); } }}
    onInvalidCapture={(event) => {
      const target = event.target as HTMLElement;
      const area = target.closest<HTMLElement>('[data-step]');
      if (area) { setStep(Number(area.dataset.step)); requestAnimationFrame(() => target.focus()); }
    }}
    onSubmit={(event) => { if (blockOfflineSubmission(event)) return; if (ready && step < 3) { event.preventDefault(); goTo(step + 1); } }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    {ready && <ol className={styles.onboardingSteps} aria-label="خطوات إضافة الموظف">{steps.map((label, index) => <li key={label} aria-current={step === index ? 'step' : undefined}><span>{index + 1}</span>{label}</li>)}</ol>}
    <fieldset className={styles.formGroup} data-step="0" hidden={ready && step !== 0}><legend tabIndex={-1}>بيانات الموظف</legend>
    <Field id="employee-name" label={<>اسم الموظف</>} required><Input id="employee-name" name="name" required minLength={2} maxLength={160} autoFocus defaultValue={state.name}  placeholder="مثال: أحمد محمد"/></Field>
    <Field id="employee-code" label="رقم الموظف" help="جهّزنا رقمًا مقترحًا. يمكنك تغييره إذا كان للموظف رقم في شركتك، بشرط ألا يكون مستخدمًا." required><Input id="employee-code" name="code" required maxLength={40} defaultValue={state.code} placeholder="مثال: EMP-014"/></Field>
    </fieldset>

    <fieldset className={styles.formGroup} data-step="1" hidden={ready && step !== 1}><legend tabIndex={-1}>العمل والفرع</legend>
    <Field id="employee-employer" label={<>جهة التوظيف</>} required><Select id="employee-employer" name="employerId" required value={employerId}
      onChange={(event) => setEmployerChoice(event.target.value)}>
      {employers.map((employer) => <option key={employer.id} value={employer.id}>{employer.name}</option>)}
    </Select></Field>
    <Field id="employee-site" label={<>الفرع</>} required><Select key={`${state.attempt}-${employerId}`} id="employee-site" name="siteId" required
      defaultValue={visibleSites.some((site) => site.id === state.siteId) ? state.siteId : visibleSites[0]?.id ?? ''}>
      {visibleSites.length === 0 && <option value="">لا يوجد فرع نشط لهذه الجهة</option>}
      {visibleSites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
    </Select></Field>
    <Field id="employee-start" label={<>تاريخ بداية العمل</>} required><Input id="employee-start" name="startDate" type="date" required defaultValue={state.startDate} /></Field>
    {departments.length > 0 && <Field id="employee-department" label="القسم (اختياري)">
      <Select id="employee-department" name="departmentId" value={departmentId}
        onChange={(event) => setDepartmentChoice(event.target.value)}><option value="">دون تحديد الآن</option>
        {departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}</Select></Field>}
    {jobs.length > 0 && <Field id="employee-job" label="الوظيفة (اختياري)">
      <Select key={`${state.attempt}-${departmentId}`} id="employee-job" name="jobId"
        defaultValue={visibleJobs.some((job) => job.id === state.jobId) ? state.jobId : ''}>
        <option value="">دون تحديد الآن</option>
        {visibleJobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}</Select></Field>}
    </fieldset>

    <fieldset className={styles.formGroup} data-step="2" hidden={ready && step !== 2}><legend tabIndex={-1}>الراتب</legend>
    <Field id="employee-pay-basis" label={<>طريقة الأجر</>}><Select id="employee-pay-basis" name="payBasis" defaultValue={state.payBasis}>
      <option value="monthly">شهري</option><option value="daily">يومي</option>
    </Select></Field>
    <Field id="employee-amount" label={<>الأجر الأساسي بالجنيه المصري</>} required help="الأجر الأساسي بالجنيه المصري وفق طريقة الأجر المختارة، دون إضافة البدلات هنا."><Input id="employee-amount" name="amount" type="number" min="0" max="999999999999.99" step="0.01"
      inputMode="decimal" required defaultValue={state.amount}  placeholder="مثال: 5000.00"/></Field>
    <label className="checkbox-row" htmlFor="employee-payroll-eligible">
      <Checkbox id="employee-payroll-eligible" name="payrollEligible"  defaultChecked={state.payrollEligible} />
      <span>إضافة الموظف إلى مسيرات الرواتب</span>
    </label>
    </fieldset>
    {ready && <section data-step="3" hidden={step !== 3} className={styles.onboardingReview}>
      <h2 tabIndex={-1}>راجع بيانات الموظف</h2>
      <dl className="snapshot-grid">
        <div><dt>الاسم</dt><dd>{review.name}</dd></div><div><dt>رقم الموظف</dt><dd><bdi>{review.code}</bdi></dd></div>
        <div><dt>جهة العمل</dt><dd>{employers.find(item => item.id === review.employerId)?.name}</dd></div>
        <div><dt>الفرع</dt><dd>{sites.find(item => item.id === review.siteId)?.name}</dd></div>
        <div><dt>بداية العمل</dt><dd><bdi>{review.startDate}</bdi></dd></div>
        <div><dt>الأجر الأساسي</dt><dd>{review.amount} جنيه {review.payBasis === 'daily' ? 'يوميًا' : 'شهريًا'}</dd></div>
        <div><dt>مسيرات الرواتب</dt><dd>{review.payrollEligible === 'on' ? 'يُضاف إلى المسير' : 'غير مشمول'}</dd></div>
      </dl>
      <p className="field-hint">بعد الإضافة يفتح ملف الموظف لتحديد دوامه وإرسال دعوة حسابه.</p>
    </section>}
    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    {state.uncertainCode && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/people?${new URLSearchParams({ q: state.uncertainCode })}`}>تحقق في دليل الموظفين</ButtonLink>}
    <div className="workspace-form-actions">
      {ready && step < 3 ? <Button type="button" onClick={() => goTo(step + 1)} disabled={actionPending}>متابعة</Button> : <SubmitButton label="إضافة الموظف وفتح ملفه" pendingLabel="جارٍ إضافة الموظف…" ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>}
      {ready && step > 0 && <Button type="button" variant="ghost" onClick={() => goTo(step - 1)} disabled={actionPending}>السابق</Button>}
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>إلغاء</ButtonLink></div>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
