import { Badge, ButtonLink, Disclosure, EmptyState, KeyValueStrip, Message, Panel, RecordCard } from '@/components/ui';
import { DecisionPanel } from '@/components/patterns/decision-panel/decision-panel';

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
import { leaveCorrectionHref, type LeaveCorrectionContext } from '@/lib/payroll/leave-correction-context';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; requestId: string }>;
type Query = Promise<{ state?: string | string[]; hpage?: string | string[]; rv?: string; pv?: string; replacement?: string; rpage?: string; payrollCorrection?: string }>;

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
  const correctionResult = await supabase.rpc('payroll_leave_correction_context', {
    p_tenant: tenantId, p_request: requestId,
  });
  const correctionContext = correctionResult.error ? null : correctionResult.data as LeaveCorrectionContext;

  return <PageFrame footer="الموارد البشرية">
    {feedback && <FeedbackToast key={crypto.randomUUID()} message={feedback} />}
    {correctionContext && correctionContext.outputs.length > 0 && <Panel className="work-card">
      <h2>تصحيح الرواتب المرتبط بهذا الطلب</h2>
      <p>اختر المخرج المتأثر لمراجعة مسؤولية التصحيح. تُستعاد مصادر الطلب واستبدالاته تلقائيًا، وتُراجع المبالغ قبل الاعتماد.</p>
      {correctionContext.outputs.map(output => <p key={output.id}>
        <PendingLink className="ui-button ui-button-solid ui-button-md" href={leaveCorrectionHref(tenantId, correctionContext, output.id)}>
          مراجعة التصحيح — <bdi>{output.starts_on}</bdi> إلى <bdi>{output.ends_on}</bdi>
        </PendingLink>
      </p>)}
    </Panel>}
    {query.payrollCorrection === 'required' && correctionResult.error && <Panel className="work-card">
      <p>{correctionResult.error.code === '42501'
        ? 'أرسل الطلب إلى مسؤول تصحيح الرواتب لمراجعة أثره المالي. لا تتيح صلاحية الإجازات وحدها فتح التصحيح.'
        : 'تعذر استعادة مسؤولية تصحيح الرواتب. أعد تحميل الطلب قبل متابعة التصحيح.'}</p>
    </Panel>}

    <Panel className="work-card task-page" aria-labelledby="leave-request-title">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/leave`}>العودة إلى قائمة المراجعة</PendingLink>
      <p className="eyebrow">مراجعة طلب إجازة</p>
      <div className="record-title-row">
        <h1 id="leave-request-title">{request.leaveTypeName}</h1>
        <Badge className={`entity-status ${stateClass(request.state)}`}>{stateLabel(request.state)}</Badge>
      </div>
      <p className="record-meta">{request.employeeName} · رقم الموظف: <bdi>{request.employeeCode}</bdi></p>
      <p className="record-meta">{request.submittedAt
        ? <>أُرسل في <bdi>{formatInstant(request.submittedAt)}</bdi> · </>
        : 'لم يُرسل بعد · '}{nextOwnerText(request.state, pending !== null)}</p>

      <KeyValueStrip items={[{label: 'الفترة', value: `${request.startDate} — ${request.endDate}`}, {label: 'المدة', value: `${formatDays(request.totalUnits)} يوم`}, {label: 'السبب', value: request.reason || 'غير مسجل'}]} /><Disclosure  summary={<>بيانات الطلب وسجل التوقيت</>}><dl className="snapshot-grid">
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
      </dl></Disclosure>

      {request.days.length > 0 && <Disclosure  summary={<>تفاصيل أيام الطلب · {request.days.length} يوم</>}>
        <DayBreakdown days={request.days} showMapping={request.isHalfDay} />
      </Disclosure>}
    </Panel>

    <Panel className="work-card task-page" aria-labelledby="leave-preview-title">
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
      <Disclosure  summary={<>تفاصيل حساب الأيام</>}><p className="record-meta">إصدار الحساب: {request.previewVersion} · عدد الأيام المعروضة: {request.days.length} · قيود الاستهلاك: {request.consumptionCount}{request.approvedPreviewVersion !== null ? ` · الإصدار المعتمد: ${request.approvedPreviewVersion}` : ''}</p></Disclosure>
      {request.isHalfDay && <Message tone={unmappedHalfDays.length > 0 ? 'bad' : 'info'}
        role={unmappedHalfDays.length > 0 ? 'alert' : 'status'}>
        {unmappedHalfDays.length > 0
          ? `${unmappedHalfDays.length} من أيام نصف يوم ليست مطابقة لدوام اليوم، فلا يمكن اعتماد الطلب. حدّث المعاينة أولًا؛ وإن بقيت غير مطابقة فراجع إعدادات دوام الموظف وسياسة الحضور لهذه الأيام. لا يُصحَّح سجل الوقت من هنا.`
          : request.days.some((day) => day.mappingState === 'leave_only')
            ? 'احتساب نصف يوم للإجازة فقط؛ لا توجد مطابقة مع دوام الحضور في هذه المعاينة.'
            : 'مطابقة نصف يوم مكتملة لكل أيام نصف يوم في المعاينة.'}
      </Message>}
      {unmappedHalfDays.length > 0 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
        href={`/tenant/${tenantId}/people/work-policies?returnToRequest=${requestId}`}>مراجعة إعداد نصف اليوم في سياسة العمل</PendingLink>}
      {unpaidDays.length > 0 && <p className="record-meta">
        منها {unpaidDays.length} يوم بدون أجر.
      </p>}
      {untrackedDays.length > 0 && <p className="record-meta">
        نوع الإجازة لا يخصم أيامه من رصيد الموظف؛ تُحتسب المدة فقط.
      </p>}
    </Panel>

    {canReview && <DecisionPanel id="leave-review-title" person={request.employeeName} kind="طلب إجازة" title="قرار طلب الإجازة" values={[{label: 'نوع الإجازة', value: request.leaveTypeName}, {label: 'المدة', value: `${formatDays(request.totalUnits)} يوم`}]} facts={[{text: 'الاعتماد يستهلك الرصيد للأنواع التي تتطلب رصيدًا فقط؛ الرفض لا يستهلك رصيدًا.'}]}>
      <p className="field-hint">راجع أثر الإجازة ثم اختر القرار واكتب سببه. تحديث الحساب مطلوب فقط إذا تغيّرت بياناته.</p>
      {!access.newWorkEnabled && <Message tone="info"  role="status">الاعتماد والتحديث غير متاحين حاليًا؛ يمكنك رفض الطلب.</Message>}
      <ReviewIntentForm decision canApprove={access.newWorkEnabled} intent={access.newWorkEnabled ? "approve" : "reject"}
        tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
        reviewedPreviewVersion={request.previewVersion} submitLabel="اعتماد الطلب" pendingLabel="جارٍ حفظ القرار…"
        backHref={path} hint="يُحفظ القرار وسببه. الاعتماد يستهلك الرصيد للأنواع التي تتطلب رصيدًا فقط؛ الرفض لا يستهلك رصيدًا." />
      {access.newWorkEnabled && <Disclosure  summary={<>تحديث حساب أيام الإجازة</>}>
        <ReviewIntentForm intent="refresh" tenantId={tenantId} requestId={requestId} expectedVersion={request.version}
          submitLabel="تحديث الحساب" pendingLabel="جارٍ التحديث…" backHref={path}
          hint="يعيد حساب أيام الطلب دون اتخاذ قرار بالموافقة أو الرفض." />
      </Disclosure>}
    </DecisionPanel>}
    {(access.canApprove || access.canManage) && <Panel className="work-card task-page" aria-labelledby="leave-cancellation-title">
      <h2 id="leave-cancellation-title">إلغاء الاعتماد</h2>
      {historyFailed
        ? <div role="alert"><EmptyState title={<>تعذر تحميل سجل طلبات الإلغاء</>} description={<>لم يتغير الطلب. أعد المحاولة للتحقق من وجود طلب إلغاء معلق قبل أي إجراء.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={path}>إعادة المحاولة</PendingLink></>} /></div>
        : pending && access.canApprove ? <>
          <p className="field-hint">
            يوجد طلب إلغاء معلق. الطلب المعتمد يبقى ساريًا ولا يُعاد الرصيد قبل قبول الطلب؛ عند القبول
            تصبح حالته «ملغى الاعتماد».
          </p>
          <KeyValueStrip items={[{ label: <>من طلب الإلغاء</>, value: <>{requesterKindLabel(pending.requesterKind)}</> }, { label: <>وقت الطلب</>, value: <><bdi>{formatInstant(pending.requestedAt)}</bdi></> }, { label: <>سبب طلب الإلغاء</>, value: <>{pending.reason || 'غير مسجل'}</> }, { label: <>حالة الطلب</>, value: <>بانتظار القرار</> }]} />
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
          ? <Message tone="info"  role="status">
            يوجد طلب إلغاء معلق بانتظار قرار فريق الاعتماد. لا يملك حسابك صلاحية اتخاذ هذا القرار.
          </Message>
          : canManageCancellation ? <>
            <p className="field-hint">
              الاعتماد ساري ولا يتراجع عنه مباشرة. أنشئ طلب إلغاء يُحال إلى فريق الاعتماد؛
              لا يتغير الطلب ولا يُعاد الرصيد قبل قبول الطلب.
            </p>
            <Disclosure  summary={<>طلب إلغاء اعتماد هذا الطلب</>}>
              <ReviewIntentForm
                intent="cancellation-request"
                tenantId={tenantId}
                requestId={requestId}
                expectedVersion={request.version}
                submitLabel="إرسال طلب الإلغاء"
                pendingLabel="جارٍ الإرسال…"
                buttonClass="danger-button"
                hint="يبقى الطلب معتمدًا ويظهر بانتظار قرار الموارد البشرية حتى يُقبل أو يُرفض طلبه." />
            </Disclosure>
          </>
          : <Message tone="info"  role="status">
            {request.state === 'approved'
              ? 'لا يوجد طلب إلغاء معلق لهذا الطلب، وتبقى حالته معتمدة.'
              : 'إلغاء الاعتماد متاح فقط للطلبات المعتمدة.'}
          </Message>}
    </Panel>}

    <ReplacementPanel tenantId={tenantId} request={request} source={detailResult.data}
      canReplace={access.canApprove && access.newWorkEnabled && !historyFailed && pending === null}
      replacementId={query.replacement} page={query.rpage} />

    <Panel  aria-labelledby="leave-history-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-history-title">سجل طلبات إلغاء الاعتماد</h2>
        <p>سجل طلبات الإلغاء بأسبابها وأوقاتها. الحالة الحالية تعتمد على أحدث قرار مهما كان عدد الصفحات.</p>
      </div>
      {historyPage.invalid
        ? <Message tone="bad"  role="alert">رقم صفحة السجل غير صالح.{' '}
          <PendingLink href={historyHref(tenantId, requestId, 1)}>العودة إلى الصفحة الأولى</PendingLink></Message>
        : historyFailed ? <div role="alert"><EmptyState title={<>تعذر تحميل سجل الإلغاء</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={historyHref(tenantId, requestId, 1)}>إعادة المحاولة</PendingLink></>} /></div>
        : history && history.items.length === 0
          ? <div ><EmptyState title={<>{historyPage.value > 1 ? 'لا توجد أحداث في هذه الصفحة' : 'لا توجد طلبات إلغاء لهذا الطلب'}</>} description={<>{historyPage.value > 1 ? 'عُد إلى صفحة سابقة لعرض سجل الإلغاء.' : 'لم يُنشأ أي طلب إلغاء اعتماد لهذا الطلب حتى الآن.'}</>} action={<>{historyPage.value > 1 && <div className="workspace-form-actions">
              <PendingLink className="ui-button ui-button-ghost ui-button-md" href={historyHref(tenantId, requestId, historyPage.value - 1)}>السابق</PendingLink>
              <PendingLink className="ui-button ui-button-ghost ui-button-md" href={historyHref(tenantId, requestId, 1)}>الصفحة الأولى</PendingLink>
            </div>}</>} /></div>
          : history ? <>
            <ul className="record-list">{history.items.map((event) => <RecordCard  key={event.id}>
              <div className="record-main">
                <div className="record-title-row">
                  <h3>{eventKeyLabel(event.eventKey)}</h3>
                  <Badge className={`entity-status ${cancellationStateClass(event.toState)}`}>
                    {cancellationStateLabel(event.toState)}</Badge>
                </div>
                <p className="record-meta">وقت التنفيذ: <bdi>{formatInstant(event.createdAt)}</bdi></p>
                <p className="record-meta">السبب: {event.reason || 'غير مسجل'}</p>
                {event.timeReconciliationRequired && <Message tone="bad" >
                  أيام هذا الطلب كانت معتمدة وقت التنفيذ، لذا يلزم مراجعة سجل الحضور لها يدويًا؛ لن يتغير سجل الوقت تلقائيًا.
                </Message>}
              </div>
            </RecordCard>)}</ul>
            <nav className={styles.pagination} aria-label="صفحات سجل طلبات الإلغاء">
              <span>الصفحة {historyPage.value} · {history.items.length} حدث</span>
              <span className={styles.paginationNav}>
                {historyPage.value > 1 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                  href={historyHref(tenantId, requestId, historyPage.value - 1)}>السابق</PendingLink>}
                {history.hasMore && <PendingLink className="ui-button ui-button-solid ui-button-md"
                  href={historyHref(tenantId, requestId, historyPage.value + 1)}>التالي</PendingLink>}
              </span>
            </nav>
          </> : null}
    </Panel>
  </PageFrame>;
}

function Status({ tenantId, title, detail, retryPath }: {
  tenantId: string;
  title: string;
  detail: string;
  retryPath?: string;
}) {
  return <PageFrame footer="الموارد البشرية">
    <Panel ><h1>{title}</h1><p className="intro">{detail}</p>
      {retryPath && <ButtonLink variant="ghost"  href={retryPath}>إعادة المحاولة</ButtonLink>}
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/leave`}>العودة إلى قائمة المراجعة</ButtonLink>
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
    </Panel>
  </PageFrame>;
}
