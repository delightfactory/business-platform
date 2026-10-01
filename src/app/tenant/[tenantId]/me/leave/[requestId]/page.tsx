import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isDayCountBasis, isObject, isUuid, type RequestDay } from '../form-rules';
import { PendingLink } from '../pending-link';
import { formatDays, formatInstant, stateClass, stateLabel } from '../states';
import { CancellationHistorySection, loadCancellationHistory } from './CancellationHistory';
import { cancellationEventActor, parseHistoryOffset } from './cancellation-rules';
import { DayBreakdown } from './DayBreakdown';
import { RequestCancellationForm } from './RequestCancellationForm';
import { WithdrawRequestForm } from './WithdrawRequestForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; requestId: string }>;
type Query = Promise<{ state?: string | string[]; h?: string | string[] }>;

type RequestDetail = {
  id: string;
  leave_type_name: string;
  start_date: string;
  end_date: string;
  total_units: number;
  is_half_day: boolean;
  state: string;
  version: number;
  reason: string;
  submitted_at: string | null;
  request_source: string;
  days: RequestDay[];
};

export default async function MyLeaveRequestPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId, requestId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(requestId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/leave/${requestId}`)}`);

  const historyOffset = parseHistoryOffset(query.h);
  const [detailResponse, history, accessResponse] = await Promise.all([
    supabase.rpc('leave_my_request_detail', { p_tenant: tenantId, p_request: requestId }),
    loadCancellationHistory(supabase, tenantId, requestId, historyOffset.invalid ? 0 : historyOffset.value),
    supabase.rpc('leave_access_snapshot', { p_tenant: tenantId }),
  ]);
  const data = detailResponse.data;
  const error = detailResponse.error;
  const request = error || !isObject(data) ? null : readRequest(data);
  if (!request) {
    const unavailable = Boolean(error && error.code === 'P0002') || (!error && !isObject(data));
    const forbidden = Boolean(error && error.code === '42501');
    return <Status tenantId={tenantId} retry={!unavailable && !forbidden}
      title={unavailable ? 'الطلب غير متاح' : forbidden ? 'عرض الطلب غير متاح' : 'تعذر تحميل الطلب الآن'}
      detail={unavailable ? 'لم نعثر على هذا الطلب ضمن سجلك، أو أنه لم يعد متاحًا للعرض.'
        : forbidden ? 'ليست لديك صلاحية عرض هذا الطلب. راجع إدارة الموارد البشرية.'
          : 'حدث خطأ أثناء تحميل تفاصيل الطلب. أعد المحاولة.'}
      requestId={requestId} />;
  }

  const latest = history.ok ? history.page.latest : null;
  const feedback = query.state === 'submitted' && request.state === 'submitted' ? 'تم إرسال طلبك وسينتظر قرار الموارد البشرية.'
    : query.state === 'withdrawn' && request.state === 'withdrawn' ? 'تم سحب الطلب وحُفظ السبب في سجل العملية.'
      : query.state === 'cancellation-requested' && request.state === 'approved' && latest?.to_state === 'pending'
        ? 'تم إرسال طلب الإلغاء إلى الموارد البشرية. يبقى طلب الإجازة معتمدًا حتى القرار.'
        : null;

  const pendingEvent = latest?.to_state === 'pending' ? latest : null;
  const historyFailed = !history.ok;
  const accessUnavailable = Boolean(accessResponse.error) || !isObject(accessResponse.data);
  const canRequestCancellation = !accessUnavailable && accessResponse.data.self_can_request === true;
  const stateNote = requestStateNote(request.state, canRequestCancellation);

  return <PageFrame footer="الخدمة الذاتية">
    {feedback && <FeedbackToast key={crypto.randomUUID()} message={feedback} />}
    <section className="work-card task-page" aria-labelledby="leave-request-title">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</PendingLink>
      <p className="eyebrow">طلب إجازة</p>
      <div className="record-title-row"><h1 id="leave-request-title">{request.leave_type_name}</h1>
        <span className={`entity-status ${stateClass(request.state)}`}>{stateLabel(request.state)}</span></div>
      <p className="record-meta">{request.submitted_at
        ? <>أُرسل في <bdi>{formatInstant(request.submitted_at)}</bdi> · </>
        : 'لم يُرسل بعد · '}الطلب المعلّق لا يحجز رصيدًا قبل الاعتماد.</p>

      <dl className="snapshot-grid">
        <div><dt>الحالة</dt><dd>{stateLabel(request.state)}</dd></div>
        <div><dt>إجمالي أيام الإجازة المحتسبة</dt><dd>{formatDays(request.total_units)} يوم{request.is_half_day ? ' · نصف يوم' : ''}</dd></div>
        <div><dt>تاريخ البداية</dt><dd><bdi>{request.start_date}</bdi></dd></div>
        <div><dt>تاريخ النهاية</dt><dd><bdi>{request.end_date}</bdi></dd></div>
        <div><dt>السبب</dt><dd>{request.reason || 'غير مسجل'}</dd></div>
        <div><dt>طريقة التسجيل</dt><dd>{request.request_source === 'hr' ? 'إدارة الموارد البشرية' : 'خدمة الموظف'}</dd></div>
      </dl>

      {isObject(data) && Array.isArray(data.correction_links) && data.correction_links.length > 0 && <>
        <h2>سجل استبدال الإجازة</h2>
        <ul className="record-list">{data.correction_links.map((link, index) => {
          if (!isObject(link) || !isUuid(link.original_request_id) || !isUuid(link.replacement_request_id)
            || typeof link.reason !== 'string' || typeof link.created_at !== 'string') return null;
          const original = link.original_request_id === request.id;
          return <li className="record-card" key={index}>
            <p>{link.reason}</p>
            <p className="record-meta">وقت التصحيح: <bdi>{formatInstant(link.created_at)}</bdi></p>
            <PendingLink href={`/tenant/${tenantId}/me/leave/${original ? link.replacement_request_id : link.original_request_id}`}>
              {original ? 'عرض الطلب البديل' : 'عرض الطلب الأصلي'}
            </PendingLink>
          </li>;
        })}</ul>
      </>}

      {stateNote && <p className="form-message" role="status">{stateNote}</p>}

      {request.days.length > 0 && <details className="task-disclosure">
        <summary className="secondary-button">تفاصيل أيام الطلب</summary>
        <DayBreakdown days={request.days} />
      </details>}
    </section>

    {request.state === 'approved' && <section className="work-card task-page" aria-labelledby="cancellation-action-title">
      {pendingEvent
        ? <>
          <div className="record-title-row"><h2 id="cancellation-action-title">طلب إلغاء معلّق</h2>
            <span className="entity-status is-pending">بانتظار قرار الموارد البشرية</span></div>
          <dl className="snapshot-grid">
            <div><dt>حالة طلب الإجازة</dt><dd>معتمد</dd></div>
            <div><dt>الخطوة التالية</dt><dd>إدارة الموارد البشرية</dd></div>
            <div><dt>وقت إرسال طلب الإلغاء</dt><dd><bdi>{formatInstant(pendingEvent.created_at)}</bdi></dd></div>
            <div><dt>أُرسل من طرف</dt><dd>{cancellationEventActor(pendingEvent, user.id)}</dd></div>
            <div><dt>سبب طلب الإلغاء</dt><dd>{pendingEvent.reason}</dd></div>
          </dl>
          <p className="form-message" role="status">الموارد البشرية ستراجع طلب الإلغاء. عند قبوله تُلغى الإجازة ويُعاد أي
            رصيد خُصم لها. لا تحتاج إلى إرسال طلب آخر أثناء الانتظار.</p>
        </>
        : historyFailed
          ? <>
            <h2 id="cancellation-action-title">طلب إلغاء الطلب المعتمد</h2>
            <p className="form-message" role="status">تعذّر تحميل سجل طلبات الإلغاء لهذه الصفحة، لذلك لن يُعرض إرسال طلب
              إلغاء جديد حتى نتحقق من الحالة الحالية. تفاصيل طلبك أعلاه لم تتغيّر؛ أعد المحاولة من قسم «سجل طلبات
              الإلغاء» أدناه.</p>
          </>
          : !canRequestCancellation
            ? <>
                <h2 id="cancellation-action-title">إلغاء الإجازة</h2>
                <p className="form-message" role="status">{accessUnavailable
                  ? 'تعذّر التحقق من صلاحية طلب الإلغاء الآن. أعد تحميل الصفحة للمحاولة من جديد.'
                  : 'حسابك يسمح بعرض الإجازة دون طلب إلغائها. راجع إدارة الموارد البشرية إذا أردت إلغاءها.'}</p>
                {accessUnavailable && <PendingLink className="secondary-button"
                  href={`/tenant/${tenantId}/me/leave/${requestId}`}>إعادة المحاولة</PendingLink>}
              </>
            : <>
              <div className="record-title-row"><h2 id="cancellation-action-title">طلب إلغاء الطلب المعتمد</h2>
                <span className="entity-status is-active">معتمد — قابل للإلغاء</span></div>
              <p className="field-hint">اكتب سبب الإلغاء ليُراجعَه فريق الموارد البشرية. يظل الطلب معتمدًا حتى القرار.</p>
              {latest?.to_state === 'rejected' && <p className="form-message" role="status">رُفض طلب إلغاء سابق لهذا
                الطلب. يمكنك إرسال طلب إلغاء جديد بسبب واضح.</p>}
              <details className="task-disclosure">
                <summary className="secondary-button">كتابة سبب الإلغاء وإرسال الطلب</summary>
                <RequestCancellationForm tenantId={tenantId} requestId={requestId}
                  expectedVersion={request.version} idempotencyKey={crypto.randomUUID()} />
              </details>
            </>}
    </section>}

    {request.state === 'submitted' && <section className="work-card task-page" aria-labelledby="withdraw-title">
      <h2 id="withdraw-title">سحب الطلب</h2>
      <p className="field-hint">يمكنك سحب طلبك ما دام بانتظار قرار الموارد البشرية. بعد السحب تصبح حالته «مسحوبًا» نهائيًا،
        ويُحفظ سببك في سجل العملية مع هويتك ووقتها. لن يُخصم أي رصيد لأن الطلب لم يُعتمد بعد.</p>
      <WithdrawRequestForm tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
        idempotencyKey={crypto.randomUUID()} />
    </section>}

    <CancellationHistorySection tenantId={tenantId} requestId={requestId} view={history}
      requestedOffset={historyOffset.invalid ? 0 : historyOffset.value}
      offsetInvalid={historyOffset.invalid} currentUserId={user.id} />
  </PageFrame>;
}

