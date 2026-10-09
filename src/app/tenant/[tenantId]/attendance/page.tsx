import { Button, ButtonLink, DataTable, Input, Message, PageHeader, Panel, EmptyState, Badge, Field } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import styles from './attendance-lists.module.css';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ date?: string; cursor?: string }>;
type DayRow = { id: string; employee_code: string; full_name: string; status: string; timezone_name: string; expected_start: string | null; expected_end: string | null; schedule_kind: string; required_minutes: number | null; late_minutes: number | null; early_leave_minutes: number | null; worked_minutes: number | null; gross_worked_minutes: number | null; scheduled_break_minutes: number | null; exception_code: string | null; overtime_pending_count?: number };

export default async function AttendanceDayPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  const day = query.date && /^\d{4}-\d{2}-\d{2}$/.test(query.date) ? query.date : cairoToday();
  const cursor = query.cursor && query.cursor.length <= 40 ? query.cursor : null;
  const retryHref = `/tenant/${tenantId}/attendance?date=${encodeURIComponent(day)}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <PageFrame><Status title="الاتصال غير متاح" text="تعذر الاتصال بخدمة الحسابات. أعد المحاولة." retryHref={retryHref} /></PageFrame>;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance`)}`);
  const { data: access, error: accessError } = await supabase.rpc('time_attendance_access_snapshot', { p_tenant_id: tenantId });
  if (accessError || !isObject(access)) return <PageFrame><Status title="الحضور غير متاح" text="لا تملك صلاحية عرض الحضور أو أن وحدة الحضور غير مفعلة لهذه الشركة." /></PageFrame>;
  const canManage = access.can_manage === true;
  const { data: channelAccess, error: channelAccessError } = await supabase.rpc('attendance_channel_access', { p_tenant: tenantId });
  const entitlementEnabled = access.entitlement_enabled === true;
  const canOpen = canManage || access.can_correct === true || access.can_approve === true;
  const result = canOpen
    ? await supabase.rpc('attendance_open_day', { p_tenant_id: tenantId, p_date: day, p_after: cursor, p_limit: 50 })
    : await supabase.rpc('attendance_day_list', { p_tenant_id: tenantId, p_date: day, p_after: cursor, p_limit: 50 });
  if (result.error || !isObject(result.data)) return <PageFrame><Status title="تعذر تحميل اليوم" text="تعذر تحميل سجلات هذا اليوم. أعد المحاولة لعرض الحالة الحالية." retryHref={retryHref} /></PageFrame>;
  const rows = Array.isArray(result.data.items) ? result.data.items as DayRow[] : [];
  if (rows.length) {
    const summary = await supabase.rpc('attendance_overtime_day_summary', { p_tenant_id: tenantId, p_operational_date: day, p_instance_ids: rows.map((row) => row.id) });
    if (!summary.error && isObject(summary.data) && isObject(summary.data.pending_by_instance)) {
      for (const row of rows) row.overtime_pending_count = Number(summary.data.pending_by_instance[row.id] ?? 0);
    }
  }
  const nextCursor = typeof result.data.next_cursor === 'string' ? result.data.next_cursor : null;
  const hasMore = result.data.has_more === true;
  const moreHref = nextCursor ? `/tenant/${tenantId}/attendance?date=${encodeURIComponent(day)}&cursor=${encodeURIComponent(nextCursor)}` : null;

  return <PageFrame footer="الحضور وسجل العمل">
      <Panel className=" task-page" aria-labelledby="attendance-title">
        <p className="eyebrow">متابعة يوم العمل</p>
        <div className="workspace-page-heading"><div><PageHeader id="attendance-title" title={<>الحضور اليومي</>} description={<> اختر تاريخ العمل لمراجعة تسجيلات الدخول والخروج. لا يُجهّز يوم قبل بدايته حسب توقيت سياسة الدوام. </>} /></div></div>
        {!entitlementEnabled && <Message tone="info" >وحدة الحضور غير مفعلة حاليًا. يمكنك مراجعة السجلات السابقة، ولن تتاح إضافة أو تعديل سجلات جديدة.</Message>}
        <div className={styles.toolbar}>
          <form method="get" className={styles.dateForm}><Field  id="attendance-date" label={<>تاريخ العمل</>}><Input id="attendance-date" type="date" name="date" defaultValue={day} /></Field><Button variant="solid"  type="submit">عرض اليوم</Button></form>
          <nav className={styles.tools} aria-label="مهام الحضور">
            {!channelAccessError && channelAccess?.can_view === true && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/sources`}>قنوات الحضور</ButtonLink>}
            {canManage && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/import`}>استيراد تسجيلات من ملف</ButtonLink>}
            {access.can_view === true && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/unassigned`}>مراجعة التسجيلات بلا تكليف</ButtonLink>}
            {access.can_view === true && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/review?date=${encodeURIComponent(day)}`}>فتح قائمة المراجعة</ButtonLink>}
          </nav>
        </div>
        {canOpen && <p className="field-hint">استخدم التالي لعرض بقية الموظفين عند وجود سجلات إضافية.</p>}
        {rows.length === 0 ? <EmptyState title={<>لا توجد سجلات لهذا اليوم</>} description={<>{!entitlementEnabled ? 'لا توجد سجلات سابقة لهذا التاريخ.' : canOpen ? 'لا توجد تكليفات دوام بدأ يومها المحلي ضمن سياسة الدوام.' : 'لم تُجهّز سجلات لهذا اليوم بعد.'}</>} /> : <DataTable className={styles.table} role="table">
          <caption>سجلات يوم العمل <bdi>{day}</bdi> — المعروضة في هذه الصفحة</caption>
          <thead role="rowgroup"><tr role="row"><th scope="col" role="columnheader">الموظف</th><th scope="col" role="columnheader">الدوام المتوقع</th><th scope="col" role="columnheader">مؤشرات اليوم والمراجعة</th><th scope="col" role="columnheader">الحالة</th><th scope="col" role="columnheader">الإجراء</th></tr></thead>
          <tbody role="rowgroup">{rows.map((row) => <tr role="row" key={row.id}>
            <th scope="row" role="rowheader"><h2 id={`attendance-person-${row.id}`}>{row.full_name}</h2>
              <p className="record-meta">رقم الموظف: <bdi>{row.employee_code}</bdi></p>
            </th>
            <td role="cell"><span className={styles.mobileLabel} aria-hidden="true">الدوام المتوقع</span>
              {row.schedule_kind === 'flexible' ? <p className="record-meta">يوم مرن · المطلوب {row.required_minutes ?? '—'} دقيقة · {timezoneLabel(row.timezone_name)}</p> : row.expected_start && row.expected_end && <p className="record-meta">المتوقع: {formatInstant(row.expected_start, row.timezone_name)} – {formatInstant(row.expected_end, row.timezone_name)} · {timezoneLabel(row.timezone_name)}</p>}
            </td>
            <td role="cell"><span className={styles.mobileLabel} aria-hidden="true">مؤشرات اليوم والمراجعة</span>
              {row.worked_minutes !== null && (row.status === 'ready' || row.status === 'approved') && (row.schedule_kind === 'flexible' ? <p className="record-meta">صافي العمل: {row.worked_minutes} من {row.required_minutes ?? '—'} دقيقة مطلوبة</p> : <p className="record-meta">التأخر: {row.late_minutes ?? 0} د · المغادرة المبكرة: {row.early_leave_minutes ?? 0} د · صافي العمل: {row.worked_minutes} د · الاستراحة المقررة: {row.scheduled_break_minutes ?? '—'} د</p>)}
              {row.exception_code === 'short_workday' && row.status !== 'approved' && <Message tone="bad" >صافي المدة أقل من المطلوب؛ راجع اليوم قبل الاعتماد.</Message>}
              {row.exception_code === 'absence_candidate' && row.status !== 'approved' && <Message tone="bad" >انتهت الفترة بلا تسجيلات؛ راجع الحالة قبل إثبات الغياب.</Message>}
              {(row.overtime_pending_count ?? 0) > 0 && <Message tone="bad" >يوجد مرشح عمل إضافي بانتظار المراجعة: {row.overtime_pending_count}</Message>}
            </td>
            <td role="cell"><span className={styles.mobileLabel} aria-hidden="true">الحالة</span><Badge tone={row.status === 'approved' ? "ok" : "neutral"} >{statusLabel(row.status)}</Badge></td>
            <td role="cell"><ButtonLink variant="ghost" aria-describedby={`attendance-person-${row.id}`}  href={`/tenant/${tenantId}/attendance/${row.id}`}>فتح السجل</ButtonLink></td>
          </tr>)}</tbody>
        </DataTable>}
        <div className="attendance-pagination" aria-live="polite"><span>عدد السجلات في هذه الصفحة: {rows.length}{hasMore ? '، توجد سجلات أخرى' : ''}</span>
          {hasMore && moreHref && <ButtonLink  href={moreHref}>التالي</ButtonLink>}
        </div>
      </Panel>
  </PageFrame>;
}

function cairoToday() { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()); }
function timezoneLabel(zone: string) { if (zone === 'Africa/Cairo') return 'توقيت القاهرة'; try { return new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE, { timeZone: zone, timeZoneName: 'long' }).formatToParts(new Date()).find((part) => part.type === 'timeZoneName')?.value ?? 'توقيت سياسة الدوام'; } catch { return 'توقيت سياسة الدوام'; } }
function formatInstant(value: string, zone: string) { return new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE, { dateStyle: 'short', timeStyle: 'short', timeZone: zone }).format(new Date(value)); }
function statusLabel(status: string) { return ({ open: 'قيد المتابعة', ready: 'جاهز للمراجعة', needs_review: 'يحتاج مراجعة', approved: 'معتمد' } as Record<string, string>)[status] ?? 'قيد المتابعة'; }
function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function Status({ title, text, retryHref }: { title: string; text: string; retryHref?: string }) { return <Panel className=" task-page"><PageHeader  title={<>{title}</>} description={<> {text} </>} />{retryHref && <ButtonLink variant="ghost"  href={retryHref}>إعادة المحاولة</ButtonLink>}</Panel>; }
