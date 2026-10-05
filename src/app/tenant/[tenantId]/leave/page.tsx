import Link from 'next/link';
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
    <header className="workspace-page-heading">
      <div>
        <p className="eyebrow">الموارد البشرية</p>
        <h1>مراجعة طلبات الإجازة</h1>
        <p>الطلبات المقدمة مرتبة من الأقدم إلى الأحدث، بحد أقصى 50 طلبًا في الصفحة. افتح الطلب لعرض أيامه واتخاذ قراره.</p>
      </div>
      <PendingLink className="secondary-button" href={`/tenant/${tenantId}/leave/settings`}>إعدادات الإجازات</PendingLink>
    </header>
    {!access.newWorkEnabled && <p className="form-message" role="status">
      خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن اعتماد طلبات جديدة أو تحديث معايناتها.
      تبقى مراجعة الطلبات ورفضها متاحة.
    </p>}

    <section className="workspace-records-panel" aria-labelledby="leave-queue-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-queue-title">طلبات بانتظار القرار</h2>
        <p>حالة «مُقدَّم» تعني أن الطلب لم يُعتمد بعد ولم يحجز أي رصيد من رصيد الموظف.</p>
      </div>
      {requestPage.invalid
        ? <p className="form-message form-error" role="alert">رقم صفحة الطلبات غير صالح.{' '}
          <PendingLink href={queueHref(tenantId, 1, cancellationPage.value)}>العودة إلى الصفحة الأولى</PendingLink></p>
        : requestsFailed
          ? <div className="empty-state" role="alert">
            <h2>تعذر تحميل قائمة الطلبات</h2>
            <p>لم يتغير أي طلب. أعد المحاولة أو عُد إلى الصفحة الأولى.</p>
            <PendingLink className="secondary-button" href={queueHref(tenantId, 1, cancellationPage.value)}>إعادة المحاولة</PendingLink>
          </div>
          : requests && requests.items.length === 0
            ? <div className="empty-state">
              <h2>لا توجد طلبات بانتظار القرار</h2>
              <p>كل الطلبات المقدمة عولجت، أو لا توجد طلبات مقدمة في هذه الشركة حاليًا.</p>
            </div>
            : requests ? <>
              <ul className="record-list">{requests.items.map((request) => <li className="record-card" key={request.id}>
                <div className="record-main">
                  <div className="record-title-row">
                    <h3>{request.employeeName}</h3>
                    <span className={`entity-status ${stateClass(request.state)}`}>{stateLabel(request.state)}</span>
                  </div>
                  <p className="record-meta">رقم الموظف: <bdi>{request.employeeCode}</bdi> · {request.leaveTypeName}</p>
                  <p className="record-meta">من <bdi>{request.startDate}</bdi> إلى <bdi>{request.endDate}</bdi>
                    · {formatDays(request.totalUnits)} يوم{request.isHalfDay ? ' · نصف يوم' : ''}</p>
                  <p className="record-meta">{request.submittedAt
                    ? <>أُرسل في <bdi>{formatInstant(request.submittedAt)}</bdi> · </>
                    : 'لم يُرسل بعد · '}{nextOwnerText(request.state, false)}</p>
                </div>
                <PendingLink className="secondary-button" href={detailHref(tenantId, request.id)}>فتح الطلب</PendingLink>
              </li>)}</ul>
              <nav className={styles.pagination} aria-label="صفحات طلبات الإجازة">
                <span>الصفحة {requestPage.value} · {requests.items.length} طلب</span>
                <span className={styles.paginationNav}>
                  {requestPage.value > 1 && <PendingLink className="secondary-button"
                    href={queueHref(tenantId, requestPage.value - 1, cancellationPage.value)}>السابق</PendingLink>}
                  {requests.hasMore && <PendingLink className="primary-button"
                    href={queueHref(tenantId, requestPage.value + 1, cancellationPage.value)}>التالي</PendingLink>}
                </span>
              </nav>
            </> : null}
    </section>

    {access.canApprove && <section className="workspace-records-panel" aria-labelledby="leave-cancellation-queue-title">
      <div className={styles.panelHeading}>
        <h2 id="leave-cancellation-queue-title">طلبات إلغاء اعتماد بانتظار القرار</h2>
        <p>الطلب المعتمد يبقى ساريًا ولا يُعاد الرصيد إلا بعد قبول طلب الإلغاء.</p>
      </div>
      {cancellationPage.invalid
        ? <p className="form-message form-error" role="alert">رقم صفحة طلبات الإلغاء غير صالح.{' '}
          <PendingLink href={queueHref(tenantId, requestPage.value, 1)}>العودة إلى الصفحة الأولى</PendingLink></p>
        : cancellationsFailed
          ? <div className="empty-state" role="alert">
            <h2>تعذر تحميل طلبات إلغاء الاعتماد</h2>
            <p>لم يتغير أي طلب إلغاء. أعد المحاولة أو عُد إلى الصفحة الأولى.</p>
            <PendingLink className="secondary-button" href={queueHref(tenantId, requestPage.value, 1)}>إعادة المحاولة</PendingLink>
          </div>
          : cancellations && cancellations.items.length === 0
            ? <div className="empty-state">
              <h2>لا توجد طلبات إلغاء اعتماد</h2>
              <p>لا يوجد أي طلب إلغاء معلق بانتظار قرارك الآن.</p>
            </div>
            : cancellations ? <>
              <ul className="record-list">{cancellations.items.map((cancellation) => <li className="record-card" key={cancellation.cancellationId}>
                <div className="record-main">
                  <div className="record-title-row">
                    <h3>{cancellation.employeeName}</h3>
                    <span className="entity-status is-pending">طلب إلغاء بانتظار القرار</span>
                  </div>
                  <p className="record-meta">رقم الموظف: <bdi>{cancellation.employeeCode}</bdi> · {cancellation.leaveTypeName}</p>
                  <p className="record-meta">من <bdi>{cancellation.startDate}</bdi> إلى <bdi>{cancellation.endDate}</bdi>
                    {cancellation.isHalfDay ? ' · نصف يوم' : ''}</p>
                  <p className="record-meta">طلبه {requesterKindLabel(cancellation.requesterKind)} في{' '}
                    <bdi>{formatInstant(cancellation.requestedAt)}</bdi></p>
                </div>
                <PendingLink className="secondary-button" href={detailHref(tenantId, cancellation.requestId)}>فتح الطلب</PendingLink>
              </li>)}</ul>
              <nav className={styles.pagination} aria-label="صفحات طلبات إلغاء الاعتماد">
                <span>الصفحة {cancellationPage.value} · {cancellations.items.length} طلب</span>
                <span className={styles.paginationNav}>
                  {cancellationPage.value > 1 && <PendingLink className="secondary-button"
                    href={queueHref(tenantId, requestPage.value, cancellationPage.value - 1)}>السابق</PendingLink>}
                  {cancellations.hasMore && <PendingLink className="primary-button"
                    href={queueHref(tenantId, requestPage.value, cancellationPage.value + 1)}>التالي</PendingLink>}
                </span>
              </nav>
            </> : null}
    </section>}

    <PendingLink className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</PendingLink>
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
      <Link className="secondary-button" href={`/tenant/${tenantId}/leave/settings`}>إعدادات الإجازات</Link>
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
    </section>
  </PageFrame>;
}
