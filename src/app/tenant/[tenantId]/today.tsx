import { Message } from '@/components/ui';
import Link from 'next/link';
import { TaskCard, type TaskPreview } from '@/components/patterns/task-card';
import { Icon, type IconName } from '@/components/ui/icon';
import { readWorkspaceRpc } from '@/lib/workspace-access';
import type { createSupabaseServerClient } from '@/lib/supabase/server';
import { readAccess, readCancellationQueue, readRequestQueue } from './leave/rules';

type Client = NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>;
type ReadResult = { data: unknown; error: { code?: string } | null };
type Entry = { title: string; detail: string; href: string; count?: number; more?: boolean; preview?: TaskPreview[] };
export type TodayModel = { work: Entry[]; own: Entry[]; followUp: Entry[]; unavailable: string[]; date: string };

function object(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

// Optional reads fail independently. Authentication/lifecycle/membership are checked by the parent.
export async function readToday(client: Client, tenantId: string): Promise<TodayModel> {
  const date = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
  const model: TodayModel = { work: [], own: [], followUp: [], unavailable: [], date };
  const base = `/tenant/${tenantId}`;
  async function read(name: string, args: Record<string, unknown>): Promise<ReadResult> {
    try { return await client.rpc(name, args); }
    catch { return { data: null, error: { code: 'unavailable' } }; }
  }
  const names = ['time_attendance_access_snapshot', 'leave_access_snapshot', 'people_access_snapshot',
    'tenant_my_employee_snapshot', 'attendance_mobile_snapshot', 'attendance_channel_access',
    'payroll_access_snapshot', 'payroll_input_access', 'payroll_run_access', 'payroll_navigation_access'];
  const results = await Promise.all(names.map(async name => {
    const argument = name.startsWith('payroll_') || name === 'leave_access_snapshot'
      || name === 'attendance_mobile_snapshot' || name === 'attendance_channel_access' ? 'p_tenant' : 'p_tenant_id';
    try { return await readWorkspaceRpc(client, name, tenantId, argument); }
    catch { return { data: null, error: { code: 'unavailable' } }; }
  }));
  const access = (index: number, label: string) => {
    const result = results[index];
    if (result.error) {
      if (result.error.code !== '42501') model.unavailable.push(label);
      return null;
    }
    const value = object(result.data);
    if (result.data !== null && !value) model.unavailable.push(label);
    return value;
  };
  const attendance = access(0, 'الحضور');
  const leaveRaw = access(1, 'الإجازات');
  const leave = readAccess(leaveRaw);
  if (leaveRaw && !leave) model.unavailable.push('صلاحيات الإجازات');
  const people = access(2, 'الموظفون');
  const employee = access(3, 'ملفي');
  const mobile = access(4, 'حضوري');
  const channel = access(5, 'قنوات الحضور');
  const payroll = access(6, 'دورة الرواتب');
  const inputs = access(7, 'مدخلات الرواتب');
  const runs = access(8, 'مسيرات الرواتب');
  const navigation = access(9, 'متابعة الرواتب');

  const [attendanceResult, requestResult, cancellationResult] = await Promise.all([
    attendance?.can_view === true ? read('attendance_review_queue', { p_tenant_id: tenantId, p_operational_date: date, p_filter: 'all', p_after: null, p_limit: 1 }) : null,
    leave?.canView ? read('leave_hr_queue', { p_tenant: tenantId, p_limit: 3, p_offset: 0 }) : null,
    leave?.canApprove ? read('leave_cancellation_queue', { p_tenant: tenantId, p_limit: 3, p_offset: 0 }) : null,
  ]);
  if (attendance?.can_view === true) {
    const counts = attendanceResult && !attendanceResult.error ? object(object(attendanceResult.data)?.counts) : null;
    const valid = counts && ['exception_count', 'clean_ready', 'overtime_pending'].every(key => typeof counts[key] === 'number' && Number.isSafeInteger(counts[key]) && Number(counts[key]) >= 0);
    const scope = `تاريخ ${date} · Africa/Cairo${attendance.entitlement_enabled === false ? ' · خدمة الحضور موقوفة؛ السجل للقراءة' : ''}`;
    const entries = attendance.can_approve === true || attendance.can_correct === true ? model.work : model.followUp;
    entries.push({ title: 'مراجعة الحضور', detail: valid
      ? `${scope}. استثناءات: ${counts.exception_count}؛ جاهز للمراجعة: ${counts.clean_ready}. الأعداد لهذا التاريخ فقط؛ افتح القائمة للتحقق من اليوم أو الأيام السابقة.`
      : `${scope}. تعذر تحميل ملخص المراجعة؛ افتح القائمة لإعادة المحاولة.`, href: `${base}/attendance/review?date=${date}`, count: valid ? Number(counts.exception_count) : undefined });
    if (valid && Number(counts.overtime_pending) > 0) entries.push({ title: 'إضافي بانتظار القرار', detail: `${scope}. عناصر الإضافي: ${counts.overtime_pending}؛ قد تتداخل مع الاستثناءات.`, href: `${base}/attendance/review?date=${date}&filter=overtime`, count: Number(counts.overtime_pending) });
    entries.push({ title: 'تسجيلات بلا تكليف', detail: 'قائمة مستقلة للتحقق من التسجيلات والأيام المحتملة؛ ليست ضمن عداد المراجعة.', href: `${base}/attendance/unassigned` });
  }
  if (channel?.can_view === true) model.work.push({ title: 'طرق تسجيل الحضور والمواقع', detail: 'راجع طريقة تسجيل الحضور وموقع العمل والتسجيلات الواردة.', href: `${base}/attendance/sources` });
  if (leave?.canView) {
    const queue = requestResult && !requestResult.error ? readRequestQueue(requestResult.data) : null;
    const entries = leave.canApprove || leave.canManage ? model.work : model.followUp;
    entries.push({ title: 'طلبات الإجازة', detail: queue
      ? queue.items.length ? `طلبات ظاهرة للمراجعة: ${queue.items.length}${queue.hasMore ? '؛ توجد طلبات أخرى. عرض كامل الطلبات في القائمة.' : '. افتح القائمة لمتابعتها.'}` : 'لم تظهر طلبات جديدة الآن. افتح القائمة لمتابعة الإجازات.'
      : 'تعذر تحميل الطلبات هنا. افتح قائمة الإجازات للمحاولة من جديد.', href: `${base}/leave`, count: queue?.items.length, more: queue?.hasMore,
      preview: queue?.items.map(item => ({ label: item.employeeName, detail: item.leaveTypeName, href: `${base}/leave/requests/${item.id}` })) });
    if (leave.canApprove) {
      const queue = cancellationResult && !cancellationResult.error ? readCancellationQueue(cancellationResult.data) : null;
      entries.push({ title: 'طلبات إلغاء الإجازة', detail: queue
        ? queue.items.length ? `طلبات إلغاء ظاهرة: ${queue.items.length}${queue.hasMore ? '؛ توجد طلبات أخرى. عرض كامل الطلبات في القائمة.' : '. راجع الطلب الأصلي قبل القرار.'}` : 'لم تظهر طلبات إلغاء تحتاج مراجعة الآن.'
        : 'تعذر تحميل طلبات الإلغاء. يمكنك متابعة باقي طلبات الإجازة.', href: `${base}/leave#leave-cancellation-queue-title`, count: queue?.items.length, more: queue?.hasMore,
        preview: queue?.items.map(item => ({ label: item.employeeName, detail: 'طلب إلغاء إجازة', href: `${base}/leave/requests/${item.requestId}` })) });
    }
  }
  if (payroll?.can_manage === true || payroll?.can_view === true || runs?.can_view === true) model.work.push({ title: 'الرواتب', detail: 'اختر الجهة والشهر في قسم الرواتب لعرض المبالغ وما يحتاج مراجعة.', href: payroll ? `${base}/payroll` : `${base}/payroll/runs` });
  if (inputs) model.work.push({ title: 'مدخلات الرواتب', detail: 'جهّز بيانات الرواتب للجهة والفترة المطلوبة.', href: `${base}/payroll/inputs` });
  if (navigation?.can_view_advances === true) model.followUp.push({ title: 'سلف الموظفين', detail: 'متابعة السلف والأرصدة في الصفحة المختصة.', href: `${base}/payroll/advances` });
  if (navigation?.can_view_reports === true) model.followUp.push({ title: 'تقارير الرواتب', detail: 'عرض التقرير المتاح لهذا الحساب دون تغيير أي مسير.', href: `${base}/payroll/reports?report=${navigation.report_kind === 'advances' ? 'advances' : 'sheet'}` });
  if (people?.can_view === true) model.work.push({ title: 'الموظفون', detail: 'ملفات الموظفين وبيانات العمل والعمليات المتاحة لحسابك.', href: `${base}/people` });
  if (mobile) model.own.push({ title: 'حضوري', detail: 'سجّل حضورك أو تحقق من نتيجة محاولتك الحالية.', href: `${base}/me/attendance` });
  if (leaveRaw?.self_access === true) model.own.push({ title: 'إجازاتي', detail: 'طلب إجازة ومتابعة القرار أو الإلغاء.', href: `${base}/me/leave` });
  if (employee) model.own.push({ title: 'ملفي', detail: 'بياناتك وخدماتك الذاتية المتاحة.', href: `${base}/me` });
  return model;
}

function iconFor(entry: Entry): IconName {
  if (entry.href.includes('/payroll')) return 'wallet';
  if (entry.href.includes('/leave')) return 'calendar';
  if (entry.href.includes('/people') || entry.href.endsWith('/me')) return 'users';
  return 'clock';
}
export function TodaySections({ model }: { model: TodayModel }) {
  const featured = model.work.filter(entry => ['مراجعة الحضور', 'طلبات الإجازة', 'الرواتب'].includes(entry.title));
  const otherWork = model.work.filter(entry => !featured.includes(entry));
  return <div className="today-sections">
    {featured.length > 0 && <section aria-labelledby="today-work-title"><h2 id="today-work-title" className="today-section-title">ما يحتاج انتباهك</h2>
      <div className="today-work-grid">{featured.map(entry => <TaskCard key={entry.href} title={entry.title} description={entry.detail} href={entry.href} count={entry.count} more={entry.more} preview={entry.preview} icon={iconFor(entry)} scope={entry.href.includes('/attendance/review') ? model.date : undefined} action={entry.href.includes('/payroll') ? 'افتح مساحة الرواتب' : entry.href.includes('/leave') ? 'راجع الطلبات' : 'افتح المهمة'} />)}</div>
    </section>}
    <TodayList title="أكمل العمل" entries={otherWork} />
    <TodayList title="خدماتي" entries={model.own} />
    <TodayList title="عرض ومتابعة" entries={model.followUp} />
    {model.unavailable.length > 0 && <Message tone="info"  role="status">تعذر تحميل {model.unavailable.join('، ')}. يمكنك متابعة باقي الخدمات أو تحديث الصفحة.</Message>}
    {!model.work.length && !model.own.length && !model.followUp.length && <div className="empty-state"><Icon name="info" size={28} /><h2>{model.unavailable.length ? 'الخدمات غير متاحة الآن' : 'مساحتك جاهزة'}</h2><p>{model.unavailable.length ? 'حدّث الصفحة لإعادة المحاولة.' : 'راجع مسؤول الشركة لإتاحة خدمات العمل لحسابك.'}</p></div>}
  </div>;
}
function TodayList({ title, entries }: { title: string; entries: Entry[] }) {
  if (!entries.length) return null;
  return <section className="today-shortcuts"><h2>{title}</h2><ul>{entries.map(entry => <li key={entry.href}><Link href={entry.href}><Icon name={iconFor(entry)} size={22} /><span><strong>{entry.title}</strong><small>{entry.detail}</small></span><Icon name="arrowLeft" size={18} /></Link></li>)}</ul></section>;
}
