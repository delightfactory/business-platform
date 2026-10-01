import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { PendingLink } from '../../pending-link';
import { detailHref, formatInstant, isUuid, stateClass, stateLabel } from '../../rules';
import {
  PAGE_SIZE,
  balancesHref,
  employmentStatusLabel,
  entryKindLabel,
  employerStatusLabel,
  formatDays,
  formatSignedDays,
  ledgerHref,
  parseLedgerQuery,
  readBalanceAccess,
  readFailure,
  readLedgerPage,
} from '../rules';
import styles from '../../review.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; accountId: string }>;

export default async function LeaveBalanceLedgerPage({ params, searchParams }: {
  params: Params;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { tenantId, accountId } = await params;
  const raw = await searchParams;
  if (!isUuid(tenantId) || !isUuid(accountId)) notFound();
  const scope = parseLedgerQuery(raw);
  const accountsPath = `/tenant/${tenantId}/leave/balances`;
  const path = scope.employee === '' ? accountsPath
    : ledgerHref(tenantId, accountId, { employee: scope.employee, employer: scope.employer });

  const supabase = await createSupabaseServerClient();
  if (!supabase) {
    return <Status tenantId={tenantId} title="الاتصال غير متاح"
      detail="تعذّر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." retryPath={path} />;
  }
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(path)}`);

  const accessResult = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  const access = accessResult.error ? null : readBalanceAccess(accessResult.data);
  if (!access) {
    const forbidden = accessResult.error?.code === '42501';
    return <Status tenantId={tenantId}
      title={forbidden ? 'سجل الحساب غير متاح لهذا الحساب' : 'تعذّر تحميل سجل الحساب الآن'}
      detail={forbidden
        ? 'لا يملك حسابك أي صلاحية لعرض سجل حسابات الإجازات في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء التحقق من صلاحيتك أو تحميل الصفحة. أعد المحاولة.'}
      retryPath={forbidden ? undefined : path} />;
  }
  if (!access.canView) {
    return <Status tenantId={tenantId} title="سجل حسابات الإجازات غير متاح لهذا الحساب"
      detail="تحتاج إلى صلاحية عرض أرصدة الإجازات لدى الشركة. راجع إدارة الموارد البشرية." />;
  }
  if (scope.error !== '') {
    return <Status tenantId={tenantId} title="رابط سجل الحساب غير صالح" detail={scope.error}
      retryPath={accountsPath} />;
  }

  const ledgerResult = await supabase.rpc('leave_balance_ledger', {
    p_tenant: tenantId,
    p_employee: scope.employee,
    p_employer: scope.employer,
    p_account: accountId,
    p_limit: PAGE_SIZE,
    p_before_created_at: scope.cursor ? scope.cursor.createdAt : null,
    p_before_entry: scope.cursor ? scope.cursor.entryId : null,
  });
  const ledger = ledgerResult.error ? null : readLedgerPage(ledgerResult.data);
  const failure = ledgerResult.error ? readFailure(ledgerResult.error.code) : null;

  const backHref = balancesHref(tenantId, { employee: scope.employee, employer: scope.employer });
  const newerHref = ledgerHref(tenantId, accountId, { employee: scope.employee, employer: scope.employer });
  const olderHref = !ledger || !ledger.next ? null
    : ledgerHref(tenantId, accountId, {
      employee: scope.employee, employer: scope.employer,
      lc: ledger.next.createdAt, le: ledger.next.entryId,
    });

  if (failure === 'denied') {
    return <PageFrame footer="الموارد البشرية">
      <section className="workspace-records-panel">
        <div className="empty-state" role="alert">
          <h2>عرض سجل الحساب غير مصرح به</h2>
          <p>لا تملك صلاحية عرض سجل رصيد الموظف لدى جهة العمل المختارة. راجع إدارة الموارد البشرية.</p>
          <PendingLink className="secondary-button" href={backHref}>العودة إلى الأرصدة</PendingLink>
        </div>
      </section>
    </PageFrame>;
  }

  return <PageFrame footer="الموارد البشرية">
    <header className="workspace-page-heading">
      <div>
        <p className="eyebrow">الموارد البشرية</p>
        <h1>سجل حساب الرصيد</h1>
        <p>القيود مرتّبة من الأحدث إلى الأقدم بحد أقصى {PAGE_SIZE} قيدًا في الصفحة، وكل قيد يعرض
          أيامه الموقعة وسببه ومرجعه ونسخة السياسة المرتبطة به.</p>
      </div>
      <div className="workspace-form-actions">
        <PendingLink className="secondary-button" href={backHref}>أرصدة الموظف</PendingLink>
        <PendingLink className="secondary-button" href={`/tenant/${tenantId}/leave`}>طلبات الإجازة</PendingLink>
      </div>
    </header>

    {failure !== null
      ? <section className="workspace-records-panel" aria-label="خطأ في تحميل سجل الحساب">
        <div className="empty-state" role="alert">
          <h2>{failure === 'scope' ? 'هذا الحساب غير متاح لزوج الموظف المحدد'
            : 'تعذّر تحميل سجل الحساب'}</h2>
          <p>لم يتغير أي رصيد. {failure === 'scope'
            ? 'الرابط يشير إلى حساب لا يخص الموظف وجهة العمل المختارين.'
            : 'أعد المحاولة أو عُد إلى الأرصدة.'}</p>
          <PendingLink className="secondary-button" href={failure === 'scope' ? backHref : path}>
            {failure === 'scope' ? 'العودة إلى الأرصدة' : 'إعادة المحاولة'}</PendingLink>
        </div>
      </section>
      : ledger === null
        ? <section className="workspace-records-panel" aria-label="خطأ في قراءة سجل الحساب">
          <div className="empty-state" role="alert">
            <h2>تعذّر قراءة بيانات سجل الحساب</h2>
            <p>لم يتغير أي رصيد. أعد المحاولة.</p>
            <PendingLink className="secondary-button" href={path}>إعادة المحاولة</PendingLink>
          </div>
        </section>
        : <>
          <section className="workspace-records-panel" aria-labelledby="ledger-account-title">
            <div className={styles.panelHeading}>
              <h2 id="ledger-account-title">{ledger.pair.employeeName} · {ledger.account.typeName}</h2>
              <p>رقم الموظف: <bdi>{ledger.pair.employeeCode}</bdi> · جهة العمل: {ledger.pair.employerName}
                {' · '}{employmentStatusLabel(ledger.pair)} · {employerStatusLabel(ledger.pair)}</p>
              <p className="record-meta">الفترة: {ledger.account.periodLabel} · من{' '}
                <bdi>{ledger.account.startsOn}</bdi> إلى <bdi>{ledger.account.endsOn}</bdi></p>
              <p>الرصيد الحالي للحساب كاملًا: <bdi>{formatDays(ledger.account.balanceDays)}</bdi> يوم.
                هذا الرقم هو رصيد الحساب الذي يعيده الخادم، وليس مجموع القيود المعروضة في هذه الصفحة؛
                الصفحة تعرض آخر القيود فقط.</p>
            </div>
            {ledger.items.length === 0
              ? <div className="empty-state">
                <h2>{scope.cursor === null ? 'لا توجد قيود على هذا الحساب بعد' : 'لا توجد قيود أقدم في هذه الصفحة'}</h2>
                <p>{scope.cursor === null
                  ? 'لم يُسجَّل أي قيد على حساب الرصيد هذا حتى الآن.'
                  : 'عُد إلى أحدث القيود لعرض أحدث حركة على الحساب.'}</p>
                <PendingLink className="secondary-button" href={scope.cursor === null ? backHref : newerHref}>
                  {scope.cursor === null ? 'العودة إلى الأرصدة' : 'أحدث القيود'}</PendingLink>
              </div>
              : <>
                <ul className="record-list">{ledger.items.map((entry) => <li className="record-card"
                  key={entry.entryId}>
                  <div className="record-main">
                    <div className="record-title-row">
                      <h3>{entryKindLabel(entry.entryKind)}</h3>
                      <span className={`entity-status ${entry.deltaDays >= 0 ? 'is-active' : 'is-inactive'}`}>
                        {formatSignedDays(entry.deltaDays)} يوم</span>
                    </div>
                    <p className="record-meta"><bdi>{formatInstant(entry.createdAt)}</bdi>
                      {entry.sourceReference === '' ? '' : ` · المرجع: ${entry.sourceReference}`}</p>
                    <p className="record-meta">{entry.reason}</p>
                    {entry.typeVersion && <p className="record-meta">
                      نسخة السياسة {entry.typeVersion.version} سارية من <bdi>{entry.typeVersion.effectiveFrom}</bdi>
                      {entry.typeVersion.effectiveUntil
                        ? <> إلى <bdi>{entry.typeVersion.effectiveUntil}</bdi></> : ' دون تاريخ انتهاء'}
                      {' · '}المصدر: {entry.typeVersion.source}
                      {' · '}وضع الرصيد: {entry.typeVersion.balanceMode === 'tracked' ? 'متتبع' : 'غير متتبع'}
                    </p>}
                    {entry.reversalOfEntryId !== null && <p className="record-meta">
                      قيد إرجاع يعيد رصيد قيد سابق.
                      {entry.reversedSourceDeltaDays !== null && <>
                        {' '}قدر القيد الأصلي: {formatSignedDays(entry.reversedSourceDeltaDays)} يوم</>}
                    </p>}
                    {entry.correctionId !== null && <p className="record-meta">قيد ضمن تصحيح طلبات.</p>}
                    {entry.requestConsumption && <p className="record-meta">
                      رُبط باعتماد طلب إجازة:{' '}
                      <PendingLink href={detailHref(tenantId, entry.requestConsumption.requestId)}>
                        فتح الطلب</PendingLink>
                      {' · '}<span className={`entity-status ${stateClass(entry.requestConsumption.requestState)}`}>
                        {stateLabel(entry.requestConsumption.requestState)}</span>
                      {' · '}الأيام المستهلكة: <bdi>{formatDays(entry.requestConsumption.units)}</bdi>
                      {' · '}تاريخ الإجازة: <bdi>{entry.requestConsumption.leaveDate}</bdi>
                    </p>}
                    {entry.reversalEntries.length > 0 && <details className="task-disclosure">
                      <summary>قيود أعادت رصيد هذا القيد</summary>
                      {entry.reversalEntries.map((reversal) => <p className="record-meta" key={reversal.entryId}>
                        {entryKindLabel(reversal.entryKind)} · {formatSignedDays(reversal.deltaDays)} يوم
                        {reversal.correctionId === null ? '' : ' · ضمن تصحيح'}
                        {' · '}معرّف قيد الإرجاع: <bdi>{reversal.entryId}</bdi>
                      </p>)}
                    </details>}
                    {entry.correctionLinks.length > 0 && <details className="task-disclosure">
                      <summary>تفاصيل التصحيح المرتبط</summary>
                      {entry.correctionLinks.map((correction) => <div key={correction.correctionId}>
                        <p className="record-meta">سبب التصحيح: {correction.reason}
                          {' · '}سُجّل في <bdi>{formatInstant(correction.createdAt)}</bdi></p>
                        {correction.originalRequestId && <p className="record-meta">
                          الطلب الأصلي:{' '}
                          <PendingLink href={detailHref(tenantId, correction.originalRequestId)}>
                            فتح الطلب الأصلي</PendingLink>
                        </p>}
                        {correction.replacementRequestId && <p className="record-meta">
                          الطلب البديل:{' '}
                          <PendingLink href={detailHref(tenantId, correction.replacementRequestId)}>
                            فتح الطلب البديل</PendingLink>
                        </p>}
                      </div>)}
                    </details>}
                    <details className="task-disclosure">
                      <summary>معرّفات تدقيق هذا القيد</summary>
                      <p className="record-meta">معرّف القيد: <bdi>{entry.entryId}</bdi></p>
                      {entry.reversalOfEntryId && <p className="record-meta">معرّف القيد الأصلي: <bdi>{entry.reversalOfEntryId}</bdi></p>}
                      <p className="record-meta">معرّف الحساب: <bdi>{entry.accountId}</bdi></p>
                      <p className="record-meta">معرّف المنفّذ: {entry.actorUserId
                        ? <bdi>{entry.actorUserId}</bdi> : 'غير محدّد'}</p>
                      {entry.sourceVersionId && <p className="record-meta">معرّف نسخة المصدر:{' '}
                        <bdi>{entry.sourceVersionId}</bdi></p>}
                      {entry.typeVersion && <p className="record-meta">معرّف نسخة السياسة:{' '}
                        <bdi>{entry.typeVersion.id}</bdi></p>}
                    </details>
                  </div>
                </li>)}</ul>
                <nav className={styles.pagination} aria-label="صفحات سجل الحساب">
                  <span>{scope.cursor === null ? 'أحدث القيود' : 'صفحة من قيود أقدم'}</span>
                  <span className={styles.paginationNav}>
                    {scope.cursor !== null && <PendingLink className="secondary-button"
                      href={newerHref}>أحدث القيود</PendingLink>}
                    {ledger.hasMore && olderHref && <PendingLink className="primary-button"
                      href={olderHref}>الأقدم</PendingLink>}
                  </span>
                </nav>
              </>}
          </section>
        </>}

    <PendingLink className="secondary-button" href={backHref}>العودة إلى أرصدة الموظف</PendingLink>
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
      <Link className="secondary-button" href={`/tenant/${tenantId}/leave`}>طلبات الإجازة</Link>
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
    </section>
  </PageFrame>;
}
