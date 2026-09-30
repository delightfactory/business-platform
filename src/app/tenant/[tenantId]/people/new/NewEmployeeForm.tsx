'use client';

import Link from 'next/link';
import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { createEmployeeAction, type NewEmployeeState } from '../actions';

type Named = { id: string; name: string };
type Site = Named & { employer_id: string };
type Job = Named & { department_id: string | null };
export type OnboardingOptions = { employers: Named[]; sites: Site[]; departments: Named[]; jobs: Job[] };

export function NewEmployeeForm({ tenantId, options }: { tenantId: string; options: OnboardingOptions }) {
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
  const [state, action] = useActionState(createEmployeeAction, initial);
  const [employerChoice, setEmployerChoice] = useState<string | null>(null);
  const [departmentChoice, setDepartmentChoice] = useState<string | null>(null);
  const employerId = employerChoice ?? state.employerId;
  const departmentId = departmentChoice ?? state.departmentId;
  const visibleSites = sites.filter((site) => site.employer_id === employerId);
  const visibleJobs = jobs.filter((job) => !job.department_id || job.department_id === departmentId);
  if (employers.length === 0 || sites.length === 0) return <div className="empty-state"><h2>أكمل إعداد الشركة أولًا</h2>
    <p>يلزم وجود جهة توظيف وفرع نشط قبل إضافة موظف.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}/entities-sites`}>الجهات والفروع</Link></div>;

  return <form key={state.attempt} action={action} className="auth-form compact-form">
    <input type="hidden" name="tenantId" value={tenantId} />
    <h2>بيانات الموظف</h2>
    <label htmlFor="employee-code">رمز الموظف</label>
    <input id="employee-code" name="code" required maxLength={40} autoFocus defaultValue={state.code} />
    <label htmlFor="employee-name">اسم الموظف</label>
    <input id="employee-name" name="name" required minLength={2} maxLength={160} defaultValue={state.name} />
    <p className="field-hint">يمكن إنشاء حساب دخول وربطه بالموظف لاحقًا؛ الملف الوظيفي لا يحتاج إلى حساب.</p>

    <h2>العمل والفرع</h2>
    <label htmlFor="employee-employer">جهة التوظيف</label>
    <select id="employee-employer" name="employerId" required value={employerId}
      onChange={(event) => setEmployerChoice(event.target.value)}>
      {employers.map((employer) => <option key={employer.id} value={employer.id}>{employer.name}</option>)}
    </select>
    <label htmlFor="employee-site">الفرع</label>
    <select key={`${state.attempt}-${employerId}`} id="employee-site" name="siteId" required
      defaultValue={visibleSites.some((site) => site.id === state.siteId) ? state.siteId : visibleSites[0]?.id ?? ''}>
      {visibleSites.length === 0 && <option value="">لا يوجد فرع نشط لهذه الجهة</option>}
      {visibleSites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
    </select>
    <label htmlFor="employee-start">تاريخ بداية العمل</label>
    <input id="employee-start" name="startDate" type="date" required defaultValue={state.startDate} />
    {departments.length > 0 && <><label htmlFor="employee-department">القسم (اختياري)</label>
      <select id="employee-department" name="departmentId" value={departmentId}
        onChange={(event) => setDepartmentChoice(event.target.value)}><option value="">دون تحديد الآن</option>
        {departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}</select></>}
    {jobs.length > 0 && <><label htmlFor="employee-job">الوظيفة (اختياري)</label>
      <select key={`${state.attempt}-${departmentId}`} id="employee-job" name="jobId"
        defaultValue={visibleJobs.some((job) => job.id === state.jobId) ? state.jobId : ''}>
        <option value="">دون تحديد الآن</option>
        {visibleJobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}</select></>}

    <h2>الأجر الأساسي</h2>
    <label htmlFor="employee-pay-basis">طريقة الأجر</label>
    <select id="employee-pay-basis" name="payBasis" defaultValue={state.payBasis}>
      <option value="monthly">شهري</option><option value="daily">يومي</option>
    </select>
    <label htmlFor="employee-amount">الأجر الأساسي بالجنيه المصري</label>
    <input id="employee-amount" name="amount" type="number" min="0" max="999999999999.99" step="0.01"
      inputMode="decimal" required defaultValue={state.amount} />
    <label className="checkbox-row" htmlFor="employee-payroll-eligible">
      <input id="employee-payroll-eligible" name="payrollEligible" type="checkbox" defaultChecked={state.payrollEligible} />
      <span>يُدرج في كشوف الرواتب عند تفعيل الرواتب</span>
    </label>
    {state.error && <p className="form-message error-message" role="alert">{state.error}</p>}
    <div className="workspace-form-actions"><SubmitButton label="إضافة الموظف" pendingLabel="جارٍ إضافة الموظف…" />
      <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>إلغاء</Link></div>
  </form>;
}
