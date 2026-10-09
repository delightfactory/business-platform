import { Avatar, Badge, ButtonLink, Disclosure, EmptyState, Message, PageHeader, Panel, RecordCard } from '@/components/ui';

import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PendingLink } from './pending-link';
import {
  PAGE_SIZE,
  detailHref,
  formatDays,
  formatInstant,
  isUuid,
  nextOwnerText,
  parsePage,
  queueHref,
  readAccess,
  readCancellationQueue,
  readRequestQueue,
  requesterKindLabel,
  stateClass,
  stateLabel,
} from './rules';
import styles from './review.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ page?: string | string[]; cpage?: string | string[] }>;

export default async function LeaveReviewQueuePage({ params, searchParams }: {
  params: Params;
  searchParams: Query;
}) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) notFound();
  const requestPage = parsePage(query.page);
  const cancellationPage = parsePage(query.cpage);
  const path = `/tenant/${tenantId}/leave`;

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
      title={forbidden ? 'مراجعة طلبات الإجازة غير متاحة لهذا الحساب' : 'تعذر تحميل طلبات الإجازة الآن'}
      detail={forbidden
        ? 'لا يملك حسابك أي صلاحية لعرض طلبات الإجازة في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء التحقق من صلاحيتك أو تحميل القائمة. أعد المحاولة.'}
      retryPath={forbidden ? undefined : path} />;
  }
  if (!access.canView) {
    return <Status tenantId={tenantId} title="عرض طلبات الإجازة غير متاح لهذا الحساب"
      detail="تحتاج إلى صلاحية عرض أو اعتماد أو إدارة الإجازات لدى الشركة. راجع إدارة الموارد البشرية." />;
  }

  const requestResult = requestPage.invalid ? null
    : await supabase.rpc('leave_hr_queue', {
      p_tenant: tenantId,
      p_limit: PAGE_SIZE,
      p_offset: (requestPage.value - 1) * PAGE_SIZE,
    });
  const cancellationResult = !access.canApprove || cancellationPage.invalid ? null
    : await supabase.rpc('leave_cancellation_queue', {
      p_tenant: tenantId,
      p_limit: PAGE_SIZE,
      p_offset: (cancellationPage.value - 1) * PAGE_SIZE,
    });

  const requests = !requestPage.invalid && requestResult && !requestResult.error
    ? readRequestQueue(requestResult.data) : null;
  const cancellations = access.canApprove && !cancellationPage.invalid && cancellationResult && !cancellationResult.error
    ? readCancellationQueue(cancellationResult.data) : null;
  const requestsFailed = !requestPage.invalid && requests === null;
  const cancellationsFailed = access.canApprove && !cancellationPage.invalid && cancellations === null;

  return <PageFrame footer="الموارد البشرية">
    <PageHeader title={<>مراجعة طلبات الإجازة</>} eyebrow={<>الموارد البشرية</>} description={<>الطلبات المقدمة مرتبة من الأقدم إلى الأحدث، بحد أقصى 50 طلبًا في الصفحة. افتح الطلب لعرض أيامه واتخاذ قراره.</>} action={<><div className="workspace-form-actions">
        {access.canManage && access.newWorkEnabled && <PendingLink className="ui-button ui-button-solid ui-button-md"
          href={`/tenant/${tenantId}/leave/new`}>تسجيل إجازة موظف</PendingLink>}
        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave/settings`}>إعدادات الإجازات</PendingLink>
      </div></>} />
    {!access.newWorkEnabled && <Message tone="info"  role="status">
      خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن اعتماد طلبات جديدة أو تحديث معايناتها.
      تبقى مراجعة الطلبات ورفضها متاحة.
    </Message>}

    <Panel  aria-labelledby="leave-queue-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-queue-title">طلبات بانتظار القرار</h2>
        <p>حالة «مُقدَّم» تعني أن الطلب لم يُعتمد بعد ولم يحجز أي رصيد من رصيد الموظف.</p>
      </div>
      {requestPage.invalid
        ? <Message tone="bad"  role="alert">رقم صفحة الطلبات غير صالح.{' '}
          <PendingLink href={queueHref(tenantId, 1, cancellationPage.value)}>العودة إلى الصفحة الأولى</PendingLink></Message>
        : requestsFailed
          ? <div role="alert"><EmptyState title={<>تعذر تحميل قائمة الطلبات</>} description={<>لم يتغير أي طلب. أعد المحاولة أو عُد إلى الصفحة الأولى.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={queueHref(tenantId, 1, cancellationPage.value)}>إعادة المحاولة</PendingLink></>} /></div>
          : requests && requests.items.length === 0
            ? <div ><EmptyState title={<>{requestPage.value > 1 ? 'لا توجد طلبات في هذه الصفحة' : 'لا توجد طلبات بانتظار القرار'}</>} description={<>{requestPage.value > 1 ? 'عُد إلى الصفحة الأولى لعرض الطلبات الحالية.' : 'لا توجد طلبات مقدمة بانتظار القرار حاليًا.'}</>} action={<>{requestPage.value > 1 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                href={queueHref(tenantId, 1, cancellationPage.value)}>العودة إلى أول صفحة للطلبات</PendingLink>}</>} /></div>
            : requests ? <>
              <ul className="record-list">{requests.items.map((request) => <RecordCard  key={request.id}>
                <div className="record-main">
                  <div className="record-title-row">
                    <Avatar name={request.employeeName} size={40}/><h3>{request.employeeName}</h3>
                    <Badge className={`entity-status ${stateClass(request.state)}`}>{stateLabel(request.state)}</Badge>
                  </div>
                  <p className="record-meta">رقم الموظف: <bdi>{request.employeeCode}</bdi> · {request.leaveTypeName}</p>
                  <p className="record-meta">من <bdi>{request.startDate}</bdi> إلى <bdi>{request.endDate}</bdi>
                    · {formatDays(request.totalUnits)} يوم{request.isHalfDay ? ' · نصف يوم' : ''}</p>
                  <Disclosure  summary={<>تفاصيل الإرسال والمتابعة</>}><p className="record-meta">{request.submittedAt
                    ? <>أُرسل في <bdi>{formatInstant(request.submittedAt)}</bdi> · </>
                    : 'لم يُرسل بعد · '}{nextOwnerText(request.state, false)}</p></Disclosure>
                </div>
                <PendingLink className="ui-button ui-button-ghost ui-button-md" href={detailHref(tenantId, request.id)}>فتح الطلب</PendingLink>
              </RecordCard>)}</ul>
              <nav className={styles.pagination} aria-label="صفحات طلبات الإجازة">
                <span>الصفحة {requestPage.value} · {requests.items.length} طلب</span>
                <span className={styles.paginationNav}>
                  {requestPage.value > 1 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                    href={queueHref(tenantId, requestPage.value - 1, cancellationPage.value)}>السابق</PendingLink>}
                  {requests.hasMore && <PendingLink className="ui-button ui-button-solid ui-button-md"
                    href={queueHref(tenantId, requestPage.value + 1, cancellationPage.value)}>التالي</PendingLink>}
                </span>
              </nav>
            </> : null}
    </Panel>

    {access.canApprove && <Panel  aria-labelledby="leave-cancellation-queue-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-cancellation-queue-title">طلبات إلغاء اعتماد بانتظار القرار</h2>
        <p>الطلب المعتمد يبقى ساريًا ولا يُعاد الرصيد إلا بعد قبول طلب الإلغاء.</p>
      </div>
      {cancellationPage.invalid
        ? <Message tone="bad"  role="alert">رقم صفحة طلبات الإلغاء غير صالح.{' '}
          <PendingLink href={queueHref(tenantId, requestPage.value, 1)}>العودة إلى الصفحة الأولى</PendingLink></Message>
        : cancellationsFailed
          ? <div role="alert"><EmptyState title={<>تعذر تحميل طلبات إلغاء الاعتماد</>} description={<>لم يتغير أي طلب إلغاء. أعد المحاولة أو عُد إلى الصفحة الأولى.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={queueHref(tenantId, requestPage.value, 1)}>إعادة المحاولة</PendingLink></>} /></div>
          : cancellations && cancellations.items.length === 0
            ? <div ><EmptyState title={<>{cancellationPage.value > 1 ? 'لا توجد طلبات إلغاء في هذه الصفحة' : 'لا توجد طلبات إلغاء اعتماد'}</>} description={<>{cancellationPage.value > 1 ? 'عُد إلى الصفحة الأولى لعرض طلبات الإلغاء الحالية.' : 'لا يوجد أي طلب إلغاء معلق بانتظار قرارك الآن.'}</>} action={<>{cancellationPage.value > 1 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                href={queueHref(tenantId, requestPage.value, 1)}>العودة إلى أول صفحة للإلغاء</PendingLink>}</>} /></div>
            : cancellations ? <>
              <ul className="record-list">{cancellations.items.map((cancellation) => <RecordCard  key={cancellation.cancellationId}>
                <div className="record-main">
                  <div className="record-title-row">
                    <Avatar name={cancellation.employeeName} size={40}/><h3>{cancellation.employeeName}</h3>
                    <Badge className="is-pending">طلب إلغاء بانتظار القرار</Badge>
                  </div>
                  <p className="record-meta">رقم الموظف: <bdi>{cancellation.employeeCode}</bdi> · {cancellation.leaveTypeName}</p>
                  <p className="record-meta">من <bdi>{cancellation.startDate}</bdi> إلى <bdi>{cancellation.endDate}</bdi>
                    {cancellation.isHalfDay ? ' · نصف يوم' : ''}</p>
                  <p className="record-meta">طلبه {requesterKindLabel(cancellation.requesterKind)} في{' '}
                    <bdi>{formatInstant(cancellation.requestedAt)}</bdi></p>
                </div>
                <PendingLink className="ui-button ui-button-ghost ui-button-md" href={detailHref(tenantId, cancellation.requestId)}>فتح الطلب</PendingLink>
              </RecordCard>)}</ul>
              <nav className={styles.pagination} aria-label="صفحات طلبات إلغاء الاعتماد">
                <span>الصفحة {cancellationPage.value} · {cancellations.items.length} طلب</span>
                <span className={styles.paginationNav}>
                  {cancellationPage.value > 1 && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                    href={queueHref(tenantId, requestPage.value, cancellationPage.value - 1)}>السابق</PendingLink>}
                  {cancellations.hasMore && <PendingLink className="ui-button ui-button-solid ui-button-md"
                    href={queueHref(tenantId, requestPage.value, cancellationPage.value + 1)}>التالي</PendingLink>}
                </span>
              </nav>
            </> : null}
    </Panel>}

    <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</PendingLink>
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
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/leave/settings`}>إعدادات الإجازات</ButtonLink>
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
    </Panel>
  </PageFrame>;
}
