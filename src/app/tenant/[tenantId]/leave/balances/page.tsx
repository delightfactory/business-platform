import { Badge, Button, ButtonLink, Card, EmptyState, Field, Input, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { PendingLink } from '../pending-link';
import { isUuid } from '../rules';
import {
  PAGE_SIZE,
  balancesHref,
  blockedReasonLabel,
  employmentStatusLabel,
  employerStatusLabel,
  formatDays,
  ledgerHref,
  parseBalanceQuery,
  postingKindLabel,
  readAccountsPage,
  readBalanceAccess,
  readFailure,
  readOptionsPage,
  readPeriodsPage,
  readTypesPage,
  type PostingKind,
} from './rules';
import { PostBalanceForm } from './PostBalanceForm';
import styles from '../review.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;

export default async function LeaveBalancesPage({ params, searchParams }: {
  params: Params;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { tenantId } = await params;
  const raw = await searchParams;
  if (!isUuid(tenantId)) notFound();
  const { params: query, errors } = parseBalanceQuery(raw);
  const path = `/tenant/${tenantId}/leave/balances`;

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
      title={forbidden ? 'أرصدة الإجازات غير متاحة لهذا الحساب' : 'تعذّر تحميل أرصدة الإجازات الآن'}
      detail={forbidden
        ? 'لا يملك حسابك أي صلاحية لعرض أرصدة الإجازات في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء التحقق من صلاحيتك أو تحميل الصفحة. أعد المحاولة.'}
      retryPath={forbidden ? undefined : path} />;
  }
  if (!access.canView) {
    return <Status tenantId={tenantId} title="عرض أرصدة الإجازات غير متاح لهذا الحساب"
      detail="تحتاج إلى صلاحية عرض أرصدة الإجازات أو تعديلها لدى الشركة. راجع إدارة الموارد البشرية." />;
  }

  // parseBalanceQuery has already discarded any incomplete cursor tuple, so a bad cursor
  // simply restarts at the first page while the matching alert explains what happened.
  const hasPair = query.employee !== '' && errors.pair === '';
  const [optionsResult, accountsResult] = await Promise.all([
    query.q === '' ? null : supabase.rpc('leave_balance_employee_options', {
      p_tenant: tenantId,
      p_query: query.q,
      p_limit: PAGE_SIZE,
      p_after_code: query.sc === '' ? null : query.sc,
      p_after_employee: query.se === '' ? null : query.se,
      p_after_employer: query.so === '' ? null : query.so,
    }),
    !hasPair ? null : supabase.rpc('leave_balance_accounts', {
      p_tenant: tenantId,
      p_employee: query.employee,
      p_employer: query.employer,
      p_limit: PAGE_SIZE,
      p_after_period_start: query.acs === '' ? null : query.acs,
      p_after_account: query.aca === '' ? null : query.aca,
    }),
  ]);
  const options = optionsResult && !optionsResult.error ? readOptionsPage(optionsResult.data) : null;
  const accounts = accountsResult && !accountsResult.error ? readAccountsPage(accountsResult.data) : null;
  const pair = accounts?.pair ?? null;
  const canPost = pair !== null && pair.canAdjust;
  const accountContext = query.kind === 'adjustment' ? accounts?.items.find((account) =>
    account.periodId === query.period && account.leaveTypeId === query.type) ?? null : null;

  const [periodsResult, initialTypesResult] = await Promise.all([
    !canPost || query.kind === '' ? null
    : supabase.rpc('leave_balance_posting_periods', {
      p_tenant: tenantId,
      p_employee: query.employee,
      p_employer: query.employer,
      p_limit: PAGE_SIZE,
      p_after_start: query.pcs === '' ? null : query.pcs,
      p_after_period: query.pcp === '' ? null : query.pcp,
    }),
    !canPost || query.kind === '' || query.period === '' ? null
    : supabase.rpc('leave_balance_posting_types', {
      p_tenant: tenantId,
      p_employee: query.employee,
      p_employer: query.employer,
      p_kind: query.kind,
      p_period: query.period,
      p_limit: PAGE_SIZE,
      p_after_code: query.tcs === '' ? null : query.tcs,
      p_after_type: query.tct === '' ? null : query.tct,
    }),
  ]);
  const periods = periodsResult && !periodsResult.error ? readPeriodsPage(periodsResult.data) : null;
  const selectedPeriod = query.period === '' ? null
    : periods?.items.find((item) => item.periodId === query.period)
      ?? (accountContext ? { label: accountContext.periodLabel, startsOn: accountContext.startsOn, endsOn: accountContext.endsOn } : null);

  let typesResult = initialTypesResult;
  let types = typesResult && !typesResult.error ? readTypesPage(typesResult.data) : null;
  let selectedType = query.type === '' || !types ? null
    : types.items.find((item) => item.leaveTypeId === query.type) ?? null;
  if (canPost && accountContext && types && !selectedType) {
    // Seek immediately before the known account type, retaining the authoritative
    // eligibility/version read even when the type is beyond the first page.
    const hex = (BigInt(`0x${accountContext.leaveTypeId.replaceAll('-', '')}`) - BigInt(1)).toString(16).padStart(32, '0');
    const beforeType = `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
    typesResult = await supabase.rpc('leave_balance_posting_types', {
      p_tenant: tenantId, p_employee: query.employee, p_employer: query.employer,
      p_kind: query.kind, p_period: query.period, p_limit: PAGE_SIZE,
      p_after_code: accountContext.typeCode, p_after_type: beforeType,
    });
    types = !typesResult.error ? readTypesPage(typesResult.data) : null;
    selectedType = types?.items.find((item) => item.leaveTypeId === query.type) ?? null;
  }

  const searchHref = (next: Partial<Parameters<typeof balancesHref>[1]> = {}) =>
    balancesHref(tenantId, { employee: '', employer: '', kind: '', period: '', type: '', ...next });
  const pairHref = (next: Partial<Parameters<typeof balancesHref>[1]> = {}) =>
    balancesHref(tenantId, { employee: query.employee, employer: query.employer, ...next });
  const selectedPeriodQuery = { kind: query.kind, period: query.period, pcs: query.pcs, pcp: query.pcp };
  const selectedTypeQuery = { ...selectedPeriodQuery, type: query.type, tcs: query.tcs, tct: query.tct };

  const postingForm = canPost && query.type !== '' && query.period !== '' && query.kind !== ''
    ? <PostBalanceForm key={[user.id,tenantId,query.employee,query.employer,query.kind,query.period,query.type].join(':')}
      tenantId={tenantId} actorId={user.id} employeeId={query.employee} employerId={query.employer}
      kind={query.kind as PostingKind} periodId={query.period} periodLabel={selectedPeriod?.label ?? ''}
      type={selectedType} leaveTypeId={query.type} initialIntentKey={crypto.randomUUID()}
      cancelHref={pairHref(selectedPeriodQuery)} backHref={pairHref()} /> : null;

  const queryAlerts = [
    { message: errors.searchCursor, href: searchHref({ q: query.q }), label: 'العودة إلى أول صفحة للبحث' },
    { message: errors.pair, href: searchHref({ q: query.q }), label: 'اختيار الموظف من جديد' },
    { message: errors.accountsCursor, href: pairHref(), label: 'العودة إلى أول صفحة للأرصدة' },
    { message: errors.kind, href: pairHref(), label: 'مسح نوع حركة الرصيد' },
    { message: errors.period, href: pairHref({ kind: query.kind }), label: 'اختيار الفترة من جديد' },
    { message: errors.periodsCursor, href: pairHref({ kind: query.kind }), label: 'العودة إلى أول صفحة للفترات' },
    { message: errors.type, href: pairHref(selectedPeriodQuery), label: 'اختيار النوع من جديد' },
    { message: errors.typesCursor, href: pairHref(selectedPeriodQuery),
      label: 'العودة إلى أول صفحة للأنواع' },
  ].filter((entry) => entry.message !== '');

  return <PageFrame footer="الموارد البشرية">
    <PageHeader title={<>أرصدة الإجازات</>} eyebrow={<>الموارد البشرية</>} description={<>ابحث عن الموظف بالاسم أو رمزه، ثم اختر جهة عمله لعرض أرصدة حساباته كاملة
          وسجل حساب كل رصيد.</>} action={<><div className="workspace-form-actions">
        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave`}>طلبات الإجازة</PendingLink>
        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}`}>مساحة الشركة</PendingLink>
      </div></>} />
    {!access.newWorkEnabled && <Message tone="info"  role="status">
      خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا تُقبل حركات رصيد جديدة.
      تبقى عرض الأرصدة وسجل الحساب متاحًا.
    </Message>}

    {queryAlerts.length > 0 && <Panel  aria-label="تنبيهات روابط الصفحة">
      {queryAlerts.map((entry) => <Message tone="bad" key={entry.label}
         role="alert">{entry.message}{' '}
        <PendingLink href={entry.href}>{entry.label}</PendingLink></Message>)}
    </Panel>}

    <Panel  aria-labelledby="balances-search-title">
      <div className={styles.panelHeading}>
        <h2 id="balances-search-title">البحث عن موظف</h2>
        <p>اكتب من 2 إلى 80 حرفًا لعرض حتى {PAGE_SIZE} موظفًا مطابقًا، ثم اختر الموظف وجهة عمله.</p>
      </div>
      <form className="auth-form" method="get" action={path}>
        <Field id="balance-search" label={<>اسم الموظف أو رمزه</>}><Input id="balance-search" key={query.q} name="q" type="search" defaultValue={query.q} minLength={2}
          maxLength={80} autoComplete="off" placeholder="مثال: أحمد أو E-1042" /></Field>
        <div className="workspace-form-actions">
          <Button variant="solid"  type="submit">بحث</Button>
          {query.q !== '' && <PendingLink className="ui-button ui-button-ghost ui-button-md" href={searchHref()}>مسح البحث</PendingLink>}
        </div>
      </form>
      {errors.q !== '' && <Message tone="bad"  role="alert">{errors.q}</Message>}

      {query.q !== '' && (errors.q === '' ? <>
        {optionsResult && optionsResult.error
          ? <div role="alert"><EmptyState title={<>تعذّر تنفيذ البحث عن الموظفين</>} description={<>لم يتغير أي شيء. أعد المحاولة أو امسح البحث.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
              href={searchHref({ q: query.q })}>إعادة المحاولة</PendingLink></>} /></div>
          : options === null
            ? <div role="alert"><EmptyState title={<>تعذّر قراءة نتائج البحث</>} description={<>لم يتغير أي شيء. أعد المحاولة أو عُد إلى أول صفحة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={searchHref({ q: query.q })}>إعادة المحاولة</PendingLink></>} /></div>
            : options.items.length === 0
              ? <div ><EmptyState title={<>لا يوجد موظف مطابق</>} description={<>لم يعثر النظام على موظف يطابق «{query.q}». تحقق من الرمز أو جزء من الاسم.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={searchHref()}>مسح البحث</PendingLink></>} /></div>
              : <>
                <ul className="record-list">{options.items.map((item) => <RecordCard
                  key={`${item.employeeId}:${item.employerId}`}>
                  <div className="record-main">
                    <div className="record-title-row">
                      <h3>{item.employeeName}</h3>
                      <Badge className={`entity-status ${item.employerIsActive ? 'is-active' : 'is-inactive'}`}>
                        {employerStatusLabel(item)}</Badge>
                    </div>
                    <p className="record-meta">رقم الموظف: <bdi>{item.employeeCode}</bdi> · جهة العمل: {item.employerName}</p>
                    <p className="record-meta">{employmentStatusLabel(item)}</p>
                  </div>
                  <PendingLink className="ui-button ui-button-ghost ui-button-md"
                    href={searchHref({ q: query.q, employee: item.employeeId, employer: item.employerId })}>
                    عرض الأرصدة</PendingLink>
                </RecordCard>)}</ul>
                <nav className={styles.pagination} aria-label="صفحات نتائج البحث">
                  <span>حتى {PAGE_SIZE} موظفًا في الصفحة</span>
                  <span className={styles.paginationNav}>
                    {query.sc !== '' && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                      href={searchHref({ q: query.q })}>أول صفحة</PendingLink>}
                    {options.hasMore && options.next && <PendingLink className="ui-button ui-button-solid ui-button-md"
                      href={searchHref({ q: query.q, sc: options.next.code, se: options.next.employee, so: options.next.employer })}>
                      التالي</PendingLink>}
                  </span>
                </nav>
              </>}
      </> : null)}
    </Panel>

    {hasPair && (accountsResult && accountsResult.error && readFailure(accountsResult.error.code) === 'denied'
      ? <Panel  aria-label="غير مصرح بعرض الأرصدة">
        <div role="alert"><EmptyState title={<>لا تملك صلاحية عرض أرصدة هذا الموظف</>} description={<>لا تملك صلاحية عرض أرصدة الموظف لدى جهة العمل المختارة. راجع إدارة الموارد البشرية.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={searchHref({ q: query.q })}>اختيار موظف آخر</PendingLink></>} /></div>
      </Panel>
      : accountsResult && accountsResult.error
        ? <Panel  aria-label="خطأ في تحميل الأرصدة">
          <div role="alert"><EmptyState title={<>تعذّر تحميل أرصدة هذا الموظف</>} description={<>لم يتغير أي رصيد. {readFailure(accountsResult.error.code) === 'scope'
              ? 'الموظف أو جهة العمل المختارة غير متاحين لحسابك.'
              : 'أعد المحاولة أو اختر الموظف من جديد.'}</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={pairHref()}>إعادة المحاولة</PendingLink></>} /></div>
        </Panel>
        : accounts === null
          ? <Panel  aria-label="خطأ في قراءة الأرصدة">
            <div role="alert"><EmptyState title={<>تعذّر قراءة بيانات الأرصدة</>} description={<>لم يتغير أي رصيد. أعد المحاولة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={pairHref()}>إعادة المحاولة</PendingLink></>} /></div>
          </Panel>
          : <>
            <Panel  aria-labelledby="balances-pair-title">
              <div className={styles.panelHeading}>
                <h2 id="balances-pair-title">{pair?.employeeName}</h2>
                <p>رقم الموظف: <bdi>{pair?.employeeCode}</bdi> · جهة العمل: {pair?.employerName}
                  {' · '}{pair ? employmentStatusLabel(pair) : ''}{pair ? ` · ${employerStatusLabel(pair)}` : ''}</p>
              </div>
              {accounts.items.length === 0
                ? <div ><EmptyState title={<>لا توجد أرصدة مسجلة لهذا الموظف لدى جهة العمل المختارة</>} description={<>لم يُفتح حساب رصيد لهذا الموظف حتى الآن. يُفتح الحساب عند أول عملية تحتاج إلى حساب رصيد.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md" href={searchHref({ q: query.q })}>اختيار موظف آخر</PendingLink></>} /></div>
                : <>
                  <ul className="record-list">{accounts.items.map((account) => <RecordCard
                    key={account.accountId}>
                    <div className="record-main">
                      <div className="record-title-row">
                        <h3>{account.typeName}</h3>
                        <Badge className={`entity-status ${account.typeIsActive ? 'is-active' : 'is-inactive'}`}>
                          {account.typeIsActive ? 'النوع مفعّل' : 'النوع غير مفعّل'}</Badge>
                      </div>
                      <p className="record-meta">الرصيد الحالي: <bdi>{formatDays(account.balanceDays)}</bdi> يوم
                        · الفترة: {account.periodLabel} · من <bdi>{account.startsOn}</bdi> إلى <bdi>{account.endsOn}</bdi></p>
                      <p className="record-meta">رقم النوع: <bdi>{account.typeCode}</bdi>
                        {' · '}رصيد افتتاحي: {account.hasOpening ? 'مُسجّل' : 'غير مسجل'}
                        {' · '}استحقاق الإجازة السنوية: {account.hasAnnualGrant ? 'مسجل' : 'غير مسجل'}</p>
                      <p className="record-meta">الرصيد يشمل جميع حركات الحساب، بما فيها الحركات الموجودة في الصفحات الأخرى.</p>
                    </div>
                    {pair?.canAdjust && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                      href={`${pairHref({ kind: 'adjustment', period: account.periodId, type: account.leaveTypeId, acs: query.acs, aca: query.aca })}#balances-type-title`}>
                      تعديل هذا الرصيد</PendingLink>}
                    <PendingLink className="ui-button ui-button-ghost ui-button-md"
                      href={ledgerHref(tenantId, account.accountId, {
                        employee: query.employee, employer: query.employer,
                      })}>سجل الحساب</PendingLink>
                  </RecordCard>)}</ul>
                  <nav className={styles.pagination} aria-label="صفحات حسابات الرصيد">
                    <span>حتى {PAGE_SIZE} حسابًا في الصفحة</span>
                    <span className={styles.paginationNav}>
                      {query.acs !== '' && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                        href={pairHref()}>أول صفحة</PendingLink>}
                      {accounts.hasMore && accounts.next && <PendingLink className="ui-button ui-button-solid ui-button-md"
                        href={pairHref({ acs: accounts.next.start, aca: accounts.next.id })}>التالي</PendingLink>}
                    </span>
                  </nav>
                </>}
            </Panel>

            {pair && !pair.canAdjust
              ? <Message tone="info"  role="status">
                عرض الأرصدة متاح لحسابك، لكن تسجيل حركات الرصيد يتطلب صلاحية تعديل أرصدة الإجازات.
                راجع إدارة الموارد البشرية.
              </Message>
              : pair && !pair.canPost
                ? <Message tone="info"  role="status">{blockedReasonLabel(pair.postingBlockedReason, false)}</Message>
                : null}

            {canPost && pair && query.kind === ''
              ? <Panel  aria-labelledby="balances-kind-title">
                <div className={styles.panelHeading}>
                  <h2 id="balances-kind-title">تسجيل حركة رصيد</h2>
                  <p>اختر نوع الحركة وأدخل عدد الأيام المعتمد لدى الشركة. لا يُحسب الرصيد أو الاستحقاق تلقائيًا من تاريخ التعيين.</p>
                </div>
                <ul className="record-list">{(['opening', 'annual_grant', 'adjustment'] as PostingKind[])
                  .map((kind) => <RecordCard  key={kind}>
                    <div className="record-main">
                      <div className="record-title-row"><h3>{postingKindLabel(kind)}</h3></div>
                      <p className="record-meta">{kind === 'opening' ? 'حركة واحدة فقط لكل حساب حتى لو تغيّرت نسخة السياسة.'
                        : kind === 'annual_grant' ? 'استحقاق سنوي واحد فقط لكل حساب. أدخل عدد الأيام يدويًا.'
                          : 'إضافة أيام إلى الرصيد أو خصم أيام منه.'}</p>
                    </div>
                    <PendingLink className="ui-button ui-button-ghost ui-button-md" href={pairHref({ kind })}>اختيار</PendingLink>
                  </RecordCard>)}</ul>
              </Panel>
              : null}

            {canPost && pair && query.kind !== '' && <>
              <Panel  aria-labelledby="balances-period-title">
                <div className={styles.panelHeading}>
                  <h2 id="balances-period-title">فترة الحركة · {postingKindLabel(query.kind as PostingKind)}</h2>
                  <p>اختر الفترة من قائمة الفترات المخزّنة، كل فترة مرتّبة بتاريخ بدايتها.</p>
                </div>
                {periodsResult && periodsResult.error
                  ? <div role="alert"><EmptyState title={<>تعذّر تحميل فترات الإجازات</>} description={<>لم يتغير أي شيء. أعد المحاولة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                      href={pairHref(selectedTypeQuery)}>إعادة المحاولة</PendingLink></>} /></div>
                  : periods === null
                    ? <div role="alert"><EmptyState title={<>تعذّر قراءة قائمة الفترات</>} description={<>لم يتغير أي شيء. أعد المحاولة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                        href={pairHref({ kind: query.kind })}>إعادة المحاولة</PendingLink></>} /></div>
                    : query.period !== ''
                      ? <Card ><div className="record-main">
                        <div className="record-title-row">
                          <h3>{selectedPeriod ? selectedPeriod.label : 'الفترة المحددة'}</h3>
                          <Badge className="is-active">محددة</Badge>
                        </div>
                        <p className="record-meta">{selectedPeriod
                          ? <>من <bdi>{selectedPeriod.startsOn}</bdi> إلى <bdi>{selectedPeriod.endsOn}</bdi></>
                          : <>معرّف الفترة: <bdi>{query.period}</bdi></>}</p>
                        <p className="record-meta">اختر فترة أخرى لعرض الأنواع المتاحة فيها.</p>
                      </div><PendingLink className="ui-button ui-button-ghost ui-button-md"
                        href={pairHref({ kind: query.kind })}>تغيير الفترة</PendingLink></Card>
                      : periods.items.length === 0
                        ? <div ><EmptyState title={<>لا توجد فترات إجازات متاحة</>} description={<>لم تُعرَّف أي فترة إجازات يمكن ربط حركة الرصيد بها.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                            href={pairHref()}>مسح نوع حركة الرصيد</PendingLink></>} /></div>
                        : <>
                          <ul className="record-list">{periods.items.map((period) => <RecordCard
                            key={period.periodId}>
                            <div className="record-main">
                              <div className="record-title-row"><h3>{period.label}</h3></div>
                              <p className="record-meta">من <bdi>{period.startsOn}</bdi> إلى <bdi>{period.endsOn}</bdi></p>
                            </div>
                            <PendingLink className="ui-button ui-button-ghost ui-button-md"
                              href={pairHref({ kind: query.kind, period: period.periodId, pcs: query.pcs, pcp: query.pcp })}>اختيار الفترة</PendingLink>
                          </RecordCard>)}</ul>
                          <nav className={styles.pagination} aria-label="صفحات فترات الحركة">
                            <span>حتى {PAGE_SIZE} فترة في الصفحة</span>
                            <span className={styles.paginationNav}>
                              {query.pcs !== '' && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                                href={pairHref({ kind: query.kind })}>أول صفحة</PendingLink>}
                              {periods.hasMore && periods.next && <PendingLink className="ui-button ui-button-solid ui-button-md"
                                href={pairHref({ kind: query.kind, pcs: periods.next.start, pcp: periods.next.id })}>
                                التالي</PendingLink>}
                            </span>
                          </nav>
                        </>}
              </Panel>

              {query.period !== '' && <Panel  aria-labelledby="balances-type-title">
                <div className={styles.panelHeading}>
                  <h2 id="balances-type-title">نوع الإجازة</h2>
                  <p>اختر نوع الإجازة داخل الفترة المحددة. الأنواع التي لا يمكن تسجيل حركة رصيد لها تُعرض بحالتها دون رابط.</p>
                </div>
                {typesResult && typesResult.error
                  ? <div role="alert"><EmptyState title={<>تعذّر تحميل أنواع الإجازات</>} description={<>لم يتغير أي شيء. {readFailure(typesResult.error.code) === 'scope'
                      ? 'الفترة المختارة لا تخص جهة العمل المحددة.'
                      : 'أعد المحاولة.'}</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                      href={readFailure(typesResult.error.code) === 'scope'
                        ? pairHref({ kind: query.kind }) : pairHref(selectedTypeQuery)}>
                      {readFailure(typesResult.error.code) === 'scope' ? 'اختيار فترة أخرى' : 'إعادة المحاولة'}
                    </PendingLink></>} /></div>
                  : types === null
                    ? <div role="alert"><EmptyState title={<>تعذّر قراءة قائمة الأنواع</>} description={<>لم يتغير أي شيء. أعد المحاولة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                        href={pairHref(selectedTypeQuery)}>إعادة المحاولة</PendingLink></>} /></div>
                    : query.type !== ''
                      ? <>{query.kind === 'annual_grant' && pair?.canAdjust && <PendingLink className="ui-button ui-button-solid ui-button-md"
                        href={`/tenant/${tenantId}/leave/balances/annual?employee=${query.employee}&employer=${query.employer}&type=${query.type}&period=${query.period}`}>
                        حساب الاستحقاق السنوي تلقائيًا</PendingLink>}{postingForm}</>
                      : types.items.length === 0
                        ? <div ><EmptyState title={<>لا توجد أنواع إجازات في هذه الفترة</>} description={<>لم يُعرَّف أي نوع إجازة يمكن تسجيل حركة في رصيده في الفترة المحددة.</>} action={<><PendingLink className="ui-button ui-button-ghost ui-button-md"
                            href={pairHref({ kind: query.kind })}>تغيير الفترة</PendingLink></>} /></div>
                        : <>
                          <ul className="record-list">{types.items.map((item) => <RecordCard
                            key={item.leaveTypeId}>
                            <div className="record-main">
                              <div className="record-title-row">
                                <h3>{item.name}</h3>
                                <Badge className={`entity-status ${item.canPost ? 'is-active' : 'is-pending'}`}>
                                  {item.canPost ? 'يقبل حركة رصيد' : blockedReasonLabel(item.postingBlockedReason, false)}
                                </Badge>
                              </div>
                              <p className="record-meta">رقم النوع: <bdi>{item.code}</bdi>
                                {' · '}{item.isActive ? 'النوع مفعّل' : 'النوع غير مفعّل'}
                                {' · '}النسخة {item.typeVersion} سارية من <bdi>{item.effectiveFrom}</bdi></p>
                              <p className="record-meta">الرصيد الحالي لهذا النوع:
                                {' '}<bdi>{formatDays(item.balanceDays)}</bdi> يوم
                                {' · '}تاريخ الاستحقاق <bdi>{item.policyDate}</bdi></p>
                            </div>
                            {item.canPost
                              ? <PendingLink className="ui-button ui-button-ghost ui-button-md"
                                href={pairHref({
                                  kind: query.kind, period: query.period, type: item.leaveTypeId,
                                  tcs: query.tcs, tct: query.tct, pcs: query.pcs, pcp: query.pcp,
                                })}>اختيار النوع</PendingLink>
                              : <span className="ui-button ui-button-ghost ui-button-md" aria-disabled="true">غير متاح</span>}
                          </RecordCard>)}</ul>
                          <nav className={styles.pagination} aria-label="صفحات أنواع الحركة">
                            <span>حتى {PAGE_SIZE} نوعًا في الصفحة</span>
                            <span className={styles.paginationNav}>
                              {query.tcs !== '' && <PendingLink className="ui-button ui-button-ghost ui-button-md"
                                href={pairHref(selectedPeriodQuery)}>
                                أول صفحة</PendingLink>}
                              {types.hasMore && types.next && <PendingLink className="ui-button ui-button-solid ui-button-md"
                                href={pairHref({
                                  ...selectedPeriodQuery,
                                  tcs: types.next.code, tct: types.next.id,
                                })}>التالي</PendingLink>}
                            </span>
                          </nav>
                        </>}
                {types === null && postingForm}
              </Panel>}
            </>}
          </>)}

    <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/leave`}>العودة إلى طلبات الإجازة</PendingLink>
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
