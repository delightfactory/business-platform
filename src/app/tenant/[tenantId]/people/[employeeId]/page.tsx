import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type Employment = { employer: string; start_date: string; status: string };
type Assignment = { site: string; department: string | null; job: string | null; valid_from: string };
type Employee = { id: string; code: string; name: string; status: string; employment: Employment | null; assignment: Assignment | null };
type Compensation = { amount: number | string; currency: string; valid_from: string; pay_basis: string };

export default async function EmployeePage({ params, searchParams }: {
  params: Promise<{ tenantId: string; employeeId: string }>;
  searchParams: Promise<{ state?: string }>;
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
  let compensation: Compensation | null = null;
  if (access.can_view_compensation === true) {
    const { data } = await supabase.rpc('people_compensation_snapshot', {
      p_tenant_id: tenantId, p_employee_id: employeeId,
    });
    if (data && typeof data === 'object' && !Array.isArray(data)) compensation = data as Compensation;
  }
  return <PageFrame footer="الموارد البشرية">
    {query.state === 'created' && <FeedbackToast key={employeeId} message="تمت إضافة الموظف وحفظ بيانات عمله." />}
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
      </dl> : <p>لا توجد علاقة توظيف نشطة لهذا الموظف.</p>}
    </section>
    {compensation && <section className="workspace-records-panel" aria-labelledby="compensation-heading">
      <h2 id="compensation-heading">الأجر الأساسي</h2>
      <p className="intro"><bdi>{Number(compensation.amount).toLocaleString('ar-EG', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</bdi> جنيه مصري
        {' · '}{compensation.pay_basis === 'daily' ? 'يومي' : 'شهري'}</p>
      <p className="record-meta">سارٍ من <bdi>{compensation.valid_from}</bdi></p>
    </section>}
    <section className="workspace-records-panel" aria-label="الخطوة التالية">
      <h2>الخطوة التالية</h2><p>تأكد من بيانات العمل المسجلة، ثم تابع إلى دليل الموظفين أو أضف موظفًا آخر.</p>
      <div className="workspace-form-actions"><Link className="secondary-button" href={`/tenant/${tenantId}/people`}>عرض جميع الموظفين</Link>
        {access.can_manage === true && access.can_manage_employment === true && access.can_manage_compensation === true &&
          <Link className="secondary-button" href={`/tenant/${tenantId}/people/new`}>إضافة موظف آخر</Link>}</div>
    </section>
  </PageFrame>;
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>ملف الموظف غير متاح</h1>
    <p className="intro">قد يكون الملف غير موجود، أو ليس لديك صلاحية عرضه في هذه الشركة.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</Link>
  </section></PageFrame>;
}
