import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PendingLink } from '../pending-link';
import { formatInstant } from '../states';
import {
  CANCELLATION_HISTORY_LIMIT,
  cancellationEventActor,
  cancellationEventLabel,
  cancellationStateClass,
  cancellationStateLabel,
  historyErrorText,
  historyPageNumber,
  mapHistoryError,
  readHistoryPage,
  type CancellationHistoryPage,
} from './cancellation-rules';
import styles from '../leave.module.css';

export type CancellationHistoryView =
  | { ok: true; page: CancellationHistoryPage }
  | { ok: false; code: string };

type SupabaseServer = NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>;

export async function loadCancellationHistory(
  supabase: SupabaseServer,
  tenantId: string,
  requestId: string,
  offset: number,
): Promise<CancellationHistoryView> {
  let response;
  try {
    response = await supabase.rpc('leave_my_cancellation_history', {
      p_tenant: tenantId, p_request: requestId,
      p_limit: CANCELLATION_HISTORY_LIMIT, p_offset: offset,
    });
  } catch {
    return { ok: false, code: 'failed' };
  }
  const { data, error } = response;
  if (error) return { ok: false, code: mapHistoryError(error.message, error.code) };
  const page = readHistoryPage(data, offset);
  if (!page) return { ok: false, code: 'failed' };
  return { ok: true, page };
}

export function CancellationHistorySection({ tenantId, requestId, view, requestedOffset, offsetInvalid, currentUserId }: {
  tenantId: string;
  requestId: string;
  view: CancellationHistoryView;
  requestedOffset: number;
  offsetInvalid: boolean;
  currentUserId: string;
}) {
  const retryHref = historyHref(tenantId, requestId, requestedOffset);
  return <section className="work-card task-page" aria-labelledby="cancellation-history-title">
    <h2 id="cancellation-history-title">سجل طلبات الإلغاء</h2>
    <p className="field-hint">طلبات الإلغاء وقرارات الموارد البشرية، من الأقدم إلى الأحدث. الحالات أدناه هي وقت كل حركة؛ حالة الإجازة الحالية أعلى الصفحة.</p>

    {offsetInvalid ? <p className="form-message form-error" role="alert">رقم صفحة سجل الإلغاء غير صالح.{' '}
      <PendingLink href={historyHref(tenantId, requestId, 0)}>العودة إلى أول صفحة</PendingLink></p>
      : !view.ok ? <div className="empty-state" role="alert">
        <h2>تعذر تحميل سجل طلبات الإلغاء</h2>
        <p>{historyErrorText(view.code)} تعذر التحقق من أحدث حالة لطلب الإلغاء. قد تكون حالة طلب الإلغاء تغيّرت. أعد تحميل
          السجل قبل أي إجراء جديد.</p>
        <PendingLink className="secondary-button" href={retryHref}>إعادة المحاولة</PendingLink>
      </div>
        : <HistoryPage tenantId={tenantId} requestId={requestId} page={view.page} currentUserId={currentUserId} />}
  </section>;
}

function HistoryPage({ tenantId, requestId, page, currentUserId }: {
  tenantId: string;
  requestId: string;
  page: CancellationHistoryPage;
  currentUserId: string;
}) {
  if (page.items.length === 0) return page.offset > 0
    ? <>
      <div className="empty-state">
        <h2>لا توجد سجلات في هذه الصفحة</h2>
        <p>انتهت السجلات قبل هذا الرقم. عد إلى الصفحات السابقة أو إلى أول الصفحة.</p>
        <PendingLink className="secondary-button" href={historyHref(tenantId, requestId, 0)}>العودة إلى أول صفحة</PendingLink>
      </div>
      <HistoryNav tenantId={tenantId} requestId={requestId} page={page} />
    </>
    : <div className="empty-state">
      <h2>لا توجد طلبات إلغاء مسجلة على هذا الطلب</h2>
      <p>لم يُرسل أي طلب إلغاء لهذا الطلب بعد، ولا توجد قرارات محفوظة عليه.</p>
    </div>;
  return <>
    <ul className="record-list">{page.items.map((event) => <li className="record-card" key={event.id}>
      <div className="record-main">
        <div className="record-title-row"><h3>{cancellationEventLabel(event.event_key)}</h3>
          <span className={`entity-status ${cancellationStateClass(event.to_state)}`}>
            بعد هذه الحركة: {cancellationStateLabel(event.to_state)}</span></div>
        <p className="record-meta">{event.from_state
          ? <>من {cancellationStateLabel(event.from_state)} إلى {cancellationStateLabel(event.to_state)}</>
          : <>الحالة بعد الحركة: {cancellationStateLabel(event.to_state)}</>}
          {' · '}<bdi>{formatInstant(event.created_at)}</bdi>{' · '}
          {cancellationEventActor(event, currentUserId)}</p>
        <p className="record-meta">السبب: {event.reason}</p>
        {event.time_reconciliation_required && <p className="record-meta">
          يتطلب هذا القرار مراجعة سجل الحضور المرتبط بأيام الطلب لدى فريق الموارد البشرية.</p>}
      </div>
    </li>)}</ul>
    <HistoryNav tenantId={tenantId} requestId={requestId} page={page} />
  </>;
}

function HistoryNav({ tenantId, requestId, page }: {
  tenantId: string;
  requestId: string;
  page: CancellationHistoryPage;
}) {
  if (page.offset === 0 && !page.hasMore) return null;
  return <nav className={styles.pagination} aria-label="صفحات سجل طلبات الإلغاء">
    <span role="status">صفحة {historyPageNumber(page.offset)} · عدد السجلات في الصفحة: {page.items.length}
      {page.hasMore ? '، وتوجد سجلات بعد هذه الصفحة' : ''}</span>
    <span className={styles.paginationNav}>
      {page.offset > 0 && <PendingLink className="secondary-button"
        href={historyHref(tenantId, requestId, page.offset - CANCELLATION_HISTORY_LIMIT)}>السابق</PendingLink>}
      {page.hasMore && <PendingLink className="secondary-button"
        href={historyHref(tenantId, requestId, page.offset + CANCELLATION_HISTORY_LIMIT)}>التالي</PendingLink>}
    </span>
  </nav>;
}

function historyHref(tenantId: string, requestId: string, offset: number): string {
  const suffix = offset > 0 ? `?h=${offset}` : '';
  return `/tenant/${tenantId}/me/leave/${requestId}${suffix}`;
}
