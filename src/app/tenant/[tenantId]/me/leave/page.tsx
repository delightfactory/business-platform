import { Panel } from '@/components/ui';
import { Message, RecordCard, ButtonLink } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { Badge, Icon, PageHeader } from '@/components/ui';
import { BalanceSegments } from '@/components/patterns/balance-segments/BalanceSegments';
import { isDate, isInstant, isLeaveAccessSnapshot, isObject, isUuid } from './form-rules';
import { PendingLink } from './pending-link';
import { formatDays, formatInstant, isRequestState, stateLabel } from './states';
import styles from './leave.module.css';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 10;
// p_offset is a PostgreSQL integer: (page - 1) * PAGE_SIZE must stay within its signed 32-bit bound.
const RPC_P_OFFSET_MAX = 2147483647;
const MAX_PAGE = Math.floor(RPC_P_OFFSET_MAX / PAGE_SIZE) + 1;

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ page?: string | string[]; bal?: string | string[]; state?: string | string[] }>;

type Balance = {
  leave_type_id: string;
  type_name: string;
  period_id: string;
  period_label: string;
  starts_on: string;
  balance_days: number;
};

type RequestSummary = {
  id: string;
  leave_type_name: string;
  start_date: string;
  end_date: string;
  total_units: number;
  is_half_day: boolean;
  state: string;
  submitted_at: string | null;
};

type PagedResult<T> = { items: T[]; hasMore: boolean };

