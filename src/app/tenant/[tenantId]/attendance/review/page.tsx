import { Avatar, Panel, PageHeader, ButtonLink, Message, Input, Button, RecordCard, EmptyState, Badge, Field } from '@/components/ui';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { AttendanceBulkApprovalForm } from '../AttendanceBulkApprovalForm';
import styles from '../attendance-lists.module.css';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ date?: string; filter?: string; cursor?: string }>;
type QueueRow = { id: string; employee_code: string; full_name: string; status: string; exception_code: string | null; owner_permission: string | null; worked_minutes: number | null; late_minutes: number | null; early_leave_minutes: number | null; overtime_pending_count: number; can_bulk_approve: boolean };
type Queue = { items: QueueRow[]; counts: { exception_count: number; clean_ready: number; overtime_pending: number }; next_cursor: string | null; has_more: boolean };
const filters = ['all', 'exceptions', 'ready', 'overtime'] as const;

export default async function AttendanceReviewPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  const date = query.date && /^\d{4}-\d{2}-\d{2}$/.test(query.date) ? query.date : cairoToday();
  const filter = filters.includes(query.filter as typeof filters[number]) ? query.filter as typeof filters[number] : 'all';
  const cursor = query.cursor && query.cursor.length <= 64 ? query.cursor : null;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <PageFrame><Status title="تعذر الاتصال" text="تعذر تحميل قائمة المراجعة. أعد المحاولة." /></PageFrame>;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/attendance/review`)}`);
  const { data: access, error: accessError } = await supabase.rpc('time_attendance_access_snapshot', { p_tenant_id: tenantId });
  if (accessError || !isObject(access)) return <PageFrame><Status title="قائمة المراجعة غير متاحة" text="تحقق من عضويتك وصلاحيات الحضور لهذه الشركة." /></PageFrame>;
  const result = await supabase.rpc('attendance_review_queue', {
    p_tenant_id: tenantId, p_operational_date: date, p_filter: filter, p_after: cursor, p_limit: 50,
  });
  if (result.error || !isObject(result.data) || !Array.isArray(result.data.items)) return <PageFrame><Status title="تعذر تحميل القائمة" text="لم تتغير أي سجلات. حدّث الصفحة أو أعد المحاولة." /></PageFrame>;
  const queue = result.data as unknown as Queue;
  const canBulkApprove = access.entitlement_enabled === true && access.can_approve === true;
  const nextHref = queue.next_cursor ? `/tenant/${tenantId}/attendance/review?date=${encodeURIComponent(date)}&filter=${filter}&cursor=${encodeURIComponent(queue.next_cursor)}` : null;
  const count = queue.counts ?? { exception_count: 0, clean_ready: 0, overtime_pending: 0 };

  return <PageFrame footer="مراجعة الحضور وسجل العمل">
    <Panel className={` task-page attendance-review-page ${styles.reviewPage}`} aria-labelledby="attendance-review-title">
      <p className="eyebrow">مهام مراجعة اليوم</p>
      <div className="workspace-page-heading"><div><PageHeader id="attendance-review-title" title={<>مراجعة الحضور</>} description={<> ابدأ بالحالات التي تحتاج قرارًا، واعتمد الأيام المكتملة بعد مراجعة بياناتها. لا تُعتمد الحالات الاستثنائية جماعيًا. </>} /></div>
        <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance?date=${encodeURIComponent(date)}`}>العودة إلى اليوم</ButtonLink>
      </div>
      {access.entitlement_enabled !== true && <Message tone="info" >وحدة الحضور غير مفعلة. هذه القائمة للقراءة فقط.</Message>}
      <div className={styles.toolbar}><form method="get" className={styles.dateForm}><Field  id="review-date" label={<>تاريخ العمل</>}><Input id="review-date" type="date" name="date" defaultValue={date} /></Field><input type="hidden" name="filter" value={filter} /><Button variant="solid"  type="submit">عرض التاريخ</Button></form></div>
      <nav className="attendance-review-filters" aria-label="تصفية قائمة المراجعة">
        <FilterLink tenantId={tenantId} date={date} active={filter === 'all'} filter="all" label="الكل" />
        <FilterLink tenantId={tenantId} date={date} active={filter === 'exceptions'} filter="exceptions" label={`استثناءات تحتاج قرارًا · ${count.exception_count}`} />
        <FilterLink tenantId={tenantId} date={date} active={filter === 'ready'} filter="ready" label={`جاهز للاعتماد · ${count.clean_ready}`} />
        <FilterLink tenantId={tenantId} date={date} active={filter === 'overtime'} filter="overtime" label={`إضافي بانتظار القرار · ${count.overtime_pending}`} />
      </nav>
      {queue.items.length === 0 ? <EmptyState title={<>لا توجد مهام في هذا العرض</>} description={<>جرّب تصفية أخرى أو اختر تاريخًا مختلفًا.</>} />
      : filter === 'ready' && canBulkApprove && queue.items.some((row) => row.can_bulk_approve)
        ? <AttendanceBulkApprovalForm tenantId={tenantId} date={date} rows={queue.items.filter((row) => row.can_bulk_approve)} />
        : <ul className="record-list attendance-review-list">
        {queue.items.map((row) => <RecordCard  key={row.id}>
          <div className="record-main"><div className="record-title-row"><Avatar name={row.full_name} size={40}/><h2>{row.full_name}</h2><Badge tone={row.status === 'approved' ? "ok" : "neutral"} >{statusLabel(row.status)}</Badge></div>
            <p className="record-meta">رقم الموظف: <bdi>{row.employee_code}</bdi></p>
            {row.exception_code && <Message tone="bad" >{exceptionLabel(row.exception_code)} · المسؤول: {ownerLabel(row.owner_permission)}</Message>}
            {!row.exception_code && row.status === 'ready' && <p className="record-meta">اليوم مكتمل ولا توجد استثناءات؛ يمكن مراجعته واعتماده.</p>}
            {(row.overtime_pending_count ?? 0) > 0 && <Message tone="bad" >عمل إضافي بانتظار قرار فردي: {row.overtime_pending_count}</Message>}
            {row.worked_minutes !== null && <p className="record-meta">صافي العمل: {row.worked_minutes} دقيقة{row.late_minutes !== null ? ` · التأخر ${row.late_minutes} د` : ''}{row.early_leave_minutes !== null ? ` · المغادرة المبكرة ${row.early_leave_minutes} د` : ''}</p>}
          </div><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/attendance/${row.id}`}>مراجعة السجل</ButtonLink>
        </RecordCard>)}
      </ul>}
      {filter === 'ready' && !canBulkApprove && queue.items.some((row) => row.can_bulk_approve) && <p className="field-hint">يمكن لمراجع الحضور اعتماد الأيام الجاهزة؛ لا تملك هذه العضوية صلاحية الاعتماد.</p>}
      <div className="attendance-pagination"><span>عدد السجلات في هذه الصفحة: {queue.items.length}{queue.has_more ? '، توجد سجلات أخرى' : ''}</span>{queue.has_more && nextHref && <ButtonLink  href={nextHref}>التالي</ButtonLink>}</div>
    </Panel>
  </PageFrame>;
}

