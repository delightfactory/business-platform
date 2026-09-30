import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { WorkAssignmentPanel, type AssignmentHistory, type TransferOptions } from './WorkAssignmentPanel';
import { CompensationPanel, type CompensationHistory, type CompensationOptions } from './CompensationPanel';

export const dynamic = 'force-dynamic';
type Employment = { id: string; employer: string; start_date: string; end_date: string | null; status: string };
type Assignment = { id: string; site: string; department: string | null; job: string | null; manager: string | null; valid_from: string };
type Employee = { id: string; code: string; name: string; status: string; employment: Employment | null; assignment: Assignment | null };

export default async function EmployeePage({ params, searchParams }: {
  params: Promise<{ tenantId: string; employeeId: string }>;
  searchParams: Promise<{ state?: string; assignment?: string; compensation?: string }>;
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
  const [historyResult, optionsResult, compensationHistoryResult, compensationOptionsResult] = await Promise.all([
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
  ]);
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
    </section>
    <WorkAssignmentPanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId}
      employmentStartDate={employee.employment?.start_date ?? null}
      currentAssignmentId={employee.assignment?.id ?? null} employmentActive={employee.employment?.status === 'active'}
      history={assignmentHistory} historyError={historyError} options={transferOptions} optionsError={optionsError}
      canManage={canManageWorkContext} initialDate={today} />
    {(canViewCompensation || canManageCompensation) && <CompensationPanel tenantId={tenantId} employeeId={employee.id}
      employmentId={employmentId} canView={canViewCompensation} canManage={canManageCompensation}
      history={compensationHistory} historyError={compensationHistoryError}
      options={compensationOptions} optionsError={compensationOptionsError} today={today} />}
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