export default async function MyLeavePage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) notFound();
  const requestPage = parsePage(typeof query.page === 'string' ? query.page : '1');
  const balancePage = parsePage(typeof query.bal === 'string' ? query.bal : '1');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." retry />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/leave`)}`);

  const accessResult = await readResponse(() => supabase.rpc('leave_access_snapshot', { p_tenant: tenantId }));
  if (!accessResult || accessResult.error || !isLeaveAccessSnapshot(accessResult.data)) {
    const forbidden = accessResult?.error?.code === '42501';
    return <Status tenantId={tenantId} retry={!forbidden}
      title={forbidden ? 'الخدمة الذاتية غير متاحة لهذا الحساب' : 'تعذر تحميل إجازاتي الآن'}
      detail={forbidden ? 'لا يملك حسابك أي صلاحية لعرض بيانات الإجازات في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء تحميل بيانات إجازاتك. أعد المحاولة.'} />;
  }
  const access = accessResult.data;
  if (access.self_access !== true) {
    return <Status tenantId={tenantId} retry={false} title="عرض الإجازات غير متاح لهذا الحساب"
      detail="يجب أن يكون حسابك مرتبطًا بملف موظف بصلاحية عرض الإجازات الذاتية. راجع إدارة الموارد البشرية." />;
  }
  const canRequest = access.self_can_request === true && access.new_work_enabled === true;

  const [balancesResponse, requestsResponse] = await Promise.all([
    !balancePage.invalid ? readResponse(() => supabase.rpc('leave_my_balances', {
      p_tenant: tenantId, p_limit: PAGE_SIZE, p_offset: (balancePage.value - 1) * PAGE_SIZE,
    })) : null,
    !requestPage.invalid ? readResponse(() => supabase.rpc('leave_my_requests', {
      p_tenant: tenantId, p_limit: PAGE_SIZE, p_offset: (requestPage.value - 1) * PAGE_SIZE,
    })) : null,
  ]);
  const balancesPayload = readPaged(balancesResponse);
  const requestsPayload = readPaged(requestsResponse);
  const balances = balancesPayload ? readBalances(balancesPayload.items) : null;
  const requests = requestsPayload ? readRequests(requestsPayload.items) : null;
  const balancesFailed = !balancePage.invalid && (!balancesPayload || !balances);
  const requestsFailed = !requestPage.invalid && (!requestsPayload || !requests);
  const showResultGuide = query.state === 'submitted' || query.state === 'withdrawn';

  return <PageFrame footer="الخدمة الذاتية">
    <PageHeader eyebrow="يومي" title="إجازاتي" description="رصيدك وطلباتك في مكان واحد. الطلب المعلق لا يحجز رصيدًا قبل اعتماده." action={canRequest && <PendingLink className="ui-button ui-button-solid ui-button-md" href={`/tenant/${tenantId}/me/leave/new`}><Icon name="plus" size={18}/>طلب إجازة</PendingLink>} />
    {showResultGuide && !requestsFailed && !requestPage.invalid
      && <Message tone="info"  role="status">راجع سجل طلبات الإجازة لمعرفة الحالة الحالية لطلباتك.</Message>}
    {!canRequest && <Message tone="info"  role="status">يمكنك مراجعة أرصدة إجازاتك وسجل طلباتك. إنشاء طلبات جديدة غير متاح حاليًا.</Message>}

    <div className={styles.overviewGrid}>
    <Panel className={`workspace-records-panel ${styles.overviewPanel}`} aria-labelledby="leave-balances-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-balances-title">أرصدة الإجازات</h2>
        <p>الرصيد الحالي لكل نوع وفترة؛ الطلب المعلق لا يخصم منه.</p>
      </div>
      {balancePage.invalid ? <Message tone="bad"  role="alert">رقم صفحة الأرصدة غير صالح.{' '}
        <PendingLink href={pageHref(tenantId, requestPage.value, 1)}>العودة إلى الصفحة الأولى</PendingLink></Message>
        : balancesFailed ? <div className="empty-state" role="alert"><h2>تعذر تحميل أرصدة إجازاتك</h2>
          <p>تعذر التحقق من أحدث أرصدة إجازاتك. أعد المحاولة أو عُد إلى الصفحة الأولى.</p>
          <PendingLink className="secondary-button" href={pageHref(tenantId, requestPage.value, 1)}>إعادة المحاولة</PendingLink></div>
            : balances && balances.length === 0 ? <div className="empty-state"><h2>لا توجد أرصدة مسجّلة لك بعد</h2>
              <p>لا يوجد رصيد مسجّل لأي نوع إجازة حتى الآن. تظهر الأرصدة المسجّلة هنا فور حفظها لدى الشركة.</p></div>
            : balances ? <>
              <ul className={styles.overviewList}>{balances.map((balance) => <RecordCard  key={`${balance.leave_type_id}-${balance.period_id}`}>
                <div className="record-main">
                  <div className="record-title-row"><h3>{balance.type_name}</h3>
                    <span className={styles.balanceValue}><bdi>{formatDays(balance.balance_days)}</bdi> يوم</span></div>
                  <BalanceSegments days={balance.balance_days}/>
                  <p className="record-meta">فترة الإجازات: <bdi>{balance.period_label}</bdi></p>
                  <p className="record-meta">تبدأ في <bdi>{balance.starts_on}</bdi></p>
                </div>
              </RecordCard>)}</ul>
              <nav className={styles.pagination} aria-label="صفحات أرصدة الإجازات">
                <span>الصفحة {balancePage.value} · {balances.length} صنف</span>
                <span className={styles.paginationNav}>
                  {balancePage.value > 1 && <PendingLink className="secondary-button" href={pageHref(tenantId, requestPage.value, balancePage.value - 1)}>السابق</PendingLink>}
                  {balancesPayload?.hasMore && balancePage.value < MAX_PAGE
                    && <PendingLink className="secondary-button" href={pageHref(tenantId, requestPage.value, balancePage.value + 1)}>التالي</PendingLink>}
                </span>
              </nav>
            </> : null}
    </Panel>

    <Panel className={`workspace-records-panel ${styles.overviewPanel}`} aria-labelledby="leave-history-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-history-title">سجل طلبات الإجازة</h2>
        <p>طلباتك وحالتها الحالية. «مُقدَّم» يعني أن الطلب ينتظر قرار الموارد البشرية.</p>
      </div>
      {requestPage.invalid ? <Message tone="bad"  role="alert">رقم صفحة سجل الطلبات غير صالح.{' '}
        <PendingLink href={pageHref(tenantId, 1, balancePage.value)}>العودة إلى الصفحة الأولى</PendingLink></Message>
        : requestsFailed ? <div className="empty-state" role="alert"><h2>تعذر تحميل سجل طلباتك</h2>
          <p>تعذر التحقق من أحدث حالات طلباتك. أعد المحاولة أو عُد إلى الصفحة الأولى.</p>
          <PendingLink className="secondary-button" href={pageHref(tenantId, 1, balancePage.value)}>إعادة المحاولة</PendingLink></div>
          : requests && requests.length === 0 ? <div className="empty-state"><h2>لا توجد طلبات إجازة بعد</h2>
            <p>{canRequest ? 'ابدأ من «طلب إجازة جديد» أعلى الصفحة. سيظهر طلبك هنا مع حالته بعد إرساله.' : 'لم تُسجَّل أي طلبات إجازة باسمك حتى الآن.'}</p></div>
            : requests ? <>
              <ul className={styles.overviewList}>{requests.map((request) => <RecordCard  key={request.id}>
                <div className="record-main">
                  <div className="record-title-row"><h3>{request.leave_type_name}</h3>
                    <Badge tone={request.state === 'approved' ? 'ok' : request.state === 'rejected' ? 'bad' : request.state === 'submitted' ? 'warn' : 'neutral'}>{stateLabel(request.state)}</Badge></div>
                  <p className="record-meta">من <bdi>{request.start_date}</bdi> إلى <bdi>{request.end_date}</bdi>
                    · {formatDays(request.total_units)} يوم{request.is_half_day ? ' · نصف يوم' : ''}</p>
                  <p className="record-meta">{request.submitted_at
                    ? <>أُرسل في <bdi>{formatInstant(request.submitted_at)}</bdi></>
                    : 'لم يُرسل بعد'}</p>
                </div>
                <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/me/leave/${request.id}`}>التفاصيل<Icon name="arrowLeft" size={16}/></PendingLink>
              </RecordCard>)}</ul>
              <nav className={styles.pagination} aria-label="صفحات سجل طلبات الإجازة">
                <span>الصفحة {requestPage.value} · {requests.length} طلب</span>
                <span className={styles.paginationNav}>
                  {requestPage.value > 1 && <PendingLink className="secondary-button" href={pageHref(tenantId, requestPage.value - 1, balancePage.value)}>السابق</PendingLink>}
                  {requestsPayload?.hasMore && requestPage.value < MAX_PAGE
                    && <PendingLink className="secondary-button" href={pageHref(tenantId, requestPage.value + 1, balancePage.value)}>التالي</PendingLink>}
                </span>
              </nav>
            </> : null}
    </Panel>
    </div>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
  </PageFrame>;
}

function parsePage(raw: string): { value: number; invalid: boolean } {
  if (!/^\d+$/.test(raw)) return { value: 1, invalid: true };
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > MAX_PAGE) return { value: 1, invalid: true };
  return { value, invalid: false };
}

function pageHref(tenantId: string, requestPage: number, balancePage: number): string {
  const params = new URLSearchParams();
  if (requestPage > 1) params.set('page', String(requestPage));
  if (balancePage > 1) params.set('bal', String(balancePage));
  const suffix = params.toString();
  return `/tenant/${tenantId}/me/leave${suffix ? `?${suffix}` : ''}`;
}

function readPaged(response: { data: unknown; error: unknown } | null): PagedResult<unknown> | null {
  if (!response || response.error || !isObject(response.data)) return null;
  const payload = response.data;
  if (!Array.isArray(payload.items) || typeof payload.has_more !== 'boolean') return null;
  return { items: payload.items, hasMore: payload.has_more };
}

function readBalances(items: unknown[]): Balance[] | null {
  const balances: Balance[] = [];
  for (const item of items) {
    if (!isObject(item) || !isUuid(item.leave_type_id) || !isUuid(item.period_id)
      || typeof item.type_name !== 'string' || typeof item.period_label !== 'string'
      || typeof item.starts_on !== 'string' || !isDate(item.starts_on)
      || typeof item.balance_days !== 'number' || !Number.isFinite(item.balance_days)) return null;
    balances.push({
      leave_type_id: item.leave_type_id,
      type_name: item.type_name,
      period_id: item.period_id,
      period_label: item.period_label,
      starts_on: item.starts_on,
      balance_days: item.balance_days,
    });
  }
  return balances;
}

function readRequests(items: unknown[]): RequestSummary[] | null {
  const requests: RequestSummary[] = [];
  for (const item of items) {
    if (!isObject(item) || !isUuid(item.id) || typeof item.leave_type_name !== 'string'
      || typeof item.start_date !== 'string' || typeof item.end_date !== 'string'
      || !isDate(item.start_date) || !isDate(item.end_date) || item.start_date > item.end_date
      || typeof item.total_units !== 'number' || !Number.isFinite(item.total_units) || item.total_units <= 0
      || typeof item.is_half_day !== 'boolean' || !isRequestState(item.state)
      || !(item.submitted_at === null || isInstant(item.submitted_at))) return null;
    requests.push({
      id: item.id,
      leave_type_name: item.leave_type_name,
      start_date: item.start_date,
      end_date: item.end_date,
      total_units: item.total_units,
      is_half_day: item.is_half_day,
      state: item.state,
      submitted_at: item.submitted_at,
    });
  }
  return requests;
}

function Status({ tenantId, title, detail, retry = false }: { tenantId: string; title: string; detail: string; retry?: boolean }) {
  return <PageFrame footer="الخدمة الذاتية">
    <Panel className="auth-card"><PageHeader  title={<>{title}</>} /><p className="intro">{detail}</p>
      {retry && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/me/leave`}>إعادة المحاولة</ButtonLink>}
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/me`}>العودة إلى ملفي</ButtonLink>
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
