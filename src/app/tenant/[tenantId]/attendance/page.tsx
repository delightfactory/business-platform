import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ date?: string; cursor?: string }>;
type DayRow = { id: string; employee_code: string; full_name: string; status: string; timezone_name: string; expected_start: string | null; expected_end: string | null; schedule_kind: string; required_minutes: number | null; late_minutes: number | null; early_leave_minutes: number | null; worked_minutes: number | null; gross_worked_minutes: number | null; scheduled_break_minutes: number | null; exception_code: string | null };

export default async function AttendanceDayPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  const day = query.date && /^\d{4}-\d{2}-\d{2}$/.test(query.date) ? query.date : cairoToday();
  const cursor = query.cursor && query.cursor.length <= 40 ? query.cursor : null;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <PageFrame><Status title="الاتصال غير متاح" text="تعذر الاتصال بخدمة الحسابات. أعد المحاولة." /></PageFrame>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance`)}`);
  const { data: access, error: accessError } = await supabase.rpc('time_attendance_access_snapshot', { p_tenant_id: tenantId });
  if (accessError || !isObject(access)) return <PageFrame><Status title="الحضور غير متاح" text="لا تملك صلاحية عرض الحضور أو أن وحدة الحضور غير مفعلة لهذه الشركة." /></PageFrame>;
  const canManage = access.can_manage === true;
  const entitlementEnabled = access.entitlement_enabled === true;
  const canOpen = canManage || access.can_correct === true || access.can_approve === true;
  const result = canOpen
    ? await supabase.rpc('attendance_open_day', { p_tenant_id: tenantId, p_date: day, p_after: cursor, p_limit: 50 })
    : await supabase.rpc('attendance_day_list', { p_tenant_id: tenantId, p_date: day, p_after: cursor, p_limit: 50 });
  if (result.error || !isObject(result.data)) return <PageFrame><Status title="تعذر تحميل اليوم" text="لم تتغير أي سجلات. حدّث الصفحة أو أعد المحاولة." /></PageFrame>;
  const rows = Array.isArray(result.data.items) ? result.data.items as DayRow[] : [];
  const nextCursor = typeof result.data.next_cursor === 'string' ? result.data.next_cursor : null;
  const hasMore = result.data.has_more === true;
  const moreHref = nextCursor ? `/tenant/${tenantId}/attendance?date=${encodeURIComponent(day)}&cursor=${encodeURIComponent(nextCursor)}` : null;

  return <PageFrame footer="الحضور وسجل العمل">
      <section className="work-card task-page" aria-labelledby="attendance-title">
        <p className="eyebrow">متابعة يوم العمل</p>
        <div className="workspace-page-heading"><div><h1 id="attendance-title">الحضور اليومي</h1><p className="field-hint">اختر تاريخ العمل لمراجعة تسجيلات الدخول والخروج. لا يُجهّز يوم قبل بدايته حسب توقيت سياسة الدوام.</p></div></div>
        {!entitlementEnabled && <p className="form-message">وحدة الحضور غير مفعلة حاليًا. يمكنك مراجعة السجلات السابقة، ولن تتاح إضافة أو تعديل سجلات جديدة.</p>}
        <form method="get" className="attendance-date-form"><label htmlFor="attendance-date">تاريخ العمل</label><input id="attendance-date" type="date" name="date" defaultValue={day} /><button className="primary-button" type="submit">عرض اليوم</button></form>
        {canOpen && <p className="field-hint">استخدم التالي لعرض بقية الموظفين عند وجود سجلات إضافية.</p>}
        {rows.length === 0 ? <div className="empty-state"><h2>لا توجد سجلات لهذا اليوم</h2><p>{!entitlementEnabled ? 'لا توجد سجلات سابقة لهذا التاريخ.' : canOpen ? 'لا توجد تكليفات دوام بدأ يومها المحلي ضمن سياسة الدوام.' : 'لم تُجهّز سجلات لهذا اليوم بعد.'}</p></div> : <ul className="record-list attendance-day-list">
          {rows.map((row) => <li className="record-card" key={row.id}>
            <div className="record-main"><div className="record-title-row"><h2>{row.full_name}</h2><span className={`entity-status ${row.status === 'approved' ? 'is-active' : 'is-inactive'}`}>{statusLabel(row.status)}</span></div>
              <p className="record-meta">رقم الموظف: <bdi>{row.employee_code}</bdi></p>
              {row.schedule_kind === 'flexible' ? <p className="record-meta">يوم مرن · المطلوب {row.required_minutes ?? '—'} دقيقة · {timezoneLabel(row.timezone_name)}</p> : row.expected_start && row.expected_end && <p className="record-meta">المتوقع: {formatInstant(row.expected_start, row.timezone_name)} – {formatInstant(row.expected_end, row.timezone_name)} · {timezoneLabel(row.timezone_name)}</p>}
              {row.worked_minutes !== null && (row.status === 'ready' || row.status === 'approved') && (row.schedule_kind === 'flexible' ? <p className="record-meta">صافي العمل: {row.worked_minutes} من {row.required_minutes ?? '—'} دقيقة مطلوبة</p> : <p className="record-meta">التأخر: {row.late_minutes ?? 0} د · المغادرة المبكرة: {row.early_leave_minutes ?? 0} د · صافي العمل: {row.worked_minutes} د · الاستراحة المقررة: {row.scheduled_break_minutes ?? '—'} د</p>)}
              {row.exception_code === 'short_workday' && row.status !== 'approved' && <p className="form-message form-error">صافي المدة أقل من المطلوب؛ راجع اليوم قبل الاعتماد.</p>}
              {row.exception_code === 'absence_candidate' && row.status !== 'approved' && <p className="form-message form-error">انتهت الفترة بلا تسجيلات؛ راجع الحالة قبل إثبات الغياب.</p>}
            </div><Link className="secondary-button" href={`/tenant/${tenantId}/attendance/${row.id}`}>فتح السجل</Link>
          </li>)}
        </ul>}
        <div className="attendance-pagination" aria-live="polite"><span>عدد السجلات في هذه الصفحة: {rows.length}{hasMore ? '، توجد سجلات أخرى' : ''}</span>
          {hasMore && moreHref && <Link className="primary-button" href={moreHref}>التالي</Link>}
        </div>
      </section>
  </PageFrame>;
}

function cairoToday() { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()); }
function timezoneLabel(zone: string) { if (zone === 'Africa/Cairo') return 'توقيت القاهرة'; try { return new Intl.DateTimeFormat('ar-EG', { timeZone: zone, timeZoneName: 'long' }).formatToParts(new Date()).find((part) => part.type === 'timeZoneName')?.value ?? 'توقيت سياسة الدوام'; } catch { return 'توقيت سياسة الدوام'; } }
function formatInstant(value: string, zone: string) { return new Intl.DateTimeFormat('ar-EG', { dateStyle: 'short', timeStyle: 'short', timeZone: zone }).format(new Date(value)); }
function statusLabel(status: string) { return ({ open: 'قيد المتابعة', ready: 'جاهز للمراجعة', needs_review: 'يحتاج مراجعة', approved: 'معتمد' } as Record<string, string>)[status] ?? 'قيد المتابعة'; }
function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function Status({ title, text }: { title: string; text: string }) { return <section className="work-card task-page"><h1>{title}</h1><p>{text}</p></section>; }
