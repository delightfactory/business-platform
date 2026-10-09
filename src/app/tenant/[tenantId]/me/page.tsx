import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PageFrame } from '@/components/context-navigation';
import { InstallHint } from '@/components/install-hint';
import styles from './profile.module.css';
import { isDate, isObject } from './leave/form-rules';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type EmployeeSnapshot = {
  employee_code: string;
  display_name: string;
  employee_status: 'active' | 'inactive' | 'ended';
  employment_status: 'active' | 'ended' | null;
  employment_start_date: string | null;
  site_name: string | null;
  job_title: string | null;
  new_work_enabled: boolean;
};

export default async function MyEmployeePage({ params }: { params: Params }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <State tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me`)}`);
  let response;
  try {
    response = await supabase.rpc('tenant_my_employee_snapshot', { p_tenant_id: tenantId });
  } catch {
    return <State tenantId={tenantId} />;
  }
  const { data, error } = response;
  const profile = error ? null : readEmployeeSnapshot(data);
  if (!profile) {
    return <State tenantId={tenantId} forbidden={error?.code === '42501'} />;
  }
  return <PageFrame>
    <header className="workspace-page-heading"><div><p className="eyebrow">الخدمة الذاتية</p><h1>ملفي</h1>
      <p className="field-hint">بيانات ملفك الوظيفي المرتبطة بهذا الحساب.</p></div></header>
    <section className={`workspace-records-panel ${styles.panel}`} aria-labelledby="my-employee-heading">
      <h2 id="my-employee-heading">بيانات الموظف</h2>
      <dl className={styles.details}>
        <div><dt>الاسم</dt><dd>{profile.display_name}</dd></div>
        <div><dt>كود الموظف</dt><dd><bdi>{profile.employee_code}</bdi></dd></div>
        <div><dt>حالة الملف</dt><dd>{profile.employee_status === 'active' ? 'نشط' : profile.employee_status === 'ended' ? 'منتهٍ' : 'غير نشط'}</dd></div>
        <div><dt>حالة التوظيف</dt><dd>{profile.employment_status === 'active' ? 'على رأس العمل' : profile.employment_status === 'ended' ? 'انتهى التوظيف' : 'غير محددة'}</dd></div>
        <div><dt>بداية التوظيف</dt><dd>{profile.employment_start_date ? <time dateTime={profile.employment_start_date}><bdi>{profile.employment_start_date}</bdi></time> : 'غير مسجلة'}</dd></div>
        <div><dt>الفرع</dt><dd>{profile.site_name ?? 'غير محدد'}</dd></div>
        <div><dt>المسمى الوظيفي</dt><dd>{profile.job_title ?? 'غير محدد'}</dd></div>
      </dl>
      <p className="field-hint">لتصحيح بياناتك تواصل مع الموارد البشرية.</p>
      {!profile.new_work_enabled && <p className="field-hint" role="status">يمكنك الاطلاع على ملفك الحالي. إنشاء طلبات عمل جديدة غير متاح حاليًا.</p>}
    </section>
    <InstallHint />
    <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
  </PageFrame>;
}

function State({ tenantId, forbidden }: { tenantId: string; forbidden?: boolean }) {
  return <PageFrame>
    <header className="workspace-page-heading"><div><p className="eyebrow">الخدمة الذاتية</p><h1>ملفي</h1></div></header>
    <section className="workspace-records-panel">
      <h2>{forbidden ? 'الخدمة الذاتية غير مفعّلة لهذا الحساب' : 'تعذر تحميل ملفك الآن'}</h2>
      <p className="field-hint">{forbidden ? 'يجب أن تكون عضوًا نشطًا وأن يكون حسابك مرتبطًا بملف موظف مع صلاحية الخدمة الذاتية.' : 'حدث خطأ أثناء تحميل البيانات. أعد المحاولة.'}</p>
      {!forbidden && <Link className="secondary-button" href={`/tenant/${tenantId}/me`}>إعادة المحاولة</Link>}
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
    </section>
  </PageFrame>;
}

function readEmployeeSnapshot(data: unknown): EmployeeSnapshot | null {
  if (!isObject(data) || typeof data.employee_code !== 'string' || !data.employee_code.trim()
    || typeof data.display_name !== 'string' || !data.display_name.trim()
    || (data.employee_status !== 'active' && data.employee_status !== 'inactive' && data.employee_status !== 'ended')
    || (data.employment_status !== null && data.employment_status !== 'active' && data.employment_status !== 'ended')
    || !(data.employment_start_date === null
      || (typeof data.employment_start_date === 'string' && isDate(data.employment_start_date)))
    || !(data.site_name === null || typeof data.site_name === 'string')
    || !(data.job_title === null || typeof data.job_title === 'string')
    || typeof data.new_work_enabled !== 'boolean') return null;
  return {
    employee_code: data.employee_code, display_name: data.display_name, employee_status: data.employee_status,
    employment_status: data.employment_status, employment_start_date: data.employment_start_date,
    site_name: data.site_name, job_title: data.job_title, new_work_enabled: data.new_work_enabled,
  };
}
