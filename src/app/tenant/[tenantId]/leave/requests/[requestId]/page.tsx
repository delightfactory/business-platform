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

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; requestId: string }>;
type Query = Promise<{ state?: string | string[]; hpage?: string | string[] }>;

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
  const feedback = feedbackText(typeof query.state === 'string' ? query.state : undefined);

  const unmappedHalfDays = request.isHalfDay
    ? request.days.filter((day) => day.isHalfDay && day.eligible && day.mappingState !== 'mapped')
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
      <h2 id="leave-preview-title">المعاينة المحفوظة</h2>
      <p className="field-hint">
        هذا هو الإصدار <bdi>{request.previewVersion}</bdi> من حسابات الأيام. إن تغيّر قبل قرارك فلا يُنفذ إجراؤك،
        ويُطلب تحديث المعاينة أولًا. الطلب المعلق لا يحجز رصيدًا قبل الاعتماد.
      </p>
      <dl className="snapshot-grid">
        <div><dt>إصدار المعاينة</dt><dd>{request.previewVersion}</dd></div>
        <div><dt>عدد أيام المعاينة</dt><dd>{request.days.length}</dd></div>
        <div><dt>الرصيد المحجوز</dt><dd>{request.consumptionCount > 0
          ? `${formatDays(request.consumedUnits)} يوم في ${request.consumptionCount} قيد`
          : 'لم يُحجز رصيد بعد'}</dd></div>
        {request.approvedPreviewVersion !== null
          && <div><dt>المعاينة المعتمدة</dt><dd>{request.approvedPreviewVersion}</dd></div>}
      </dl>
      {request.isHalfDay && <p className={unmappedHalfDays.length > 0 ? 'form-message form-error' : 'form-message'}
        role={unmappedHalfDays.length > 0 ? 'alert' : 'status'}>
        {unmappedHalfDays.length > 0
          ? `${unmappedHalfDays.length} من أيام نصف يوم ليست مطابقة لدوام اليوم، فلا يمكن اعتماد الطلب. حدّث المعاينة أولًا؛ وإن بقيت غير مطابقة فراجع إعدادات دوام الموظف وسياسة الحضور لهذه الأيام. لا يُصحَّح سجل الوقت من هنا.`
          : 'مطابقة نصف يوم مكتملة لكل أيام نصف يوم في المعاينة.'}
      </p>}
      {unpaidDays.length > 0 && <p className="record-meta">
        منها {unpaidDays.length} يوم بدون أجر.
      </p>}
      {untrackedDays.length > 0 && <p className="record-meta">
        نوع الإجازة لا يخصم أيامه من رصيد الموظف؛ تُحتسب المدة فقط.
      </p>}
    </section>

    {canReview && <section className="work-card task-page" aria-labelledby="leave-review-title">
      <h2 id="leave-review-title">قرار المراجعة</h2>
      <p className="field-hint">
        التحديث وإجراء الاعتماد منفصلان: حدّث المعاينة أولًا إن تغيّرت حسابات الأيام، ثم ااعتماد بعد رؤية أيامها.
        السبب إلزامي في كل إجراء ويُحفظ في سجل العملية مع هويتك ووقتها.
      </p>
      {!access.newWorkEnabled && <p className="form-message" role="status">
        خدمة الموظفين أو الإجازات موقوفة حاليًا، لذا الاعتماد وتحديث المعاينة غير متاحين. يبقى رفض الطلب متاحًا.
      </p>}

      <div className={styles.formBlock}>
        <h3 className={styles.formTitle}>تحديث المعاينة</h3>
        {access.newWorkEnabled
          ? <ReviewIntentForm
            intent="refresh"
            tenantId={tenantId}
            requestId={requestId}
            expectedVersion={request.version}
            submitLabel="تحديث المعاينة"
            pendingLabel="جارٍ التحديث…"
            backHref={path}
            hint="يعيد حساب أيام الطلب بنفس جزء نصف يوم المحفوظ، ويغيّر إصدار المعاينة فقط دون تغيير حالة الطلب." />
          : <p className="form-message">تحديث المعاينة غير متاح ما دامت الخدمة موقوفة.</p>}
      </div>

      <div className={styles.divider} />
      <div className={styles.formBlock}>
        <h3 className={styles.formTitle}>اعتماد الطلب</h3>
        {access.newWorkEnabled
          ? <ReviewIntentForm
            intent="approve"
            tenantId={tenantId}
            requestId={requestId}
            expectedVersion={request.version}
            reviewedPreviewVersion={request.previewVersion}
            submitLabel="اعتماد الطلب"
            pendingLabel="جارٍ الاعتماد…"
            backHref={path}
            hint="يعتمد على الإصدار المعروض من المعاينة ويخصم أيام الطلب من رصيد الموظف فورًا." />
          : <p className="form-message">اعتماد الطلب غير متاح ما دامت الخدمة موقوفة.</p>}
      </div>

      <div className={styles.divider} />
      <div className={styles.formBlock}>
        <h3 className={styles.formTitle}>رفض الطلب</h3>
        <ReviewIntentForm
          intent="reject"
          tenantId={tenantId}
          requestId={requestId}
          expectedVersion={request.version}
          submitLabel="رفض الطلب"
          pendingLabel="جارٍ الرفض…"
          buttonClass="danger-button"
          backHref={path}
          hint="يصبح الطلب مرفوضًا نهائيًا دون حجز أي رصيد، ويبقى محفوظًا في السجل بسببه." />
      </div>
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
              hint="يُلغي اعتماد الطلب ويُعكس حجز الرصيد. إن كانت أيامه ظهرت في سجل الحضور فسيبقى مطلوبًا مراجعته يدويًا." />
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

    {!historyFailed && <section className="workspace-records-panel" aria-labelledby="leave-history-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-history-title">سجل طلبات إلغاء الاعتماد</h2>
        <p>كل ما جرى على طلبات الإلغاء لهذا الطلب مع سببه ووقته. الحالة الحالية تعتمد على آخر حدثة مهما كان عدد الصفحات.</p>
      </div>
      {historyPage.invalid
        ? <p className="form-message form-error" role="alert">رقم صفحة السجل غير صالح.{' '}
          <PendingLink href={historyHref(tenantId, requestId, 1)}>العودة إلى الصفحة الأولى</PendingLink></p>
        : history && history.items.length === 0
          ? <div className="empty-state">
            <h2>لا توجد طلبات إلغاء لهذا الطلب</h2>
            <p>لم يُنشأ أي طلب إلغاء اعتماد لهذا الطلب حتى الآن.</p>
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
              <span>الصفحة {historyPage.value} · {history.items.length} حدثة</span>
              <span className={styles.paginationNav}>
                {historyPage.value > 1 && <PendingLink className="secondary-button"
                  href={historyHref(tenantId, requestId, historyPage.value - 1)}>السابق</PendingLink>}
                {history.hasMore && <PendingLink className="primary-button"
                  href={historyHref(tenantId, requestId, historyPage.value + 1)}>التالي</PendingLink>}
              </span>
            </nav>
          </> : null}
    </section>}
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
