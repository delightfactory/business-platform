import { Badge, ButtonLink, Disclosure, EmptyState, KeyValueStrip, PageHeader, Panel, RecordCard } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
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
  const { data: { user } } = await getWorkspaceUser(supabase);
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
      <Panel >
        <div role="alert"><EmptyState title={<>عرض سجل الحساب غير مصرح به</>} description={<>لا تملك صلاحية عرض سجل رصيد الموظف لدى جهة العمل المختارة. راجع إدارة الموارد البشرية.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={backHref}>العودة إلى الأرصدة</PendingLink></>} /></div>
      </Panel>
    </PageFrame>;
  }

  return <PageFrame footer="الموارد البشرية">
    <PageHeader title={<>حركات رصيد الإجازة</>} eyebrow={<>الموارد البشرية</>} description={<>أحدث الحركات أولًا، حتى {PAGE_SIZE} حركة في الصفحة. تعرض كل حركة الأيام المضافة أو المخصومة وسببها ومرجعها والسياسة المستخدمة.</>} action={<><div className="workspace-form-actions">
        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={backHref}>أرصدة الموظف</PendingLink>
        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave`}>طلبات الإجازة</PendingLink>
      </div></>} />

    {failure !== null
      ? <Panel  aria-label="خطأ في تحميل سجل الحساب">
        <div role="alert"><EmptyState title={<>{failure === 'scope' ? 'هذا الرصيد لا يخص الموظف وجهة العمل المختارين'
            : 'تعذّر تحميل سجل الحساب'}</>} description={<>لم يتغير أي رصيد. {failure === 'scope'
            ? 'الرابط يشير إلى حساب لا يخص الموظف وجهة العمل المختارين.'
            : 'أعد المحاولة أو عُد إلى الأرصدة.'}</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={failure === 'scope' ? backHref : path}>
            {failure === 'scope' ? 'العودة إلى الأرصدة' : 'إعادة المحاولة'}</PendingLink></>} /></div>
      </Panel>
      : ledger === null
        ? <Panel  aria-label="خطأ في قراءة سجل الحساب">
          <div role="alert"><EmptyState title={<>تعذّر قراءة بيانات سجل الحساب</>} description={<>لم يتغير أي رصيد. أعد المحاولة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={path}>إعادة المحاولة</PendingLink></>} /></div>
        </Panel>
        : <>
          <Panel  aria-labelledby="ledger-account-title">
            <div className={styles.panelHeading}>
              <h2 id="ledger-account-title">{ledger.pair.employeeName} · {ledger.account.typeName}</h2>
              <p>رقم الموظف: <bdi>{ledger.pair.employeeCode}</bdi> · جهة العمل: {ledger.pair.employerName}
                {' · '}{employmentStatusLabel(ledger.pair)} · {employerStatusLabel(ledger.pair)}</p>
              <p className="record-meta">الفترة: {ledger.account.periodLabel} · من{' '}
                <bdi>{ledger.account.startsOn}</bdi> إلى <bdi>{ledger.account.endsOn}</bdi></p>
              <KeyValueStrip items={[{ label: 'الرصيد الحالي', value: <>{formatDays(ledger.account.balanceDays)} يوم</> }, { label: 'فترة الرصيد', value: ledger.account.periodLabel }]} />
              <Disclosure summary="كيف يُقرأ الرصيد؟"><p>هذا الرقم هو رصيد الحساب كاملًا الذي يعيده الخادم، وليس مجموع القيود المعروضة في هذه الصفحة؛ الصفحة تعرض آخر القيود فقط.</p></Disclosure>
            </div>
            {ledger.items.length === 0
              ? <div ><EmptyState title={<>{scope.cursor === null ? 'لا توجد قيود على هذا الحساب بعد' : 'لا توجد قيود أقدم في هذه الصفحة'}</>} description={<>{scope.cursor === null
                  ? 'لم يُسجَّل أي قيد على حساب الرصيد هذا حتى الآن.'
                  : 'عُد إلى أحدث القيود لعرض أحدث حركة على الحساب.'}</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={scope.cursor === null ? backHref : newerHref}>
                  {scope.cursor === null ? 'العودة إلى الأرصدة' : 'أحدث القيود'}</PendingLink></>} /></div>
              : <>
                <ul className="record-list">{ledger.items.map((entry) => <RecordCard
                  key={entry.entryId}>
                  <div className="record-main">
                    <div className="record-title-row">
                      <h3>{entryKindLabel(entry.entryKind)}</h3>
                      <Badge className={`entity-status ${entry.deltaDays >= 0 ? 'is-active' : 'is-inactive'}`}>
                        {formatSignedDays(entry.deltaDays)} يوم</Badge>
                    </div>
                    <p className="record-meta"><bdi>{formatInstant(entry.createdAt)}</bdi>
                      {entry.requestConsumption ? ' · طلب إجازة' : entry.reversalOfEntryId ? ' · إعادة رصيد' : entry.sourceReference === '' ? '' : ` · المرجع: ${entry.sourceReference}`}</p>
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
                      {' · '}<Badge className={`entity-status ${stateClass(entry.requestConsumption.requestState)}`}>
                        {stateLabel(entry.requestConsumption.requestState)}</Badge>
                      {' · '}الأيام المخصومة من الرصيد: <bdi>{formatDays(entry.requestConsumption.units)}</bdi>
                      {' · '}تاريخ الإجازة: <bdi>{entry.requestConsumption.leaveDate}</bdi>
                    </p>}
                    {entry.reversalEntries.length > 0 && <Disclosure  summary={<>قيود أعادت رصيد هذا القيد</>}>
                      {entry.reversalEntries.map((reversal) => <p className="record-meta" key={reversal.entryId}>
                        {entryKindLabel(reversal.entryKind)} · {formatSignedDays(reversal.deltaDays)} يوم
                        {reversal.correctionId === null ? '' : ' · ضمن تصحيح'}
                        {' · '}معرّف قيد الإرجاع: <bdi>{reversal.entryId}</bdi>
                      </p>)}
                    </Disclosure>}
                    {entry.correctionLinks.length > 0 && <Disclosure  summary={<>تفاصيل التصحيح المرتبط</>}>
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
                    </Disclosure>}
                    <Disclosure  summary={<>تفاصيل تدقيق هذا القيد</>}>
                      {entry.sourceReference && <p className="record-meta">مرجع المصدر: <bdi>{entry.sourceReference}</bdi></p>}
                      <p className="record-meta">معرّف القيد: <bdi>{entry.entryId}</bdi></p>
                      {entry.reversalOfEntryId && <p className="record-meta">معرّف القيد الأصلي: <bdi>{entry.reversalOfEntryId}</bdi></p>}
                      <p className="record-meta">معرّف الحساب: <bdi>{entry.accountId}</bdi></p>
                      <p className="record-meta">معرّف المنفّذ: {entry.actorUserId
                        ? <bdi>{entry.actorUserId}</bdi> : 'غير محدّد'}</p>
                      {entry.sourceVersionId && <p className="record-meta">معرّف نسخة المصدر:{' '}
                        <bdi>{entry.sourceVersionId}</bdi></p>}
                      {entry.typeVersion && <p className="record-meta">معرّف نسخة السياسة:{' '}
                        <bdi>{entry.typeVersion.id}</bdi></p>}
                    </Disclosure>
                  </div>
                </RecordCard>)}</ul>
                <nav className={styles.pagination} aria-label="صفحات سجل الحساب">
                  <span>{scope.cursor === null ? 'أحدث القيود' : 'صفحة من قيود أقدم'}</span>
                  <span className={styles.paginationNav}>
                    {scope.cursor !== null && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                      href={newerHref}>أحدث القيود</PendingLink>}
                    {ledger.hasMore && olderHref && <PendingLink className="ui-button ui-button-solid ui-button-md"
                      href={olderHref}>الأقدم</PendingLink>}
                  </span>
                </nav>
              </>}
          </Panel>
        </>}

    <PendingLink className="ui-button ui-button-ghost ui-button-md" href={backHref}>العودة إلى أرصدة الموظف</PendingLink>
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
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/leave`}>طلبات الإجازة</ButtonLink>
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
    </Panel>
  </PageFrame>;
}
