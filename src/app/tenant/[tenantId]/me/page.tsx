import { Panel } from '@/components/ui';
import { Suspense } from 'react';
import { redirect } from 'next/navigation';
import { getWorkspaceClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
import { PageFrame } from '@/components/context-navigation';
import { InstallHint } from '@/components/install-hint';
import { Avatar, ButtonLink, Disclosure, Icon, PageHeader, Skeleton, StatusBadge } from '@/components/ui';
import { ThemePreferenceControl } from '@/components/theme-preference';
import { readMobileSnapshot } from '@/lib/attendance-channel';
import { MobilePunch } from './attendance/MobilePunch';
import { AttendanceHistory } from './attendance/AttendanceHistory';
import { BalancePreview } from './leave/BalancePreview';
import styles from './profile.module.css';
import { isDate, isLeaveAccessSnapshot, isObject } from './leave/form-rules';

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
  const supabase = await getWorkspaceClient();
  if (!supabase) return <State tenantId={tenantId} />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me`)}`);
  let response;
  try {
    response = await readWorkspaceRpc(supabase, 'tenant_my_employee_snapshot', tenantId, 'p_tenant_id');
  } catch {
    return <State tenantId={tenantId} />;
  }
  const { data, error } = response;
  const profile = error ? null : readEmployeeSnapshot(data);
  if (!profile) {
    return <State tenantId={tenantId} forbidden={error?.code === '42501'} />;
  }
  let attendance = null;
  let hasLeaveAccess = false;
  try {
    const results = await Promise.allSettled([
      readWorkspaceRpc(supabase, 'attendance_mobile_snapshot', tenantId, 'p_tenant'),
      readWorkspaceRpc(supabase, 'leave_access_snapshot', tenantId, 'p_tenant'),
    ]);
    const attendanceResult = results[0].status === 'fulfilled' ? results[0].value : null;
    const leaveResult = results[1].status === 'fulfilled' ? results[1].value : null;
    attendance = attendanceResult && !attendanceResult.error ? readMobileSnapshot(attendanceResult.data) : null;
    hasLeaveAccess = Boolean(leaveResult && !leaveResult.error && isLeaveAccessSnapshot(leaveResult.data) && leaveResult.data.self_access === true);
  } catch { /* Keep the readable employee profile when attendance is unavailable. */ }
  return <PageFrame>
    <PageHeader eyebrow="يومي" title={`أهلًا، ${profile.display_name}`} description={profile.site_name ?? 'مساحتك الشخصية للعمل'} />
    <div className={styles.dailyGrid}>
      <div className={styles.dailyMain}>
        {attendance ? <MobilePunch tenantId={tenantId} snapshot={attendance} /> : <section className={`ui-card ${styles.panel}`}><Icon name="clock"/><h2>حضوري</h2><p className="field-hint">افتح سجل الحضور للتحقق من إتاحة التسجيل لحسابك.</p><ButtonLink href={`/tenant/${tenantId}/me/attendance`} icon="arrowLeft">فتح الحضور</ButtonLink></section>}
        <nav className={styles.quickActions} aria-label="خدماتي"><ButtonLink variant="ghost" href={`/tenant/${tenantId}/me/attendance`} icon="clock">سجل الحضور</ButtonLink>{hasLeaveAccess && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/me/leave`} icon="calendar">إجازاتي</ButtonLink>}<a href="#my-employee-heading" className="ui-button ui-button-ghost ui-button-md"><Icon name="user" size={18}/>ملفي</a></nav>
        {attendance && <section className={`ui-card ${styles.panel}`}><div className={styles.profileHeading}><h2>آخر التسجيلات</h2><ButtonLink variant="ghost" href={`/tenant/${tenantId}/me/attendance`}>السجل الكامل</ButtonLink></div><AttendanceHistory history={attendance.history.slice(0, 3)} /></section>}
        <InstallHint />
      </div>
    <div className={styles.dailyMain}>
    {hasLeaveAccess && <Suspense fallback={<div className={`ui-card ${styles.panel}`} aria-label="جارٍ تحميل رصيد الإجازات"><Skeleton style={{ height: 120 }}/></div>}><BalancePreview tenantId={tenantId}/></Suspense>}
    <section className={`ui-card ${styles.panel}`} aria-labelledby="my-employee-title" id="my-employee-heading">
      <div className={styles.profileHeading}><Avatar name={profile.display_name} size={48}/><div><h2 id="my-employee-title">ملفي</h2><p className="field-hint">{profile.job_title ?? 'البيانات الوظيفية'}</p></div><StatusBadge label={profile.employee_status === 'active' ? 'نشط' : profile.employee_status === 'ended' ? 'منتهٍ' : 'غير نشط'} tone={profile.employee_status === 'active' ? 'ok' : 'neutral'} /></div>
      <Disclosure summary="بياناتي الوظيفية" open>
      <dl className={styles.details}>
        <div><dt>الاسم</dt><dd>{profile.display_name}</dd></div>
        <div><dt>كود الموظف</dt><dd><bdi>{profile.employee_code}</bdi></dd></div>
        <div><dt>حالة الملف</dt><dd>{profile.employee_status === 'active' ? 'نشط' : profile.employee_status === 'ended' ? 'منتهٍ' : 'غير نشط'}</dd></div>
        <div><dt>حالة التوظيف</dt><dd>{profile.employment_status === 'active' ? 'على رأس العمل' : profile.employment_status === 'ended' ? 'انتهى التوظيف' : 'غير محددة'}</dd></div>
        <div><dt>بداية التوظيف</dt><dd>{profile.employment_start_date ? <time dateTime={profile.employment_start_date}><bdi>{profile.employment_start_date}</bdi></time> : 'غير مسجلة'}</dd></div>
        <div><dt>الفرع</dt><dd>{profile.site_name ?? 'غير محدد'}</dd></div>
        <div><dt>المسمى الوظيفي</dt><dd>{profile.job_title ?? 'غير محدد'}</dd></div>
      </dl>
      </Disclosure>
      <p className="field-hint">لتصحيح بياناتك تواصل مع الموارد البشرية.</p>
      {!profile.new_work_enabled && <p className="field-hint" role="status">يمكنك الاطلاع على ملفك الحالي. إنشاء طلبات عمل جديدة غير متاح حاليًا.</p>}
      <Disclosure summary="مظهر الواجهة"><ThemePreferenceControl /></Disclosure>
    </section>
    </div>
    </div>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
  </PageFrame>;
}

function State({ tenantId, forbidden }: { tenantId: string; forbidden?: boolean }) {
  return <PageFrame>
    <header className="workspace-page-heading"><div><p className="eyebrow">الخدمة الذاتية</p><PageHeader  title={<>ملفي</>} /></div></header>
    <Panel className="workspace-records-panel">
      <h2>{forbidden ? 'الخدمة الذاتية غير مفعّلة لهذا الحساب' : 'تعذر تحميل ملفك الآن'}</h2>
      <p className="field-hint">{forbidden ? 'يجب أن تكون عضوًا نشطًا وأن يكون حسابك مرتبطًا بملف موظف مع صلاحية الخدمة الذاتية.' : 'حدث خطأ أثناء تحميل البيانات. أعد المحاولة.'}</p>
      {!forbidden && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/me`}>إعادة المحاولة</ButtonLink>}
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
    </Panel>
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
