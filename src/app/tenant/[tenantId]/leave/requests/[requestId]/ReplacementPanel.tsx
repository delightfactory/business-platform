import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PendingLink } from '../../pending-link';
import { detailHref, formatDays, formatInstant, isObject, isUuid, PAGE_SIZE, parsePage, readRequest, readRequestQueue,
  type RequestPayload } from '../../rules';
import { DayBreakdown } from './DayBreakdown';
import { ReviewIntentForm } from './ReviewIntentForm';

export async function ReplacementPanel({ tenantId, request, source, canReplace, replacementId, page }: {
  tenantId: string; request: RequestPayload; source: unknown; canReplace: boolean;
  replacementId?: string; page?: string;
}) {
  const path = detailHref(tenantId, request.id);
  const links = isObject(source) && Array.isArray(source.correction_links) ? source.correction_links : [];
  const history = links.filter((link): link is Record<string, unknown> => isObject(link)
    && isUuid(link.original_request_id) && isUuid(link.replacement_request_id)
    && typeof link.reason === 'string' && typeof link.created_at === 'string');
  const showChoice = request.state === 'approved' && canReplace;
  if (!showChoice && history.length === 0) return null;
  const pagination = parsePage(page);
  const supabase = showChoice ? await createSupabaseServerClient() : null;
  const result = supabase && !pagination.invalid
    ? await supabase.rpc('leave_hr_queue', { p_tenant: tenantId, p_limit: PAGE_SIZE,
      p_offset: (pagination.value - 1) * PAGE_SIZE }) : null;
  const queue = result && !result.error ? readRequestQueue(result.data) : null;
  const candidates = queue?.items.filter((item) => item.employeeCode === request.employeeCode
    && item.id !== request.id && item.state === 'submitted') ?? [];
  const selectedResult = supabase && replacementId && isUuid(replacementId) && replacementId !== request.id
    ? await supabase.rpc('leave_request_detail', { p_tenant: tenantId, p_request: replacementId }) : null;
  const selected = selectedResult && !selectedResult.error ? readRequest(selectedResult.data) : null;
  const validSelection = selected && selected.state === 'submitted' && isObject(source)
    && isObject(selectedResult?.data) && isUuid(source.employee_id) && isUuid(source.employment_id)
    && selectedResult.data.employee_id === source.employee_id
    && selectedResult.data.employment_id === source.employment_id
    && selectedResult.data.employer_entity_id === source.employer_entity_id ? selected : null;

  return <section className="work-card task-page" aria-labelledby="leave-replacement-title">
    <h2 id="leave-replacement-title">استبدال الإجازة المعتمدة</h2>
    {history.length > 0 && <ul className="record-list">{history.map((link, index) => {
      const original = link.original_request_id as string;
      const replacement = link.replacement_request_id as string;
      return <li className="record-card" key={index}>
        <p>{link.reason as string}</p>
        <p className="record-meta">وقت التصحيح: <bdi>{formatInstant(link.created_at as string)}</bdi></p>
        <PendingLink href={detailHref(tenantId, request.id === original ? replacement : original)}>
          {request.id === original ? 'عرض الطلب البديل' : 'عرض الطلب الأصلي'}
        </PendingLink>
      </li>;
    })}</ul>}
    {showChoice && <>
      <p className="field-hint">اختر طلبًا مرسلًا للموظف نفسه ثم راجع تفاصيله. سيُعاد الرصيد المستهلك للطلب الأصلي ويُعتمد البديل في عملية واحدة؛ يُحفظ الأصل وسجل التصحيح. إذا كانت أيامه معتمدة في الحضور، يلزم معالجة التعارض هناك أولًا.</p>
      {replacementId && !validSelection && <p className="form-message form-error" role="alert">الطلب البديل غير متاح أو ليس طلبًا مرسلًا لنفس علاقة العمل. اختر طلبًا آخر أو أعد تحميل الصفحة.</p>}
      {validSelection ? <>
        <h3>الطلب البديل: {validSelection.leaveTypeName}</h3>
        <p>{validSelection.employeeName} · <bdi>{validSelection.startDate}</bdi> إلى <bdi>{validSelection.endDate}</bdi> · {formatDays(validSelection.totalUnits)} يوم</p>
        <p>سبب الطلب: {validSelection.reason || 'غير مسجل'}</p>
        <dl className="snapshot-grid">
          <div><dt>أيام البديل بدون أجر</dt><dd>{formatDays(validSelection.days
            .filter((day) => day.eligible && day.payEffect === 'unpaid')
            .reduce((sum, day) => sum + day.units, 0))} يوم</dd></div>
          <div><dt>رصيد يستهلكه البديل عند التأكيد</dt><dd>{formatDays(validSelection.days
            .filter((day) => day.eligible && day.balanceMode === 'tracked')
            .reduce((sum, day) => sum + day.units, 0))} يوم</dd></div>
        </dl>
        <DayBreakdown days={validSelection.days} showMapping={validSelection.isHalfDay} />
        <PendingLink className="secondary-button" href={detailHref(tenantId, validSelection.id)}>عرض الطلب البديل وتحديث حسابه عند الحاجة</PendingLink>
        {request.approvedPreviewVersion !== null && <ReviewIntentForm intent="replacement"
          tenantId={tenantId} requestId={request.id} expectedVersion={request.version}
          reviewedPreviewVersion={request.approvedPreviewVersion} replacementId={validSelection.id}
          replacementVersion={validSelection.version} replacementPreviewVersion={validSelection.previewVersion}
          submitLabel="استبدال الإجازة واعتماد البديل" pendingLabel="جارٍ حفظ التصحيح…" backHref={path}
          hint="تأكيد التصحيح يعكس استهلاك الأصل ويستهلك رصيد البديل وفق نوعه. يبقى الطلبان كما هما إذا تعذرت العملية." />}
      </> : <>
        {!queue ? <p className="form-message form-error" role="alert">تعذر تحميل الطلبات المرسلة. <PendingLink href={path}>إعادة المحاولة</PendingLink></p>
          : candidates.length === 0 ? <p>لا يوجد طلب بديل مرسل لهذا الموظف في هذه الصفحة. يمكن للموظف إرسال طلب جديد من إجازاتي.</p>
            : <ul className="record-list">{candidates.map((item) => <li className="record-card" key={item.id}>
              <PendingLink href={`${path}?replacement=${item.id}`}>{item.leaveTypeName} · <bdi>{item.startDate}</bdi> إلى <bdi>{item.endDate}</bdi> · {formatDays(item.totalUnits)} يوم — مراجعة كبديل</PendingLink>
            </li>)}</ul>}
        <nav className="workspace-form-actions" aria-label="صفحات اختيار الطلب البديل">
          {pagination.value > 1 && <PendingLink href={`${path}?rpage=${pagination.value - 1}`}>السابق</PendingLink>}
          {queue?.hasMore && <PendingLink href={`${path}?rpage=${pagination.value + 1}`}>التالي</PendingLink>}
        </nav>
      </>}
    </>}
  </section>;
}