function FilterLink({ tenantId, date, filter, active, label }: { tenantId: string; date: string; filter: typeof filters[number]; active: boolean; label: string }) {
  return <Link aria-current={active ? 'page' : undefined} className={active ? 'attendance-review-filter is-active' : 'attendance-review-filter'} href={`/tenant/${tenantId}/attendance/review?date=${encodeURIComponent(date)}&filter=${filter}`}>{label}</Link>;
}
function statusLabel(status: string) { return ({ open: 'قيد المتابعة', ready: 'جاهز للمراجعة', needs_review: 'يحتاج مراجعة', approved: 'معتمد' } as Record<string, string>)[status] ?? 'قيد المتابعة'; }
function exceptionLabel(code: string) { return ({ ambiguous_local_time: 'وقت غير واضح حسب المنطقة الزمنية', conflicting_punches: 'تعارض في تسجيلات الحضور والانصراف', outside_window: 'التسجيل خارج الفترة المسموح بها', missing_punch: 'ينقص تسجيل حضور أو انصراف', short_workday: 'مدة العمل أقل من المطلوب', absence_candidate: 'لا توجد تسجيلات بعد انتهاء اليوم' } as Record<string, string>)[code] ?? 'تحتاج الحالة إلى مراجعة فردية'; }
function ownerLabel(owner: string | null) { return owner === 'attendance.approve' ? 'مراجع الحضور' : 'مسؤول تصحيح التسجيلات'; }
function cairoToday() { return new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()); }
function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function Status({ title, text }: { title: string; text: string }) { return <Panel className=" task-page"><PageHeader  title={<>{title}</>} description={<> {text} </>} /></Panel>; }
