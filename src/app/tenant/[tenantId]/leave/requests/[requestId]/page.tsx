import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PendingLink } from '../../pending-link';
import {
  PAGE_SIZE,
  cancellationStateClass,
  cancellationStateLabel,
  detailHref,
  eventKeyLabel,
  feedbackText,
  formatDays,
  formatInstant,
  halfDayPartLabel,
  historyHref,
  isUuid,
  nextOwnerText,
  parsePage,
  readAccess,
  readCancellationHistory,
  readPendingCancellation,
  readRequest,
  requesterKindLabel,
  requestSourceLabel,
  stateClass,
  stateLabel,
} from '../../rules';
import styles from '../../review.module.css';
import { DayBreakdown } from './DayBreakdown';
import { ReviewIntentForm } from './ReviewIntentForm';
import { ReplacementPanel } from './ReplacementPanel';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; requestId: string }>;
type Query = Promise<{ state?: string | string[]; hpage?: string | string[]; rv?: string; pv?: string; replacement?: string; rpage?: string }>;

export default async function LeaveRequestReviewPage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId, requestId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(requestId)) notFound();
  const path = detailHref(tenantId, requestId);
  const historyPage = parsePage(query.hpage);

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return <Status tenantId={tenantId} title="الاتصال غير متاح"
      detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." retryPath={path} />;
  }
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(path)}`);

  const accessResult = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  const access = accessResult.error ? null : readAccess(accessResult.data);
  if (!access) {
    const forbidden = accessResult.error?.code === '42501';
    return <Status tenantId={tenantId}
      title={forbidden ? 'طلب الإجازة غير متاح لهذا الحساب' : 'تعذر تحميل الطلب الآن'}
      detail={forbidden
        ? 'لا يملك حسابك أي صلاحية لعرض طلبات الإجازة في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء التحقق من صلاحيتك أو تحميل الطلب. أعد المحاولة.'}
      retryPath={forbidden ? undefined : path} />;
  }
  if (!access.canView) {
    return <Status tenantId={tenantId} title="عرض طلب الإجازة غير متاح لهذا الحساب"
      detail="تحتاج إلى صلاحية عرض أو اعتماد أو إدارة الإجازات لدى الشركة. راجع إدارة الموارد البشرية." />;
  }

  const detailResult = await supabase.rpc('leave_request_detail', { p_tenant: tenantId, p_request: requestId });
  const request = detailResult.error ? null : readRequest(detailResult.data);
  if (!request) {
    const unavailable = Boolean(detailResult.error && detailResult.error.code === 'P0002');
    const forbidden = Boolean(detailResult.error && detailResult.error.code === '42501');
    return <Status tenantId={tenantId} retryPath={unavailable || forbidden ? undefined : path}
      title={unavailable ? 'الطلب غير متاح' : forbidden ? 'عرض الطلب غير متاح' : 'تعذر تحميل الطلب الآن'}
      detail={unavailable ? 'لم نعثر على هذا الطلب، أو أنه لم يعد متاحًا للعرض. عُد إلى قائمة المراجعة وحدّثها.'
        : forbidden ? 'ليست لديك صلاحية عرض هذا الطلب. راجع إدارة الموارد البشرية.'
          : 'حدث خطأ أثناء تحميل تفاصيل الطلب. أعد المحاولة.'} />;
  }

  const historyResult = historyPage.invalid ? null
    : await supabase.rpc('leave_cancellation_history', {
      p_tenant: tenantId,
      p_request: requestId,
      p_limit: PAGE_SIZE,
      p_offset: (historyPage.value - 1) * PAGE_SIZE,
    });
  const history = historyResult && !historyResult.error ? readCancellationHistory(historyResult.data) : null;
  const historyFailed = history === null;
  const pending = readPendingCancellation(history);
  const feedback = query.state === 'refreshed' && request.state === 'submitted'
    && query.rv === String(request.version) && query.pv === String(request.previewVersion)
    ? 'تم تحديث معاينة الطلب. راجع أيامها الجديدة ثم اتخذ قرارك.'
    : feedbackText(typeof query.state === 'string' ? query.state : undefined,
      request.state, history?.latest?.toState);

  const unmappedHalfDays = request.isHalfDay
    ? request.days.filter((day) => day.isHalfDay && day.eligible && day.mappingState !== 'mapped'
      && day.mappingState !== 'leave_only')
    : [];
  const unpaidDays = request.days.filter((day) => day.eligible && day.payEffect === 'unpaid');
  const untrackedDays = request.days.filter((day) => day.eligible && day.balanceMode === 'untracked');
  const canReview = request.state === 'submitted' && access.canApprove;
  const canManageCancellation = request.state === 'approved' && access.canManage;

  return <PageFrame footer="الموارد البشرية">
    {feedback && <FeedbackToast key={crypto.randomUUID()} message={feedback} />}

    <section className="work-card task-page" aria-labelledby="leave-request-title">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/leave`}>العودة إلى قائمة المراجعة</PendingLink>
      <p className="eyebrow">مراجعة طلب إجازة</p>
      <div className="record-title-row">
        <h1 id="leave-request-title">{request.leaveTypeName}</h1>
        <span className={`entity-status ${stateClass(request.state)}`}>{stateLabel(request.state)}</span>
      </div>
      <p className="record-meta">{request.employeeName} · رقم الموظف: <bdi>{request.employeeCode}</bdi></p>
      <p className="record-meta">{request.submittedAt
        ? <>أُرسل في <bdi>{formatInstant(request.submittedAt)}</bdi> · </>
        : 'لم يُرسل بعد · '}{nextOwnerText(request.state, pending !== null)}</p>

      <dl className="snapshot-grid">
        <div><dt>الحالة</dt><dd>{stateLabel(request.state)}</dd></div>
        <div><dt>المسؤول الحالي</dt><dd>{nextOwnerText(request.state, pending !== null)}</dd></div>
        <div><dt>الموظف</dt><dd>{request.employeeName}</dd></div>
        <div><dt>رقم الموظف</dt><dd><bdi>{request.employeeCode}</bdi></dd></div>
        <div><dt>نوع الإجازة</dt><dd>{request.leaveTypeName}</dd></div>
        <div><dt>تاريخ البداية</dt><dd><bdi>{request.startDate}</bdi></dd></div>
        <div><dt>تاريخ النهاية</dt><dd><bdi>{request.endDate}</bdi></dd></div>
        <div><dt>إجمالي أيام الإجازة</dt><dd>{formatDays(request.totalUnits)} يوم</dd></div>
        <div><dt>مدة الاحتساب</dt><dd>{request.isHalfDay
          ? `نصف يوم · ${halfDayPartLabel(request.halfDayPart)}`
          : 'يوم كامل'}</dd></div>
        <div><dt>طريقة التسجيل</dt><dd>{requestSourceLabel(request.requestSource)}</dd></div>
        <div><dt>السبب</dt><dd>{request.reason || 'غير مسجل'}</dd></div>
        {request.submittedAt && <div><dt>وقت الإرسال</dt><dd><bdi>{formatInstant(request.submittedAt)}</bdi></dd></div>}
        {request.approvedAt && <div><dt>وقت الاعتماد</dt><dd><bdi>{formatInstant(request.approvedAt)}</bdi></dd></div>}
        {request.cancelledAt && <div><dt>وقت إلغاء الاعتماد</dt><dd><bdi>{formatInstant(request.cancelledAt)}</bdi></dd></div>}
      </dl>

      {request.days.length > 0 && <details className="task-disclosure">
        <summary className="secondary-button">تفاصيل أيام الطلب · {request.days.length} يوم</summary>
        <DayBreakdown days={request.days} showMapping={request.isHalfDay} />
      </details>}
    </section>

    <section className="work-card task-page" aria-labelledby="leave-preview-title">
      <h2 id="leave-preview-title">أثر الإجازة</h2>
      <p className="field-hint">إذا تغيّرت حسابات الأيام قبل القرار، ستُطلب مراجعتها مجددًا. الطلب المعلق لا يحجز رصيدًا قبل الاعتماد.</p>
      <dl className="snapshot-grid">
        <div><dt>أيام الإجازة المحتسبة</dt><dd>{formatDays(request.totalUnits)} يوم</dd></div>
        <div><dt>أثر الأجر</dt><dd>{unpaidDays.length > 0 ? `${unpaidDays.length} يوم بدون أجر` : 'لا توجد أيام بدون أجر في هذا الطلب'}</dd></div>
        <div><dt>استهلاك الرصيد عند الاعتماد</dt><dd>{request.state === 'cancelled' || request.state === 'superseded'
          ? 'لا يوجد استهلاك ساري؛ عُكس الاستهلاك السابق'
          : request.consumptionCount > 0
          ? `${formatDays(request.consumedUnits)} يوم`
          : request.state === 'submitted' ? `${formatDays(request.days.filter((day) => day.eligible && day.balanceMode === 'tracked').reduce((sum, day) => sum + day.units, 0))} يوم عند الاعتماد؛ لم يُخصم بعد` : 'لم يُستهلك رصيد لهذا الطلب'}</dd></div>
        {request.state === 'cancelled' && <div><dt>أثر الإلغاء</dt><dd>أُعيد أي رصيد استُهلك عند الاعتماد</dd></div>}
        {request.state === 'superseded' && <div><dt>أثر التصحيح</dt><dd>عُكس الاستهلاك السابق وحُسب الطلب البديل</dd></div>}

      </dl>
      <details className="task-disclosure"><summary>تفاصيل حساب الأيام</summary><p className="record-meta">إصدار الحساب: {request.previewVersion} · عدد الأيام المعروضة: {request.days.length} · قيود الاستهلاك: {request.consumptionCount}{request.approvedPreviewVersion !== null ? ` · الإصدار المعتمد: ${request.approvedPreviewVersion}` : ''}</p></details>
      {request.isHalfDay && <p className={unmappedHalfDays.length > 0 ? 'form-message form-error' : 'form-message'}
        role={unmappedHalfDays.length > 0 ? 'alert' : 'status'}>
        {unmappedHalfDays.length > 0
          ? `${unmappedHalfDays.length} من أيام نصف يوم ليست مطابقة لدوام اليوم، فلا يمكن اعتماد الطلب. حدّث المعاينة أولًا؛ وإن بقيت غير مطابقة فراجع إعدادات دوام الموظف وسياسة الحضور لهذه الأيام. لا يُصحَّح سجل الوقت من هنا.`
          : request.days.some((day) => day.mappingState === 'leave_only')
            ? 'احتساب نصف يوم للإجازة فقط؛ لا توجد مطابقة مع دوام الحضور في هذه المعاينة.'
            : 'مطابقة نصف يوم مكتملة لكل أيام نصف يوم في المعاينة.'}
      </p>}
      {unmappedHalfDays.length > 0 && <PendingLink className="secondary-button"
        href={`/tenant/${tenantId}/people/work-policies?returnToRequest=${requestId}`}>مراجعة إعداد نصف اليوم في سياسة العمل</PendingLink>}
      {unpaidDays.length > 0 && <p className="record-meta">
        منها {unpaidDays.length} يوم بدون أجر.
      </p>}
      {untrackedDays.length > 0 && <p className="record-meta">
        نوع الإجازة لا يخصم أيامه من رصيد الموظف؛ تُحتسب المدة فقط.
      </p>}
    </section>

    {canReview && <section className="work-card task-page" aria-labelledby="leave-review-title">
      <h2 id="leave-review-title">قرار الطلب</h2>
      <p className="field-hint">راجع أثر الإجازة ثم اختر القرار واكتب سببه. تحديث الحساب مطلوب فقط إذا تغيّرت بياناته.</p>
      {!access.newWorkEnabled && <p className="form-message" role="status">الاعتماد والتحديث غير متاحين حاليًا؛ يمكنك رفض الطلب.</p>}
      <ReviewIntentForm decision canApprove={access.newWorkEnabled} intent={access.newWorkEnabled ? "approve" : "reject"}
        tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
        reviewedPreviewVersion={request.previewVersion} submitLabel="اعتماد الطلب" pendingLabel="جارٍ حفظ القرار…"
        backHref={path} hint="يُحفظ القرار وسببه. الاعتماد يستهلك الرصيد للأنواع التي تتطلب رصيدًا فقط؛ الرفض لا يستهلك رصيدًا." />
      {access.newWorkEnabled && <details className="task-disclosure"><summary className="secondary-button">تحديث حساب أيام الإجازة</summary>
        <ReviewIntentForm intent="refresh" tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
          submitLabel="تحديث الحساب" pendingLabel="جارٍ التحديث…" backHref={path}
          hint="يعيد حساب أيام الطلب دون اتخاذ قرار بالموافقة أو الرفض." />
      </details>}
    </section>}
    {(access.canApprove || access.canManage) && <section className="work-card task-page" aria-labelledby="leave-cancellation-title">
      <h2 id="leave-cancellation-title">إلغاء الاعتماد</h2>
      {historyFailed
        ? <div className="empty-state" role="alert">
          <h2>تعذر تحميل سجل طلبات الإلغاء</h2>
          <p>لم يتغير الطلب. أعد المحاولة للتحقق من وجود طلب إلغاء معلق قبل أي إجراء.</p>
          <PendingLink className="secondary-button" href={path}>إعادة المحاولة</PendingLink>
        </div>
        : pending && access.canApprove ? <>
          <p className="field-hint">
            يوجد طلب إلغاء معلق. الطلب المعتمد يبقى ساريًا ولا يُعاد الرصيد قبل قبول الطلب؛ عند القبول
            تصبح حالته «ملغى الاعتماد».
          </p>
          <dl className="snapshot-grid">
            <div><dt>من طلب الإلغاء</dt><dd>{requesterKindLabel(pending.requesterKind)}</dd></div>
            <div><dt>وقت الطلب</dt><dd><bdi>{formatInstant(pending.requestedAt)}</bdi></dd></div>
            <div><dt>سبب طلب الإلغاء</dt><dd>{pending.reason || 'غير مسجل'}</dd></div>
            <div><dt>حالة الطلب</dt><dd>بانتظار القرار</dd></div>
          </dl>
          <div className={styles.formBlock}>
            <h3 className={styles.formTitle}>قبول طلب الإلغاء</h3>
            <ReviewIntentForm
              intent="cancellation-accept"
              tenantId={tenantId}
              requestId={requestId}
              expectedVersion={request.version}
              cancellationId={pending.id}
              cancellationVersion={pending.version}
              submitLabel="قبول الإلغاء"
              pendingLabel="جارٍ القبول…"
              buttonClass="danger-button"
              backHref={path}
              hint="يُلغي اعتماد الطلب ويُعاد أي رصيد استُهلك عند الاعتماد. إن كانت أيامه ظهرت في سجل الحضور فسيبقى مطلوبًا مراجعته يدويًا." />
          </div>
          <div className={styles.divider} />
          <div className={styles.formBlock}>
            <h3 className={styles.formTitle}>رفض طلب الإلغاء</h3>
            <ReviewIntentForm
              intent="cancellation-reject"
              tenantId={tenantId}
              requestId={requestId}
              expectedVersion={request.version}
              cancellationId={pending.id}
              cancellationVersion={pending.version}
              submitLabel="رفض الإلغاء"
              pendingLabel="جارٍ الرفض…"
              backHref={path}
              hint="يبقى الطلب معتمدًا كما هو، ويُحفظ رفضك بسببه في سجل العملية." />
          </div>
        </>
        : pending
          ? <p className="form-message" role="status">
            يوجد طلب إلغاء معلق بانتظار قرار فريق الاعتماد. لا يملك حسابك صلاحية اتخاذ هذا القرار.
          </p>
          : canManageCancellation ? <>
            <p className="field-hint">
              الاعتماد ساري ولا يتراجع عنه مباشرة. أنشئ طلب إلغاء يُحال إلى فريق الاعتماد؛
              لا يتغير الطلب ولا يُعاد الرصيد قبل قبول الطلب.
            </p>
            <details className="task-disclosure">
              <summary className="secondary-button">طلب إلغاء اعتماد هذا الطلب</summary>
              <ReviewIntentForm
                intent="cancellation-request"
                tenantId={tenantId}
                requestId={requestId}
                expectedVersion={request.version}
                submitLabel="إرسال طلب الإلغاء"
                pendingLabel="جارٍ الإرسال…"
                buttonClass="danger-button"
                hint="يبقى الطلب معتمدًا ويظهر بانتظار قرار الموارد البشرية حتى يُقبل أو يُرفض طلبه." />
            </details>
          </>
          : <p className="form-message" role="status">
            {request.state === 'approved'
              ? 'لا يوجد طلب إلغاء معلق لهذا الطلب، وتبقى حالته معتمدة.'
              : 'إلغاء الاعتماد متاح فقط للطلبات المعتمدة.'}
          </p>}
    </section>}

    <ReplacementPanel tenantId={tenantId} request={request} source={detailResult.data}
      canReplace={access.canApprove && access.newWorkEnabled && !historyFailed && pending === null}
      replacementId={query.replacement} page={query.rpage} />

    <section className="workspace-records-panel" aria-labelledby="leave-history-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-history-title">سجل طلبات إلغاء الاعتماد</h2>
        <p>سجل طلبات الإلغاء بأسبابها وأوقاتها. الحالة الحالية تعتمد على أحدث قرار مهما كان عدد الصفحات.</p>
      </div>
      {historyPage.invalid
        ? <p className="form-message form-error" role="alert">رقم صفحة السجل غير صالح.{' '}
          <PendingLink href={historyHref(tenantId, requestId, 1)}>العودة إلى الصفحة الأولى</PendingLink></p>
        : historyFailed ? <div className="empty-state" role="alert">
          <h2>تعذر تحميل سجل الإلغاء</h2>
          <PendingLink className="secondary-button" href={historyHref(tenantId, requestId, 1)}>إعادة المحاولة</PendingLink>
        </div>
        : history && history.items.length === 0
          ? <div className="empty-state">
            <h2>{historyPage.value > 1 ? 'لا توجد أحداث في هذه الصفحة' : 'لا توجد طلبات إلغاء لهذا الطلب'}</h2>
            <p>{historyPage.value > 1 ? 'عُد إلى صفحة سابقة لعرض سجل الإلغاء.' : 'لم يُنشأ أي طلب إلغاء اعتماد لهذا الطلب حتى الآن.'}</p>
            {historyPage.value > 1 && <div className="workspace-form-actions">
              <PendingLink className="secondary-button" href={historyHref(tenantId, requestId, historyPage.value - 1)}>السابق</PendingLink>
              <PendingLink className="secondary-button" href={historyHref(tenantId, requestId, 1)}>الصفحة الأولى</PendingLink>
            </div>}
          </div>
          : history ? <>
            <ul className="record-list">{history.items.map((event) => <li className="record-card" key={event.id}>
              <div className="record-main">
                <div className="record-title-row">
                  <h3>{eventKeyLabel(event.eventKey)}</h3>
                  <span className={`entity-status ${cancellationStateClass(event.toState)}`}>
                    {cancellationStateLabel(event.toState)}</span>
                </div>
                <p className="record-meta">وقت التنفيذ: <bdi>{formatInstant(event.createdAt)}</bdi></p>
                <p className="record-meta">السبب: {event.reason || 'غير مسجل'}</p>
                {event.timeReconciliationRequired && <p className="form-message form-error">
                  أيام هذا الطلب كانت معتمدة وقت التنفيذ، لذا يلزم مراجعة سجل الحضور لها يدويًا؛ لن يتغير سجل الوقت تلقائيًا.
                </p>}
              </div>
            </li>)}</ul>
            <nav className={styles.pagination} aria-label="صفحات سجل طلبات الإلغاء">
              <span>الصفحة {historyPage.value} · {history.items.length} حدث</span>
              <span className={styles.paginationNav}>
                {historyPage.value > 1 && <PendingLink className="secondary-button"
                  href={historyHref(tenantId, requestId, historyPage.value - 1)}>السابق</PendingLink>}
                {history.hasMore && <PendingLink className="primary-button"
                  href={historyHref(tenantId, requestId, historyPage.value + 1)}>التالي</PendingLink>}
              </span>
            </nav>
          </> : null}
    </section>
  </PageFrame>;
}

function Status({ tenantId, title, detail, retryPath }: {
  tenantId: string;
  title: string;
  detail: string;
  retryPath?: string;
}) {
  return <PageFrame footer="الموارد البشرية">
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      {retryPath && <Link className="secondary-button" href={retryPath}>إعادة المحاولة</Link>}
      <Link className="secondary-button" href={`/tenant/${tenantId}/leave`}>العودة إلى قائمة المراجعة</Link>
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
    </section>
  </PageFrame>;
}
