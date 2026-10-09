import { Badge, Button, Card, EmptyState, Field, Input, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { PendingLink } from '../pending-link';
import {
  detailHref,
  formatDays,
  halfDayPartLabel,
  isUuid,
  readAccess,
  readRequest,
  stateClass,
  stateLabel,
} from '../rules';
import { readConfiguration } from '../settings/rules';
import { RecordLeaveForm } from './RecordLeaveForm';
import {
  MAX_QUERY_LENGTH,
  MIN_QUERY_LENGTH,
  PAGE_SIZE,
  availableTypes,
  dayCount,
  parseRecordQuery,
  readHalfDayContext,
  readOptionsPage,
  recordHref,
  type EmployeeOption,
  type HalfDayContext,
  type LeaveTypeOption,
  type OptionsPage,
} from './rules';
import styles from '../review.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{
  start?: string | string[];
  end?: string | string[];
  q?: string | string[];
  page?: string | string[];
  employee?: string | string[];
  employment?: string | string[];
  state?: string | string[];
  request?: string | string[];
}>;

type ConfigProblem = { title: string; detail: string; retry: boolean };

export default async function RecordLeavePage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId } = await params;
  const raw = await searchParams;
  if (!isUuid(tenantId)) notFound();
  const homePath = recordHref(tenantId, {});
  const query = parseRecordQuery(raw);
  const stateParam = typeof raw.state === 'string' ? raw.state : '';
  const submittedId = typeof raw.request === 'string' && isUuid(raw.request) ? raw.request : '';

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return <Status tenantId={tenantId} title="الاتصال غير متاح"
      detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." retryPath={homePath} />;
  }
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(homePath)}`);

  const accessResult = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  const access = accessResult.error ? null : readAccess(accessResult.data);
  if (!access) {
    const forbidden = accessResult.error?.code === '42501';
    return <Status tenantId={tenantId}
      title={forbidden ? 'تسجيل إجازات الموظفين غير متاح لهذا الحساب' : 'تعذر فتح صفحة التسجيل الآن'}
      detail={forbidden
        ? 'لا يملك حسابك أي صلاحية لخدمة الإجازات في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء التحقق من صلاحيتك. أعد المحاولة.'}
      retryPath={forbidden ? undefined : homePath} />;
  }
  if (!access.canManage) {
    return <Status tenantId={tenantId} title="تسجيل إجازات الموظفين غير متاح لهذا الحساب"
      detail="تحتاج إلى صلاحية إدارة الإجازات لدى الشركة لتسجيل طلبات الموظفين. راجع إدارة الموارد البشرية."
      showQueue={access.canView} />;
  }
  if (!access.newWorkEnabled) {
    return <Status tenantId={tenantId} title="تسجيل طلبات الإجازة غير متاح حاليًا"
      detail="خدمة إدارة الموظفين أو الإجازات موقوفة، فلا يمكن تسجيل طلبات جديدة. يمكنك مراجعة الطلبات المقدمة واتخاذ قراراتها."
      showQueue />;
  }

  if (stateParam === 'submitted' && submittedId) {
    const detailResult = await supabase.rpc('leave_request_detail', { p_tenant: tenantId, p_request: submittedId });
    const request = detailResult.error ? null : readRequest(detailResult.data);
    return <SubmittedView tenantId={tenantId} requestId={submittedId} request={request}
      start={query.start} end={query.end} q={query.q} />;
  }

  const searchReady = query.datesProvided && !query.dateError && !query.queryError
    && query.q.length >= MIN_QUERY_LENGTH;
  const runSearch = searchReady && !query.pageInvalid;

  let options: OptionsPage | null = null;
  let optionsFailed = false;
  if (runSearch) {
    const optionsResult = await supabase.rpc('leave_employee_options', {
      p_tenant: tenantId,
      p_start: query.start,
      p_end: query.end,
      p_query: query.q,
      p_limit: PAGE_SIZE,
      p_offset: (query.page - 1) * PAGE_SIZE,
    });
    options = optionsResult.error ? null : readOptionsPage(optionsResult.data);
    optionsFailed = options === null;
  }

  let selected: EmployeeOption | null = null;
  let stale = false;
  if (runSearch && options !== null && query.employee !== '') {
    selected = options.items.find((item) => item.employeeId === query.employee
      && item.employmentId === query.employment) ?? null;
    stale = selected === null;
  }

  let types: LeaveTypeOption[] = [];
  let configProblem: ConfigProblem | null = null;
  let halfDayContext: HalfDayContext | null = null;
  let halfDayError: string | null = null;

  if (selected !== null) {
    const configResult = await supabase.rpc('leave_configuration_snapshot', {
      p_tenant: tenantId,
      p_employer: selected.employerId,
    });
    const configuration = configResult.error ? null : readConfiguration(configResult.data);
    if (!configuration) {
      const message = configResult.error?.message ?? '';
      configProblem = configResult.error?.code === '42501'
        ? { title: 'إعدادات إجازات هذه الجهة غير متاحة', retry: false,
          detail: 'لا يملك حسابك صلاحية عرض إعدادات الإجازات لهذه الجهة. راجع إدارة الموارد البشرية.' }
        : message.includes('leave_employer_unavailable') || configResult.error?.code === 'P0002'
          ? { title: 'جهة العمل لم تعد متاحة', retry: false,
            detail: 'تعذر فتح إعدادات إجازات جهة الموظف المحدد. اختر موظفًا آخر من نتائج البحث.' }
          : { title: 'تعذر تحميل إعدادات الإجازات', retry: true,
            detail: 'حدث خطأ أثناء تحميل أنواع الإجازة المتاحة لهذه الجهة. أعد المحاولة.' };
    } else {
      types = availableTypes(configuration, query.start, query.end);
      if (query.start === query.end) {
        const contextResult = await supabase.rpc('leave_hr_halfday_mapping_options', {
          p_tenant: tenantId,
          p_employment: selected.employmentId,
          p_operational_date: query.start,
        });
        if (contextResult.error) {
          if (contextResult.error.code === '23514') {
            selected = null;
            stale = true;
            types = [];
          } else {
            halfDayError = 'تعذر تأكيد إمكانية تسجيل نصف يوم لهذا التاريخ الآن.';
          }
        } else {
          halfDayContext = readHalfDayContext(contextResult.data);
          if (halfDayContext === null) halfDayError = 'تعذر قراءة بيانات نصف يوم لهذا التاريخ.';
        }
      }
    }
  }

  const keepHref = recordHref(tenantId, { start: query.start, end: query.end, q: query.q, page: query.page });
  const resultsHref = recordHref(tenantId, { start: query.start, end: query.end, q: query.q, page: 1 });
  const retryHref = selected !== null
    ? recordHref(tenantId, {
      start: query.start, end: query.end, q: query.q, page: query.page,
      employee: selected.employeeId, employment: selected.employmentId,
    })
    : keepHref;

  return <PageFrame footer="الموارد البشرية">
    <div className="workspace-form-page">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/leave`}>العودة إلى قائمة مراجعة الإجازات</PendingLink>
      <PageHeader title={<>تسجيل إجازة موظف</>} eyebrow={<>الموارد البشرية</>} description={<>ابحث عن الموظف ضمن تواريخ الإجازة، اختره، ثم سجّل طلبه. لا يشترط أن يكون للموظف حساب استخدام في الشركة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave/settings`}>إعدادات الإجازات</PendingLink></>} />

      <Panel  aria-label="تسجيل إجازة موظف">
        <div className={styles.formBlock}>
          <h2 className={styles.formTitle}>البحث عن الموظف</h2>
          <form className="auth-form" method="get" role="search">
            <Field id="leave-start-date" label={<>تاريخ البداية</>} required><Input id="leave-start-date" name="start" type="date" required defaultValue={query.start} /></Field>
            <Field id="leave-end-date" label={<>تاريخ النهاية</>} required><Input id="leave-end-date" name="end" type="date" required defaultValue={query.end} /></Field>
            <Field id="leave-employee-query" label={<>ابحث بالاسم أو رمز الموظف</>}><Input id="leave-employee-query" name="q" type="search" minLength={MIN_QUERY_LENGTH}
              maxLength={MAX_QUERY_LENGTH} defaultValue={query.q} placeholder="مثال: أحمد أو EMP-12" /></Field>
            <p className="field-hint">تُعرض الملفات النشطاء الذين تغطي فترة عملهم التواريخ المحددة،
              بحد أقصى {PAGE_SIZE} نتيجة في الصفحة.</p>
            <div className="workspace-form-actions">
              <Button variant="solid"  type="submit">بحث</Button>
            </div>
          </form>
          {query.datesProvided && query.dateError !== ''
            && <Message tone="bad"  role="alert">{query.dateError}</Message>}
          {query.queryError !== '' && <Message tone="bad"  role="alert">{query.queryError}</Message>}
          {!query.datesProvided && <p className="field-hint" role="status">
            اختر تاريخي البداية والنهاية، ثم اكتب حرفين على الأقل لعرض الموظفين المتاحين في هذه الفترة.
          </p>}
          {query.datesProvided && query.dateError === '' && query.queryError === ''
            && query.q.length < MIN_QUERY_LENGTH && <p className="field-hint" role="status">
              التواريخ جاهزة. اكتب حرفين على الأقل في حقل البحث لعرض الموظفين المتاحين.
            </p>}
        </div>

        {searchReady && selected === null && <>
          <div className={styles.divider} />
          <div className={styles.formBlock}>
            <h2 className={styles.formTitle}>الموظفون المتاحون</h2>
            {stale && <Message tone="info"  role="status">
              الموظف المحدد سابقًا لم يعد ضمن نتائج البحث لهذه التواريخ. اختر موظفًا من القائمة.
            </Message>}
            {query.selectionInvalid && <Message tone="bad"  role="alert">
              بيانات الموظف المحدد غير صالحة. اختر الموظف من جديد.
            </Message>}
            {query.pageInvalid
              ? <Message tone="bad"  role="alert">رقم الصفحة غير صالح.{' '}
                <PendingLink href={resultsHref}>العودة إلى الصفحة الأولى</PendingLink></Message>
              : optionsFailed
                ? <div role="alert"><EmptyState title={<>تعذر تحميل نتائج البحث</>} description={<>لم يتغير شيء. أعد المحاولة أو عدّل التواريخ أو كلم البحث.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={resultsHref}>إعادة المحاولة</PendingLink></>} /></div>
                : options !== null && options.items.length === 0
                  ? <div ><EmptyState title={<>لا توجد نتائج مطابقة</>} description={<>جرّب اسمًا أو رمز موظف آخر، أو تواريخًا مختلفة ضمن فترة عمل الموظف.</>} /></div>
                  : options !== null ? <>
                    <ul className="record-list">{options.items.map((item) => {
                      const selectHref = recordHref(tenantId, {
                        start: query.start, end: query.end, q: query.q, page: query.page,
                        employee: item.employeeId, employment: item.employmentId,
                      });
                      return <RecordCard  key={item.employmentId}>
                        <div className="record-main">
                          <div className="record-title-row">
                            <h3>{item.employeeName}</h3>
                            <Badge className="is-active">نشط</Badge>
                          </div>
                          <p className="record-meta">رقم الموظف: <bdi>{item.employeeCode}</bdi></p>
                          <p className="record-meta">{item.employerName} · فترة العمل:{' '}
                            {item.employmentStart ? <>من <bdi>{item.employmentStart}</bdi></> : 'غير محددة'}{' '}
                            {item.employmentEnd ? <>إلى <bdi>{item.employmentEnd}</bdi></> : 'حتى الآن'}</p>
                        </div>
                        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={selectHref}>اختيار وتسجيل</PendingLink>
                      </RecordCard>;
                    })}</ul>
                    <nav className={styles.pagination} aria-label="صفحات نتائج البحث">
                      <span>الصفحة {query.page} · {options.items.length} نتيجة</span>
                      <span className={styles.paginationNav}>
                        {query.page > 1 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                          href={recordHref(tenantId, { start: query.start, end: query.end, q: query.q, page: query.page - 1 })}>
                          السابق</PendingLink>}
                        {options.hasMore && <PendingLink className="ui-button ui-button-solid ui-button-md"
                          href={recordHref(tenantId, { start: query.start, end: query.end, q: query.q, page: query.page + 1 })}>
                          التالي</PendingLink>}
                      </span>
                    </nav>
                  </> : null}
          </div>
        </>}

        {selected !== null && <>
          <div className={styles.divider} />
          <div className={styles.formBlock}>
            <h2 className={styles.formTitle}>الموظف المحدد</h2>
            <Card >
              <div className="record-main">
                <div className="record-title-row">
                  <h3>{selected.employeeName}</h3>
                  <Badge className="is-active">نشط</Badge>
                </div>
                <p className="record-meta">رقم الموظف: <bdi>{selected.employeeCode}</bdi> · {selected.employerName}</p>
                <p className="record-meta">الفترة: من <bdi>{query.start}</bdi> إلى <bdi>{query.end}</bdi>
                  {' · '}{dayCount(query.start, query.end)} يومًا</p>
              </div>
              <PendingLink className="ui-button ui-button-ghost ui-button-md" href={keepHref}>تغيير الموظف</PendingLink>
            </Card>
            {configProblem !== null && <div role="alert"><EmptyState title={<>{configProblem.title}</>} description={<>{configProblem.detail}</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                href={configProblem.retry ? retryHref : resultsHref}>
                {configProblem.retry ? 'إعادة المحاولة' : 'اختيار موظف آخر'}
              </PendingLink></>} /></div>}
            {configProblem === null && types.length === 0 && <div ><EmptyState title={<>لا توجد أنواع إجازة متاحة لهذه الفترة</>} description={<>لا يوجد نوع إجازة مفعّل يغطي التواريخ المحددة لدى «{selected.employerName}».
                راجع إعدادات إجازات هذه الجهة ثم أعد المحاولة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                href={`/tenant/${tenantId}/leave/settings/${selected.employerId}`}>إعدادات إجازات الجهة</PendingLink></>} /></div>}
          </div>
          {configProblem === null && types.length > 0 && <>
            <div className={styles.divider} />
            <RecordLeaveForm key={[user.id, tenantId, selected.employeeId, selected.employmentId, query.start, query.end].join(':')}
              initialIntentKey={crypto.randomUUID()} actorId={user.id} tenantId={tenantId} q={query.q} employee={selected}
              startDate={query.start} endDate={query.end} types={types}
              halfDayContext={halfDayContext} halfDayError={halfDayError} cancelHref={keepHref} />
          </>}
        </>}
      </Panel>
    </div>
  </PageFrame>;
}

function SubmittedView({ tenantId, requestId, request, start, end, q }: {
  tenantId: string;
  requestId: string;
  request: ReturnType<typeof readRequest>;
  start: string;
  end: string;
  q: string;
}) {
  const againHref = recordHref(tenantId, { start, end, q });
  const confirmed = request?.state === 'submitted' && request.requestSource === 'hr';
  return <PageFrame footer="الموارد البشرية">
    <div className="workspace-form-page">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/leave`}>العودة إلى قائمة مراجعة الإجازات</PendingLink>
      <PageHeader title={<>تسجيل إجازة موظف</>} eyebrow={<>الموارد البشرية</>} description={<>{confirmed ? 'سُجّل الطلب وحُوِّل إلى فريق اعتماد الإجازات دون حجز أي رصيد.'
            : 'راجع حالة الطلب الحالية قبل تسجيل طلب آخر.'}</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={againHref}>تسجيل طلب آخر</PendingLink></>} />

      <Panel  aria-label="نتيجة تسجيل الإجازة">
        <div className="success-panel" role="status">
          <div className="record-title-row">
            <h2>{confirmed ? 'الطلب مُقدَّم للمراجعة' : 'حالة طلب الإجازة'}</h2>
            {request !== null && <Badge className={`entity-status ${stateClass(request.state)}`}>
              {stateLabel(request.state)}
            </Badge>}
          </div>
          {request !== null ? <>
            <p>{request.employeeName} · رقم الموظف: <bdi>{request.employeeCode}</bdi> · {request.leaveTypeName}</p>
            <p>من <bdi>{request.startDate}</bdi> إلى <bdi>{request.endDate}</bdi> · {formatDays(request.totalUnits)} يوم
              {request.isHalfDay ? ` · نصف يوم (${halfDayPartLabel(request.halfDayPart)})` : ''}</p>
            {confirmed && <p>الطلب الآن بانتظار قرار فريق الاعتماد، ولم يُحجز أي رصيد من رصيد الموظف.</p>}
          </> : <p>تعذّر تأكيد تفاصيل هذا الطلب الآن. راجع قائمة مراجعة الإجازات للتحقق من الحالة.</p>}
          <div className="workspace-form-actions">
            <PendingLink className="ui-button ui-button-solid ui-button-md" href={detailHref(tenantId, requestId)}>فتح الطلب</PendingLink>
            <PendingLink className="ui-button ui-button-ghost ui-button-md" href={againHref}>تسجيل طلب آخر</PendingLink>
            <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave`}>قائمة المراجعة</PendingLink>
          </div>
        </div>
      </Panel>
    </div>
  </PageFrame>;
}

function Status({ tenantId, title, detail, retryPath, showQueue = false }: {
  tenantId: string;
  title: string;
  detail: string;
  retryPath?: string;
  showQueue?: boolean;
}) {
  return <PageFrame footer="الموارد البشرية">
    <Panel >
      <h1>{title}</h1>
      <p className="intro">{detail}</p>
      {retryPath && <PendingLink className="ui-button ui-button-ghost ui-button-md" href={retryPath}>إعادة المحاولة</PendingLink>}
      {showQueue && <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave`}>
        مراجعة طلبات الإجازة
      </PendingLink>}
      <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</PendingLink>
    </Panel>
  </PageFrame>;
}
