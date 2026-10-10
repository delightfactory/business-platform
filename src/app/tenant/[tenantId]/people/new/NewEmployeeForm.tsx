'use client';
import { ButtonLink, Checkbox, EmptyState, Field, Input, Message, Select } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { createEmployeeAction, type NewEmployeeState } from '../actions';
import styles from '../people.module.css';

type Named = { id: string; name: string };
type Site = Named & { employer_id: string };
type Job = Named & { department_id: string | null };
export type OnboardingOptions = { employers: Named[]; sites: Site[]; departments: Named[]; jobs: Job[] };

export function NewEmployeeForm({ tenantId, options }: { tenantId: string; options: OnboardingOptions }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const employers = Array.isArray(options.employers) ? options.employers : [];
  const sites = Array.isArray(options.sites) ? options.sites : [];
  const departments = Array.isArray(options.departments) ? options.departments : [];
  const jobs = Array.isArray(options.jobs) ? options.jobs : [];
  const initial: NewEmployeeState = { code: '', name: '', employerId: employers[0]?.id ?? '',
    siteId: sites.find((site) => site.employer_id === employers[0]?.id)?.id ?? '',
    departmentId: '', jobId: '', startDate: new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date()),
    payBasis: 'monthly', amount: '', payrollEligible: true, error: '', attempt: 0 };
  const [state, action, actionPending] = useActionState(createEmployeeAction, initial);
  const [employerChoice, setEmployerChoice] = useState<string | null>(null);
  const [departmentChoice, setDepartmentChoice] = useState<string | null>(null);
  const employerId = employerChoice ?? state.employerId;
  const departmentId = departmentChoice ?? state.departmentId;
  const visibleSites = sites.filter((site) => site.employer_id === employerId);
  const visibleJobs = jobs.filter((job) => !job.department_id || job.department_id === departmentId);
  if (employers.length === 0 || sites.length === 0) return <div ><EmptyState title={<>أكمل إعداد الشركة أولًا</>} description={<>يلزم وجود جهة توظيف وفرع نشط قبل إضافة موظف.</>} action={<><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/entities-sites`}>الجهات والفروع</ButtonLink></>} /></div>;

  const showOffline0 = offline && !actionPending;
  return <form key={state.attempt} action={action} className="auth-form compact-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <fieldset className={styles.formGroup}><legend>بيانات الموظف</legend>
    <Field id="employee-code" label={<>رمز الموظف</>} required><Input id="employee-code" name="code" required maxLength={40} autoFocus defaultValue={state.code} /></Field>
    <Field id="employee-name" label={<>اسم الموظف</>} required><Input id="employee-name" name="name" required minLength={2} maxLength={160} defaultValue={state.name} /></Field>
    <p className="field-hint">يمكن إنشاء حساب دخول وربطه بالموظف لاحقًا؛ الملف الوظيفي لا يحتاج إلى حساب.</p>
    </fieldset>

    <fieldset className={styles.formGroup}><legend>العمل والفرع</legend>
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

    <fieldset className={styles.formGroup}><legend>الأجر الأساسي</legend>
    <Field id="employee-pay-basis" label={<>طريقة الأجر</>}><Select id="employee-pay-basis" name="payBasis" defaultValue={state.payBasis}>
      <option value="monthly">شهري</option><option value="daily">يومي</option>
    </Select></Field>
    <Field id="employee-amount" label={<>الأجر الأساسي بالجنيه المصري</>} required><Input id="employee-amount" name="amount" type="number" min="0" max="999999999999.99" step="0.01"
      inputMode="decimal" required defaultValue={state.amount} /></Field>
    <label className="checkbox-row" htmlFor="employee-payroll-eligible">
      <Checkbox id="employee-payroll-eligible" name="payrollEligible"  defaultChecked={state.payrollEligible} />
      <span>يُدرج في كشوف الرواتب عند تفعيل الرواتب</span>
    </label>
    </fieldset>
    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    <div className="workspace-form-actions"><SubmitButton label="إضافة الموظف" pendingLabel="جارٍ إضافة الموظف…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>إلغاء</ButtonLink></div>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
