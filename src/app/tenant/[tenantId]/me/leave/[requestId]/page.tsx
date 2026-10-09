import { PageHeader, Disclosure } from '@/components/ui';
import { Panel, Message, RecordCard, ButtonLink } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { Badge, Icon, KeyValueStrip } from '@/components/ui';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isDayCountBasis, isDate, isInstant, isLeaveAccessSnapshot, isObject, isUuid, type RequestDay } from '../form-rules';
import { PendingLink } from '../pending-link';
import { formatDays, formatInstant, isRequestState, stateLabel } from '../states';
import { CancellationHistorySection, loadCancellationHistory } from './CancellationHistory';
import { cancellationEventActor, parseHistoryOffset } from './cancellation-rules';
import { DayBreakdown } from './DayBreakdown';
import { RequestCancellationForm } from './RequestCancellationForm';
import { WithdrawRequestForm } from './WithdrawRequestForm';
import styles from '../leave.module.css';

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
    readResponse(() => supabase.rpc('leave_my_request_detail', { p_tenant: tenantId, p_request: requestId })),
    loadCancellationHistory(supabase, tenantId, requestId, historyOffset.invalid ? 0 : historyOffset.value),
    readResponse(() => supabase.rpc('leave_access_snapshot', { p_tenant: tenantId })),
  ]);
  const data = detailResponse?.data;
  const error = detailResponse?.error ?? (detailResponse === null ? { code: 'READ_UNAVAILABLE' } : null);
  const request = error || !isObject(data) ? null : readRequest(data);
  if (!request || request.id.toLowerCase() !== requestId.toLowerCase()) {
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
  const feedback = query.state === 'submitted' && request.state === 'submitted' ? 'حالة طلبك الحالية: مُقدَّم وبانتظار قرار الموارد البشرية.'
    : query.state === 'withdrawn' && request.state === 'withdrawn' ? 'حالة طلبك الحالية: مسحوب. يمكنك مراجعة تفاصيله أدناه.'
      : query.state === 'cancellation-requested' && request.state === 'approved' && latest?.to_state === 'pending'
        ? 'طلب الإلغاء معلّق حاليًا بانتظار قرار الموارد البشرية. يبقى طلب الإجازة معتمدًا حتى القرار.'
        : null;

  const pendingEvent = latest?.to_state === 'pending' ? latest : null;
  const historyFailed = !history.ok;
  const accessUnavailable = !accessResponse || Boolean(accessResponse.error) || !isLeaveAccessSnapshot(accessResponse.data);
  const canRequestCancellation = !accessUnavailable && accessResponse?.data.self_can_request === true;
  const stateNote = requestStateNote(request.state, canRequestCancellation);

  return <PageFrame footer="الخدمة الذاتية">
    {feedback && <FeedbackToast key={crypto.randomUUID()} message={feedback} />}
    <div className={styles.detailPage}>
    <Panel className="task-page" aria-labelledby="leave-request-title">
      <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/me/leave`}><Icon name="arrowRight" size={18}/>إجازاتي</PendingLink>
      <p className="eyebrow">طلب إجازة</p>
      <div className="record-title-row"><PageHeader id="leave-request-title" title={<>{request.leave_type_name}</>} />
        <Badge tone={request.state === 'approved' ? 'ok' : request.state === 'rejected' ? 'bad' : request.state === 'submitted' ? 'warn' : 'neutral'}>{stateLabel(request.state)}</Badge></div>
      <p className="record-meta">{request.submitted_at
        ? <>أُرسل في <bdi>{formatInstant(request.submitted_at)}</bdi> · </>
        : 'لم يُرسل بعد · '}الطلب المعلّق لا يحجز رصيدًا قبل الاعتماد.</p>

      {stateNote && <Message tone="info"  role="status">{stateNote}</Message>}

      <KeyValueStrip items={[
        { label: 'أيام الإجازة المحتسبة', value: <>{formatDays(request.total_units)} يوم{request.is_half_day ? ' · نصف يوم' : ''}</> },
        { label: 'من', value: <bdi>{request.start_date}</bdi> },
        { label: 'إلى', value: <bdi>{request.end_date}</bdi> },
      ]}/>
      <Disclosure summary={<>سبب الإجازة وطريقة التسجيل</>} className="task-disclosure">

      <dl className={styles.requestContext}>
        <div><dt>سبب الإجازة</dt><dd>{request.reason || 'غير مسجل'}</dd></div>
        <div><dt>طريقة التسجيل</dt><dd>{request.request_source === 'hr' ? 'إدارة الموارد البشرية' : 'خدمة الموظف'}</dd></div>
      </dl>
      </Disclosure>

      {isObject(data) && Array.isArray(data.correction_links) && data.correction_links.length > 0 && <>
        <h2>سجل استبدال الإجازة</h2>
        <ul className="record-list">{data.correction_links.map((link, index) => {
          if (!isObject(link) || !isUuid(link.original_request_id) || !isUuid(link.replacement_request_id)
            || typeof link.reason !== 'string') return null;
          const original = link.original_request_id.toLowerCase() === request.id.toLowerCase();
          return <RecordCard  key={index}>
            <p>{link.reason}</p>
            <p className="record-meta">وقت التصحيح: {isInstant(link.created_at) ? <bdi>{formatInstant(link.created_at)}</bdi> : 'غير متاح الآن'}</p>
            <PendingLink href={`/tenant/${tenantId}/me/leave/${original ? link.replacement_request_id : link.original_request_id}`}>
              {original ? 'عرض الطلب البديل' : 'عرض الطلب الأصلي'}
            </PendingLink>
          </RecordCard>;
        })}</ul>
      </>}

      {request.days.length > 0 && <Disclosure summary={<>تفاصيل أيام الطلب</>} className="task-disclosure">

        <DayBreakdown days={request.days} />
      </Disclosure>}
    </Panel>

    {request.state === 'approved' && <Panel className="task-page" aria-labelledby="cancellation-action-title">
      {pendingEvent
        ? <>
          <div className="record-title-row"><h2 id="cancellation-action-title">طلب إلغاء معلّق</h2>
            <Badge className="is-pending">بانتظار قرار الموارد البشرية</Badge></div>
          <dl className="snapshot-grid">
            <div><dt>حالة طلب الإجازة</dt><dd>معتمد</dd></div>
            <div><dt>الخطوة التالية</dt><dd>إدارة الموارد البشرية</dd></div>
            <div><dt>وقت إرسال طلب الإلغاء</dt><dd><bdi>{formatInstant(pendingEvent.created_at)}</bdi></dd></div>
            <div><dt>أُرسل من طرف</dt><dd>{cancellationEventActor(pendingEvent, user.id)}</dd></div>
            <div><dt>سبب طلب الإلغاء</dt><dd>{pendingEvent.reason}</dd></div>
          </dl>
          <Message tone="info"  role="status">الموارد البشرية ستراجع طلب الإلغاء. عند قبوله تُلغى الإجازة ويُعاد أي
            رصيد خُصم لها. لا تحتاج إلى إرسال طلب آخر أثناء الانتظار.</Message>
        </>
        : historyFailed
          ? <>
            <h2 id="cancellation-action-title">طلب إلغاء الطلب المعتمد</h2>
            <Message tone="info"  role="status">تعذّر تحميل سجل طلبات الإلغاء لهذه الصفحة، لذلك لن يُعرض إرسال طلب
              إلغاء جديد حتى نتحقق من الحالة الحالية. يمكنك مراجعة التفاصيل المتاحة أعلاه؛ أعد المحاولة من قسم «سجل طلبات
              الإلغاء» أدناه.</Message>
          </>
          : !canRequestCancellation
            ? <>
                <h2 id="cancellation-action-title">إلغاء الإجازة</h2>
                <Message tone="info"  role="status">{accessUnavailable
                  ? 'تعذّر التحقق من صلاحية طلب الإلغاء الآن. أعد تحميل الصفحة للمحاولة من جديد.'
                  : 'حسابك يسمح بعرض الإجازة دون طلب إلغائها. راجع إدارة الموارد البشرية إذا أردت إلغاءها.'}</Message>
                {accessUnavailable && <PendingLink className="secondary-button"
                  href={`/tenant/${tenantId}/me/leave/${requestId}`}>إعادة المحاولة</PendingLink>}
              </>
            : <>
              <div className="record-title-row"><h2 id="cancellation-action-title">طلب إلغاء الطلب المعتمد</h2>
                <Badge className="is-active">معتمد — قابل للإلغاء</Badge></div>
              <p className="field-hint">اكتب سبب الإلغاء ليُراجعَه فريق الموارد البشرية. يظل الطلب معتمدًا حتى القرار.</p>
              {latest?.to_state === 'rejected' && <Message tone="info"  role="status">رُفض طلب إلغاء سابق لهذا
                الطلب. يمكنك إرسال طلب إلغاء جديد بسبب واضح.</Message>}
              <Disclosure summary={<>كتابة سبب الإلغاء وإرسال الطلب</>} className="task-disclosure">

                <RequestCancellationForm tenantId={tenantId} requestId={requestId}
                  expectedVersion={request.version} idempotencyKey={crypto.randomUUID()} />
              </Disclosure>
            </>}
    </Panel>}

    {request.state === 'submitted' && <Panel className="task-page" aria-labelledby="withdraw-title">
      <h2 id="withdraw-title">سحب الطلب</h2>
      <p className="field-hint">يمكنك سحب طلبك ما دام بانتظار قرار الموارد البشرية. بعد السحب تصبح حالته «مسحوبًا» نهائيًا،
        ويُحفظ سببك في سجل العملية مع هويتك ووقتها. لن يُخصم أي رصيد لأن الطلب لم يُعتمد بعد.</p>
      <Disclosure summary={<>كتابة سبب السحب</>} className="task-disclosure">

        <WithdrawRequestForm tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
          idempotencyKey={crypto.randomUUID()} />
      </Disclosure>
    </Panel>}

    <CancellationHistorySection tenantId={tenantId} requestId={requestId} view={history}
      requestedOffset={historyOffset.invalid ? 0 : historyOffset.value}
      offsetInvalid={historyOffset.invalid} currentUserId={user.id} />
    </div>
  </PageFrame>;
}

function requestStateNote(state: string, canRequestCancellation: boolean): string {
  if (state === 'submitted') return 'لم يصدر قرار الموارد البشرية بعد. إذا أردت سحب الطلب، راجع قسم «سحب الطلب» أدناه.';
  if (state === 'approved') return canRequestCancellation
    ? 'تم اعتماد الإجازة. يمكنك متابعة طلب إلغائها من القسم التالي.'
    : 'تم اعتماد الإجازة.';
  if (state === 'cancelled') return 'أُلغيت الإجازة وأُعيد أي رصيد خُصم لها. يمكنك مراجعة قرار الإلغاء أدناه.';
  if (state === 'rejected') return 'رفضت الموارد البشرية هذا الطلب، ولم يُخصم له رصيد.';
  if (state === 'withdrawn') return 'سحبت هذا الطلب بنفسك، ولم يُخصم به رصيد.';
  if (state === 'superseded') return 'استُبدل هذا الطلب ضمن تصحيح الإجازة. راجع الطلب البديل من سجل الاستبدال إذا كان متاحًا لحسابك.';
  if (state === 'draft') return 'هذا الطلب مسودة ولم يُرسل بعد.';
  return '';
}

function readRequest(data: Record<string, unknown>): RequestDetail | null {
  if (!isUuid(data.id) || typeof data.leave_type_name !== 'string' || typeof data.start_date !== 'string'
    || typeof data.end_date !== 'string' || !isDate(data.start_date) || !isDate(data.end_date)
    || data.start_date > data.end_date || typeof data.total_units !== 'number'
    || !Number.isFinite(data.total_units) || data.total_units <= 0
    || typeof data.is_half_day !== 'boolean' || !isRequestState(data.state)
    || typeof data.version !== 'number' || !Number.isInteger(data.version)
    || data.version < 1 || data.version > 2147483647
    || (data.request_source !== 'employee' && data.request_source !== 'hr')
    || !(data.submitted_at === null || isInstant(data.submitted_at))
    || !(data.reason === null || typeof data.reason === 'string')
    || !Array.isArray(data.days)) return null;
  const days: RequestDay[] = [];
  for (const day of data.days) {
    if (!isObject(day) || typeof day.date !== 'string' || typeof day.units !== 'number'
      || !isDate(day.date) || !Number.isFinite(day.units) || day.units < 0 || day.units > 1
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
    <Panel className="auth-card"><PageHeader  title={<>{title}</>} /><p className="intro">{detail}</p>
      {retry && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/me/leave/${requestId}`}>إعادة المحاولة</ButtonLink>}
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</ButtonLink>
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
    </Panel>
  </PageFrame>;
}

async function readResponse<T>(read: () => PromiseLike<T>): Promise<T | null> {
  try {
    return await read();
  } catch {
    return null;
  }
}