function requestStateNote(state: string, canRequestCancellation: boolean): string {
  if (state === 'approved') return canRequestCancellation
    ? 'تم اعتماد الإجازة. يمكنك متابعة طلب إلغائها من القسم التالي.'
    : 'تم اعتماد الإجازة.';
  if (state === 'cancelled') return 'أُلغيت الإجازة وأُعيد أي رصيد خُصم لها. يمكنك مراجعة قرار الإلغاء أدناه.';
  if (state === 'rejected') return 'رفضت الموارد البشرية هذا الطلب، ولم يُخصم له رصيد.';
  if (state === 'withdrawn') return 'سحبت هذا الطلب بنفسك، ولم يُخصم به رصيد.';
  if (state === 'draft') return 'هذا الطلب مسودة ولم يُرسل بعد.';
  return '';
}

function readRequest(data: Record<string, unknown>): RequestDetail | null {
  if (!isUuid(data.id) || typeof data.leave_type_name !== 'string' || typeof data.start_date !== 'string'
    || typeof data.end_date !== 'string' || typeof data.total_units !== 'number'
    || typeof data.is_half_day !== 'boolean' || typeof data.state !== 'string'
    || typeof data.version !== 'number' || typeof data.request_source !== 'string'
    || !(data.submitted_at === null || typeof data.submitted_at === 'string')
    || !(data.reason === null || typeof data.reason === 'string')
    || !Array.isArray(data.days)) return null;
  const days: RequestDay[] = [];
  for (const day of data.days) {
    if (!isObject(day) || typeof day.date !== 'string' || typeof day.units !== 'number'
      || typeof day.eligible !== 'boolean' || typeof day.is_weekly_rest !== 'boolean'
      || !isDayCountBasis(day.day_count_basis)
      || !(day.holiday_name === null || typeof day.holiday_name === 'string')) return null;
    days.push({
      date: day.date,
      units: day.units,
      eligible: day.eligible,
      is_weekly_rest: day.is_weekly_rest,
      holiday_name: day.holiday_name,
      day_count_basis: day.day_count_basis,
    });
  }
  return {
    id: data.id,
    leave_type_name: data.leave_type_name,
    start_date: data.start_date,
    end_date: data.end_date,
    total_units: data.total_units,
    is_half_day: data.is_half_day,
    state: data.state,
    version: data.version,
    reason: data.reason ?? '',
    submitted_at: data.submitted_at,
    request_source: data.request_source,
    days,
  };
}

function Status({ tenantId, requestId, title, detail, retry = false }: {
  tenantId: string; requestId?: string; title: string; detail: string; retry?: boolean;
}) {
  return <PageFrame footer="الخدمة الذاتية">
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      {retry && <Link className="secondary-button" href={`/tenant/${tenantId}/me/leave/${requestId}`}>إعادة المحاولة</Link>}
      <Link className="secondary-button" href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</Link>
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
    </section>
  </PageFrame>;
}
