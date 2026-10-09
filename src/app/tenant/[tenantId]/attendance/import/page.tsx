import { ButtonLink, PageHeader, Panel, buttonClassName, Disclosure } from '@/components/ui';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { AttendanceImportForm } from './AttendanceImportForm';

export const dynamic = 'force-dynamic';

export default async function AttendanceImportPage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <PageFrame><Status text="تعذر الاتصال بخدمة الحسابات. أعد المحاولة."/></PageFrame>;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/import`)}`);
  const { data, error } = await supabase.rpc('time_attendance_access_snapshot', { p_tenant_id: tenantId });
  if (error || !isObject(data) || data.can_manage !== true) return <PageFrame>
    <Panel className=" task-page"><PageHeader  title={<>استيراد الحضور غير متاح</>} description={<> {isObject(data) && data.entitlement_enabled === false ? 'وحدة الحضور غير مفعلة؛ يمكن مراجعة السجلات السابقة فقط.' : 'تحتاج إلى صلاحية تشغيل الحضور لهذه الشركة.'} </>} />

      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance`}>العودة إلى الحضور</ButtonLink>
    </Panel>
  </PageFrame>;

  return <PageFrame footer="الحضور وسجل العمل">
    <Panel className=" task-page attendance-import-page" aria-labelledby="attendance-import-title">
      <ButtonLink icon="arrowRight" variant="ghost"  href={`/tenant/${tenantId}/attendance`}>العودة إلى الحضور اليومي</ButtonLink>
      <p className="eyebrow">استيراد تسجيلات العمل</p>
      <PageHeader id="attendance-import-title" title={<>استيراد الحضور من ملف</>} description={<> ارفع الملف، وحدد أعمدته، ثم راجع التسجيلات قبل الحفظ. تظل أيام العمل بحاجة إلى المراجعة والاعتماد المعتادين. </>} />

      <a className={buttonClassName("ghost", "md", "attendance-import-template")} href="/templates/attendance-import.csv" download="attendance-import.csv">تنزيل ملف نموذجي (CSV)</a>
      <p><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/unassigned`}>مراجعة التسجيلات بلا تكليف</ButtonLink></p>
      <Disclosure summary="شروط الملف وقواعد الربط"><ul className="attendance-import-rules">
        <li>الأعمدة المطلوبة: رمز الموظف، اسم الفرع، وقت التسجيل مع فرق التوقيت، حضور أو انصراف، ورقم التسجيل في الملف الأصلي.</li>
        <li>اسم الفرع يجب أن يطابق فرعًا نشطًا وفريدًا. إذا لم يوجد تكليف مطابق لموظف معروف، يُحفظ الحدث للمراجعة ولا يُربط بيوم تلقائيًا.</li>
        <li>الحد الأقصى 100 حدث و256 كيلوبايت. الصفوف المكررة لا تتكرر، والمرفوضة لا تُحفظ.</li>
      </ul></Disclosure>
      <AttendanceImportForm tenantId={tenantId}/>
    </Panel>
  </PageFrame>;
}

function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function Status({ text }: { text: string }) { return <Panel className=" task-page"><PageHeader  title={<>تعذر فتح الاستيراد</>} description={<> {text} </>} /></Panel>; }
