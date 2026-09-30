import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { WorkAssignmentPanel, type AssignmentHistory, type TransferOptions } from './WorkAssignmentPanel';
import { CompensationPanel, type CompensationHistory, type CompensationOptions } from './CompensationPanel';
import { EmploymentLifecyclePanel, type EmploymentHistory, type RehireOptions } from './EmploymentLifecyclePanel';
import { EmployeeUserLinkPanel, type AccountProvision, type LinkSnapshot, type Options as EmployeeUserLinkOptions } from './EmployeeUserLinkPanel';

export const dynamic = 'force-dynamic';
type Employment = { id: string; employer: string; start_date: string; end_date: string | null; status: string };
type Assignment = { id: string; site: string; department: string | null; job: string | null; manager: string | null; valid_from: string };
type Employee = { id: string; code: string; name: string; status: string; employment: Employment | null; assignment: Assignment | null };

export default async function EmployeePage({ params, searchParams }: {
  params: Promise<{ tenantId: string; employeeId: string }>;
  searchParams: Promise<{ state?: string; assignment?: string; compensation?: string; employment?: string; userLink?: string; linkQuery?: string; linkPage?: string; account?: string }>;
}) {
  const { tenantId, employeeId } = await params;
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/${employeeId}`)}`);
  const [employeeResult, accessResult] = await Promise.all([
    supabase.rpc('people_employee_snapshot', { p_tenant_id: tenantId, p_employee_id: employeeId }),
    supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId }),
  ]);
  if (employeeResult.error || !employeeResult.data || typeof employeeResult.data !== 'object'
    || Array.isArray(employeeResult.data) || accessResult.error || !accessResult.data) {
    return <Unavailable tenantId={tenantId} />;
  }
  const employee = employeeResult.data as unknown as Employee;
  const access = accessResult.data as Record<string, unknown>;
  const employmentId = employee.employment?.id ?? null;
  const canViewCompensation = access.can_view_compensation === true;
  const canManageCompensation = access.can_manage_compensation === true;
  const canManageWorkContext = access.can_manage_org === true;
  const canManageLifecycle = access.can_manage === true && access.can_manage_employment === true
    && canManageWorkContext && canManageCompensation;
  const linkQuery = typeof query.linkQuery === 'string' ? query.linkQuery.slice(0, 100) : '';
  const linkPage = Math.min(1000, Math.max(1, Number.parseInt(query.linkPage ?? '1', 10) || 1));
  const [historyResult, optionsResult, compensationHistoryResult, compensationOptionsResult, employmentHistoryResult, rehireOptionsResult, linkSnapshotResult, linkOptionsResult, membershipSnapshotResult] = await Promise.all([
    employmentId ? supabase.rpc('people_work_assignment_history', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    canManageWorkContext && employmentId ? supabase.rpc('people_work_assignment_options', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    canViewCompensation && employmentId ? supabase.rpc('people_compensation_history', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    canManageCompensation && employmentId ? supabase.rpc('people_compensation_options', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    supabase.rpc('people_employment_history', { p_tenant_id: tenantId, p_employee_id: employeeId }),
    canManageLifecycle && employee.status === 'ended'
      ? supabase.rpc('people_onboarding_options', { p_tenant_id: tenantId })
      : Promise.resolve({ data: null, error: null }),
    supabase.rpc('people_employee_user_link_snapshot', { p_tenant_id: tenantId, p_employee_id: employeeId }),
    access.can_manage === true ? supabase.rpc('people_employee_user_link_options', {
      p_tenant_id: tenantId, p_employee_id: employeeId, p_query: linkQuery, p_page: linkPage,
    }) : Promise.resolve({ data: null, error: null }),
    access.can_manage === true ? supabase.rpc('tenant_membership_snapshot', { p_tenant_id: tenantId })
      : Promise.resolve({ data: null, error: null }),
  ]);
  const linkSnapshot = linkSnapshotResult.data && typeof linkSnapshotResult.data === 'object'
    ? linkSnapshotResult.data as unknown as LinkSnapshot : null;
  const linkOptions = linkOptionsResult.data && typeof linkOptionsResult.data === 'object'
    ? linkOptionsResult.data as unknown as EmployeeUserLinkOptions : null;
  const membershipSnapshot = membershipSnapshotResult.data && typeof membershipSnapshotResult.data === 'object'
    ? membershipSnapshotResult.data as Record<string, unknown> : null;
  const canProvisionEmployeeAccount = access.can_manage === true && membershipSnapshot?.can_manage_members === true;
  const accountProvisionResult = canProvisionEmployeeAccount ? await supabase.rpc('people_employee_account_provision_snapshot', {
    p_tenant_id: tenantId, p_employee_id: employeeId,
  }) : { data: null, error: null };
  const accountProvision = accountProvisionResult.data && typeof accountProvisionResult.data === 'object'
    ? accountProvisionResult.data as unknown as AccountProvision : null;
  const assignmentHistory = historyResult.data && typeof historyResult.data === 'object'
    ? historyResult.data as unknown as AssignmentHistory : null;
  const transferOptions = optionsResult.data && typeof optionsResult.data === 'object'
    ? optionsResult.data as unknown as TransferOptions : null;
  const historyError = Boolean(employmentId && (historyResult.error || !assignmentHistory));
  const optionsError = Boolean(canManageWorkContext && employmentId && (optionsResult.error || !transferOptions));
  const compensationHistory = compensationHistoryResult.data && typeof compensationHistoryResult.data === 'object'
    ? compensationHistoryResult.data as unknown as CompensationHistory : null;
  const compensationOptions = compensationOptionsResult.data && typeof compensationOptionsResult.data === 'object'
    ? compensationOptionsResult.data as unknown as CompensationOptions : null;
  const compensationHistoryError = Boolean(canViewCompensation && employmentId
    && (compensationHistoryResult.error || !compensationHistory));
  const compensationOptionsError = Boolean(canManageCompensation && employmentId
    && (compensationOptionsResult.error || !compensationOptions));
  const employmentHistory = employmentHistoryResult.data && typeof employmentHistoryResult.data === 'object'
    ? employmentHistoryResult.data as unknown as EmploymentHistory : null;
  const employmentHistoryError = Boolean(employmentHistoryResult.error || !employmentHistory);
  const rehireOptions = rehireOptionsResult.data && typeof rehireOptionsResult.data === 'object'
    ? rehireOptionsResult.data as unknown as RehireOptions : null;
  const rehireOptionsError = Boolean(canManageLifecycle && employee.status === 'ended'
    && (rehireOptionsResult.error || !rehireOptions));
  const today = cairoToday();
  return <PageFrame footer="الموارد البشرية">
    {query.state === 'created' && <FeedbackToast key={employeeId} message="تمت إضافة الموظف وحفظ بيانات عمله." />}
    {query.assignment === 'scheduled' && <FeedbackToast key="assignment-scheduled" message="تم حفظ نقل العمل وسيبدأ في التاريخ المحدد." />}
    {query.assignment === 'transferred' && <FeedbackToast key="assignment-transferred" message="تم تحديث سياق العمل اعتبارًا من اليوم." />}
    {query.assignment === 'corrected' && <FeedbackToast key="assignment-corrected" message="تم تصحيح بيانات العمل لهذا اليوم وحفظ تفاصيل التعديل." />}
    {query.assignment === 'cancelled' && <FeedbackToast key="assignment-cancelled" message="تم إلغاء النقل المقرر واستعادة سياق العمل السابق." />}
    {query.assignment === 'cancel-error' && <FeedbackToast key="assignment-cancel-error" message="تعذر إلغاء النقل. حدّث الصفحة للتحقق من حالته." />}
    {query.compensation === 'changed' && <FeedbackToast key="compensation-changed" message="تم تحديث الأجر الأساسي اعتبارًا من اليوم." />}
    {query.compensation === 'corrected' && <FeedbackToast key="compensation-corrected" message="تم حفظ التعديل بتاريخ سابق. راجع أي فترة Payroll مقفلة؛ الربط الآلي بطلب التصحيح لم يُفعّل بعد." />}
    {query.compensation === 'initial_corrected' && <FeedbackToast key="compensation-initial-corrected" message="تم تصحيح الأجر الأول لهذا اليوم وحُفظ سجل التعديل." />}
    {query.compensation === 'scheduled' && <FeedbackToast key="compensation-scheduled" message="تم حفظ تغيير الأجر وسيبدأ في التاريخ المحدد." />}
    {query.compensation === 'cancelled' && <FeedbackToast key="compensation-cancelled" message="تم إلغاء تغيير الأجر المقرر واستعادة الأجر السابق." />}
    {query.compensation === 'cancel-error' && <FeedbackToast key="compensation-cancel-error" message="تعذر إلغاء تغيير الأجر. حدّث الصفحة للتحقق من حالته." />}
    {query.employment === 'ended' && <FeedbackToast key="employment-ended" message="تم إنهاء علاقة العمل. راجع Payroll والإجازات وتمويل الموظف للتسوية والمتابعة اللازمة." />}
    {query.employment === 'rehired' && <FeedbackToast key="employment-rehired" message="تم إنشاء علاقة عمل جديدة للموظف. راجع Payroll والإجازات وتمويل الموظف بشأن الفترة السابقة." />}
    <Link className="back-link" href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</Link>
    <header className="workspace-page-heading"><div><p className="eyebrow">ملف الموظف</p><h1>{employee.name}</h1>
      <p>رمز الموظف: <bdi>{employee.code}</bdi></p></div>
      <span className={`entity-status ${employee.status === 'active' ? 'is-active' : 'is-inactive'}`}>
        {employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'سيبدأ قريبًا' : employee.status === 'ended' ? 'انتهت خدمته' : 'غير نشط'}</span>
    </header>
    <section className="workspace-records-panel" aria-labelledby="employment-heading">
      <h2 id="employment-heading">{employee.status === 'scheduled' ? 'العمل المقرر' : employee.status === 'ended' ? 'آخر علاقة عمل' : 'العمل الحالي'}</h2>
      {employee.employment ? <dl className="snapshot-grid">
        <div><dt>جهة التوظيف</dt><dd>{employee.employment.employer}</dd></div>
        <div><dt>تاريخ البداية</dt><dd><bdi>{employee.employment.start_date}</bdi></dd></div>
        <div><dt>الفرع</dt><dd>{employee.assignment?.site ?? 'غير محدد'}</dd></div>
        {employee.assignment?.department && <div><dt>القسم</dt><dd>{employee.assignment.department}</dd></div>}
        {employee.assignment?.job && <div><dt>الوظيفة</dt><dd>{employee.assignment.job}</dd></div>}
        {employee.assignment?.manager && <div><dt>المدير المباشر</dt><dd>{employee.assignment.manager}</dd></div>}
      </dl> : <p>لا توجد علاقة توظيف نشطة لهذا الموظف.</p>}
      {employee.status === 'scheduled' && employee.employment && <p className="record-meta">
        بيانات الفرع والقسم والوظيفة المعروضة مقررة لتبدأ مع العمل في <bdi>{employee.employment.start_date}</bdi>؛ لم تبدأ بعد.
      </p>}
    </section>
    <WorkAssignmentPanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId}
      employmentStartDate={employee.employment?.start_date ?? null}
      employmentActive={employee.employment?.status === 'active'}
      history={assignmentHistory} historyError={historyError} options={transferOptions} optionsError={optionsError}
      canManage={canManageWorkContext} initialDate={today} />
    {(canViewCompensation || canManageCompensation) && <CompensationPanel tenantId={tenantId} employeeId={employee.id}
      employmentId={employmentId} canView={canViewCompensation} canManage={canManageCompensation}
      history={compensationHistory} historyError={compensationHistoryError}
      options={compensationOptions} optionsError={compensationOptionsError} today={today} />}
    <EmploymentLifecyclePanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId}
      employmentStatus={employee.employment?.status ?? null} workforceStatus={employee.status}
      employmentStartDate={employee.employment?.start_date ?? null}
      previousEndDate={employee.employment?.end_date ?? null} canManage={canManageLifecycle} today={today}
      history={employmentHistory} historyError={employmentHistoryError}
      rehireOptions={rehireOptions} optionsError={rehireOptionsError} />
    <EmployeeUserLinkPanel tenantId={tenantId} employeeId={employee.id} canManage={access.can_manage === true}
      canInvite={membershipSnapshot?.can_manage_members === true}
      canProvisionAccount={canProvisionEmployeeAccount}
      accountProvision={accountProvision} accountProvisionError={Boolean(canProvisionEmployeeAccount && (accountProvisionResult.error || !accountProvision))}
      requestKey={crypto.randomUUID()} accountState={query.account}
      snapshot={linkSnapshot} snapshotError={Boolean(linkSnapshotResult.error || !linkSnapshot)}
      options={linkOptions} optionsError={Boolean(access.can_manage === true && (linkOptionsResult.error || !linkOptions))}
      query={linkQuery} page={linkPage} state={query.userLink} />
    <section className="workspace-records-panel" aria-label="الخطوة التالية">
      <h2>الخطوة التالية</h2><p>تأكد من بيانات العمل المسجلة، ثم تابع إلى دليل الموظفين أو أضف موظفًا آخر.</p>
      <div className="workspace-form-actions"><Link className="secondary-button" href={`/tenant/${tenantId}/people`}>عرض جميع الموظفين</Link>
        {access.can_manage === true && access.can_manage_employment === true && access.can_manage_compensation === true &&
          <Link className="secondary-button" href={`/tenant/${tenantId}/people/new`}>إضافة موظف آخر</Link>}</div>
    </section>
  </PageFrame>;
}

function cairoToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>ملف الموظف غير متاح</h1>
    <p className="intro">قد يكون الملف غير موجود، أو ليس لديك صلاحية عرضه في هذه الشركة.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</Link>
  </section></PageFrame>;
}
