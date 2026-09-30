import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { AttendanceImportForm } from './AttendanceImportForm';

export const dynamic = 'force-dynamic';

export default async function AttendanceImportPage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <PageFrame><Status text="تعذر الاتصال بخدمة الحسابات. أعد المحاولة."/></PageFrame>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/import`)}`);
  const { data, error } = await supabase.rpc('time_attendance_access_snapshot', { p_tenant_id: tenantId });
  if (error || !isObject(data) || data.can_manage !== true) return <PageFrame>
    <section className="work-card task-page"><h1>استيراد الحضور غير متاح</h1>
      <p>{isObject(data) && data.entitlement_enabled === false ? 'وحدة الحضور غير مفعلة؛ يمكن مراجعة السجلات السابقة فقط.' : 'تحتاج إلى صلاحية تشغيل الحضور لهذه الشركة.'}</p>
      <Link className="secondary-button" href={`/tenant/${tenantId}/attendance`}>العودة إلى الحضور</Link>
    </section>
  </PageFrame>;

  return <PageFrame footer="الحضور وسجل العمل">
    <section className="work-card task-page attendance-import-page" aria-labelledby="attendance-import-title">
      <Link className="back-link" href={`/tenant/${tenantId}/attendance`}>العودة إلى الحضور اليومي</Link>
      <p className="eyebrow">استيراد تسجيلات العمل</p>
      <h1 id="attendance-import-title">استيراد الحضور من ملف</h1>
      <p className="field-hint">ارفع الملف، واربط أعمدته، ثم راجع كل صف قبل الحفظ. تسجل الأحداث كأدلة حضور وتخضع لتفسير اليوم ومراجعته المعتاد.</p>
      <a className="secondary-button attendance-import-template" href="/templates/attendance-import.csv" download="attendance-import.csv">تنزيل قالب CSV</a>
      <ul className="attendance-import-rules">
        <li>الأعمدة المطلوبة: رمز الموظف، اسم الفرع، وقت الحدث بفرق توقيت، الاتجاه، ومعرّف الحدث في المصدر.</li>
        <li>اسم الفرع يجب أن يطابق فرعًا نشطًا وفريدًا، والتكليف الفعال للموظف في ذلك الوقت.</li>
        <li>الحد الأقصى 100 حدث و256 كيلوبايت. الصفوف المكررة لا تتكرر، والمرفوضة لا تُحفظ.</li>
      </ul>
      <AttendanceImportForm tenantId={tenantId}/>
    </section>
  </PageFrame>;
}

function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function Status({ text }: { text: string }) { return <section className="work-card task-page"><h1>تعذر فتح الاستيراد</h1><p>{text}</p></section>; }
