import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
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
  const { data: { user } } = await supabase.auth.getUser();
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
  const optionsResult = query.q === '' ? null
    : await supabase.rpc('leave_balance_employee_options', {
      p_tenant: tenantId,
      p_query: query.q,
      p_limit: PAGE_SIZE,
      p_after_code: query.sc === '' ? null : query.sc,
      p_after_employee: query.se === '' ? null : query.se,
      p_after_employer: query.so === '' ? null : query.so,
    });
  const options = optionsResult && !optionsResult.error ? readOptionsPage(optionsResult.data) : null;

  const hasPair = query.employee !== '' && errors.pair === '';
  const accountsResult = !hasPair ? null
    : await supabase.rpc('leave_balance_accounts', {
      p_tenant: tenantId,
      p_employee: query.employee,
      p_employer: query.employer,
      p_limit: PAGE_SIZE,
      p_after_period_start: query.acs === '' ? null : query.acs,
      p_after_account: query.aca === '' ? null : query.aca,
    });
  const accounts = accountsResult && !accountsResult.error ? readAccountsPage(accountsResult.data) : null;
  const pair = accounts?.pair ?? null;
  const canPost = pair !== null && pair.canAdjust;
  const accountContext = query.kind === 'adjustment' ? accounts?.items.find((account) =>
    account.periodId === query.period && account.leaveTypeId === query.type) ?? null : null;

  const periodsResult = !canPost || query.kind === '' ? null
    : await supabase.rpc('leave_balance_posting_periods', {
      p_tenant: tenantId,
      p_employee: query.employee,
      p_employer: query.employer,
      p_limit: PAGE_SIZE,
      p_after_start: query.pcs === '' ? null : query.pcs,
      p_after_period: query.pcp === '' ? null : query.pcp,
    });
  const periods = periodsResult && !periodsResult.error ? readPeriodsPage(periodsResult.data) : null;
  const selectedPeriod = query.period === '' ? null
    : periods?.items.find((item) => item.periodId === query.period)
      ?? (accountContext ? { label: accountContext.periodLabel, startsOn: accountContext.startsOn, endsOn: accountContext.endsOn } : null);

  let typesResult = !canPost || query.kind === '' || query.period === '' ? null
    : await supabase.rpc('leave_balance_posting_types', {
      p_tenant: tenantId,
      p_employee: query.employee,
      p_employer: query.employer,
      p_kind: query.kind,
      p_period: query.period,
      p_limit: PAGE_SIZE,
      p_after_code: query.tcs === '' ? null : query.tcs,
      p_after_type: query.tct === '' ? null : query.tct,
    });
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
    { message: errors.kind, href: pairHref(), label: 'مسح نوع القيد' },
    { message: errors.period, href: pairHref({ kind: query.kind }), label: 'اختيار الفترة من جديد' },
    { message: errors.periodsCursor, href: pairHref({ kind: query.kind }), label: 'العودة إلى أول صفحة للفترات' },
    { message: errors.type, href: pairHref(selectedPeriodQuery), label: 'اختيار النوع من جديد' },
    { message: errors.typesCursor, href: pairHref(selectedPeriodQuery),
      label: 'العودة إلى أول صفحة للأنواع' },
  ].filter((entry) => entry.message !== '');

  return <PageFrame footer="الموارد البشرية">
    <header className="workspace-page-heading">
      <div>
        <p className="eyebrow">الموارد البشرية</p>
        <h1>أرصدة الإجازات</h1>
        <p>ابحث عن الموظف بالاسم أو رمزه، ثم اختر جهة عمله لعرض أرصدة حساباته كاملة
          وسجل حساب كل رصيد.</p>
      </div>
      <div className="workspace-form-actions">
        <PendingLink className="secondary-button" href={`/tenant/${tenantId}/leave`}>طلبات الإجازة</PendingLink>
        <PendingLink className="secondary-button" href={`/tenant/${tenantId}`}>مساحة الشركة</PendingLink>
      </div>
    </header>
    {!access.newWorkEnabled && <p className="form-message" role="status">
      خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا تُقبل قيود رصيد جديدة.
      تبقى عرض الأرصدة وسجل الحساب متاحًا.
    </p>}

    {queryAlerts.length > 0 && <section className="workspace-records-panel" aria-label="تنبيهات روابط الصفحة">
      {queryAlerts.map((entry) => <p key={entry.label}
        className="form-message form-error" role="alert">{entry.message}{' '}
        <PendingLink href={entry.href}>{entry.label}</PendingLink></p>)}
    </section>}

    <section className="workspace-records-panel" aria-labelledby="balances-search-title">
      <div className={styles.panelHeading}>
        <h2 id="balances-search-title">البحث عن موظف</h2>
        <p>اكتب من 2 إلى 80 حرفًا لعرض حتى {PAGE_SIZE} موظفًا مطابقًا، ثم اختر الموظف وجهة عمله.</p>
      </div>
      <form className="auth-form" method="get" action={path}>
        <label htmlFor="balance-search">اسم الموظف أو رمزه</label>
        <input id="balance-search" key={query.q} name="q" type="search" defaultValue={query.q} minLength={2}
          maxLength={80} autoComplete="off" placeholder="مثال: أحمد أو E-1042" />
        <div className="workspace-form-actions">
          <button className="primary-button" type="submit">بحث</button>
          {query.q !== '' && <PendingLink className="secondary-button" href={searchHref()}>مسح البحث</PendingLink>}
        </div>
      </form>
      {errors.q !== '' && <p className="form-message form-error" role="alert">{errors.q}</p>}

      {query.q !== '' && (errors.q === '' ? <>
        {optionsResult && optionsResult.error
          ? <div className="empty-state" role="alert">
            <h2>تعذّر تنفيذ البحث عن الموظفين</h2>
            <p>لم يتغير أي شيء. أعد المحاولة أو امسح البحث.</p>
            <PendingLink className="secondary-button"
              href={searchHref({ q: query.q })}>إعادة المحاولة</PendingLink>
          </div>
          : options === null
            ? <div className="empty-state" role="alert">
              <h2>تعذّر قراءة نتائج البحث</h2>
              <p>لم يتغير أي شيء. أعد المحاولة أو عُد إلى أول صفحة.</p>
              <PendingLink className="secondary-button" href={searchHref({ q: query.q })}>إعادة المحاولة</PendingLink>
            </div>
            : options.items.length === 0
              ? <div className="empty-state">
                <h2>لا يوجد موظف مطابق</h2>
                <p>لم يعثر النظام على موظف يطابق «{query.q}». تحقق من الرمز أو جزء من الاسم.</p>
                <PendingLink className="secondary-button" href={searchHref()}>مسح البحث</PendingLink>
              </div>
              : <>
                <ul className="record-list">{options.items.map((item) => <li className="record-card"
                  key={`${item.employeeId}:${item.employerId}`}>
                  <div className="record-main">
                    <div className="record-title-row">
                      <h3>{item.employeeName}</h3>
                      <span className={`entity-status ${item.employerIsActive ? 'is-active' : 'is-inactive'}`}>
                        {employerStatusLabel(item)}</span>
                    </div>
                    <p className="record-meta">رقم الموظف: <bdi>{item.employeeCode}</bdi> · جهة العمل: {item.employerName}</p>
                    <p className="record-meta">{employmentStatusLabel(item)}</p>
                  </div>
                  <PendingLink className="secondary-button"
                    href={searchHref({ q: query.q, employee: item.employeeId, employer: item.employerId })}>
                    عرض الأرصدة</PendingLink>
                </li>)}</ul>
                <nav className={styles.pagination} aria-label="صفحات نتائج البحث">
                  <span>حتى {PAGE_SIZE} موظفًا في الصفحة</span>
                  <span className={styles.paginationNav}>
                    {query.sc !== '' && <PendingLink className="secondary-button"
                      href={searchHref({ q: query.q })}>أول صفحة</PendingLink>}
                    {options.hasMore && options.next && <PendingLink className="primary-button"
                      href={searchHref({ q: query.q, sc: options.next.code, se: options.next.employee, so: options.next.employer })}>
                      التالي</PendingLink>}
                  </span>
                </nav>
              </>}
      </> : null)}
    </section>

    {hasPair && (accountsResult && accountsResult.error && readFailure(accountsResult.error.code) === 'denied'
      ? <section className="workspace-records-panel" aria-label="غير مصرح بعرض الأرصدة">
        <div className="empty-state" role="alert">
          <h2>لا تملك صلاحية عرض أرصدة هذا الموظف</h2>
          <p>لا تملك صلاحية عرض أرصدة الموظف لدى جهة العمل المختارة. راجع إدارة الموارد البشرية.</p>
          <PendingLink className="secondary-button" href={searchHref({ q: query.q })}>اختيار موظف آخر</PendingLink>
        </div>
      </section>
      : accountsResult && accountsResult.error
        ? <section className="workspace-records-panel" aria-label="خطأ في تحميل الأرصدة">
          <div className="empty-state" role="alert">
            <h2>تعذّر تحميل أرصدة هذا الموظف</h2>
            <p>لم يتغير أي رصيد. {readFailure(accountsResult.error.code) === 'scope'
              ? 'الموظف أو جهة العمل المختارة غير متاحين لحسابك.'
              : 'أعد المحاولة أو اختر الموظف من جديد.'}</p>
            <PendingLink className="secondary-button" href={pairHref()}>إعادة المحاولة</PendingLink>
          </div>
        </section>
        : accounts === null
          ? <section className="workspace-records-panel" aria-label="خطأ في قراءة الأرصدة">
            <div className="empty-state" role="alert">
              <h2>تعذّر قراءة بيانات الأرصدة</h2>
              <p>لم يتغير أي رصيد. أعد المحاولة.</p>
              <PendingLink className="secondary-button" href={pairHref()}>إعادة المحاولة</PendingLink>
            </div>
          </section>
          : <>
            <section className="workspace-records-panel" aria-labelledby="balances-pair-title">
              <div className={styles.panelHeading}>
                <h2 id="balances-pair-title">{pair?.employeeName}</h2>
                <p>رقم الموظف: <bdi>{pair?.employeeCode}</bdi> · جهة العمل: {pair?.employerName}
                  {' · '}{pair ? employmentStatusLabel(pair) : ''}{pair ? ` · ${employerStatusLabel(pair)}` : ''}</p>
              </div>
              {accounts.items.length === 0
                ? <div className="empty-state">
                  <h2>لا توجد أرصدة مسجلة لهذا الموظف لدى جهة العمل المختارة</h2>
                  <p>لم يُفتح حساب رصيد لهذا الموظف حتى الآن. يُفتح الحساب عند أول عملية تحتاج إلى حساب رصيد.</p>
                  <PendingLink className="secondary-button" href={searchHref({ q: query.q })}>اختيار موظف آخر</PendingLink>
                </div>
                : <>
                  <ul className="record-list">{accounts.items.map((account) => <li className="record-card"
                    key={account.accountId}>
                    <div className="record-main">
                      <div className="record-title-row">
                        <h3>{account.typeName}</h3>
                        <span className={`entity-status ${account.typeIsActive ? 'is-active' : 'is-inactive'}`}>
                          {account.typeIsActive ? 'النوع مفعّل' : 'النوع غير مفعّل'}</span>
                      </div>
                      <p className="record-meta">الرصيد الحالي: <bdi>{formatDays(account.balanceDays)}</bdi> يوم
                        · الفترة: {account.periodLabel} · من <bdi>{account.startsOn}</bdi> إلى <bdi>{account.endsOn}</bdi></p>
                      <p className="record-meta">رقم النوع: <bdi>{account.typeCode}</bdi>
                        {' · '}رصيد افتتاحي: {account.hasOpening ? 'مُسجّل' : 'غير مسجل'}
                        {' · '}منحة سنوية: {account.hasAnnualGrant ? 'مسجلة' : 'غير مسجلة'}</p>
                      <p className="record-meta">الرصيد يشمل جميع حركات الحساب، بما فيها الحركات الموجودة في الصفحات الأخرى.</p>
                    </div>
                    {pair?.canAdjust && <PendingLink className="secondary-button"
                      href={`${pairHref({ kind: 'adjustment', period: account.periodId, type: account.leaveTypeId, acs: query.acs, aca: query.aca })}#balances-type-title`}>
                      تعديل هذا الرصيد</PendingLink>}
                    <PendingLink className="secondary-button"
                      href={ledgerHref(tenantId, account.accountId, {
                        employee: query.employee, employer: query.employer,
                      })}>سجل الحساب</PendingLink>
                  </li>)}</ul>
                  <nav className={styles.pagination} aria-label="صفحات حسابات الرصيد">
                    <span>حتى {PAGE_SIZE} حسابًا في الصفحة</span>
                    <span className={styles.paginationNav}>
                      {query.acs !== '' && <PendingLink className="secondary-button"
                        href={pairHref()}>أول صفحة</PendingLink>}
                      {accounts.hasMore && accounts.next && <PendingLink className="primary-button"
                        href={pairHref({ acs: accounts.next.start, aca: accounts.next.id })}>التالي</PendingLink>}
                    </span>
                  </nav>
                </>}
            </section>

            {pair && !pair.canAdjust
              ? <p className="form-message" role="status">
                عرض الأرصدة متاح لحسابك، لكن تسجيل قيود الرصيد يتطلب صلاحية تعديل أرصدة الإجازات.
                راجع إدارة الموارد البشرية.
              </p>
              : pair && !pair.canPost
                ? <p className="form-message" role="status">{blockedReasonLabel(pair.postingBlockedReason, false)}</p>
                : null}

            {canPost && pair && query.kind === ''
              ? <section className="workspace-records-panel" aria-labelledby="balances-kind-title">
                <div className={styles.panelHeading}>
                  <h2 id="balances-kind-title">تسجيل قيد رصيد</h2>
                  <p>اختر نوع القيد المطلوب. لا تحتسب الواجهة أي منحة ولا رصيدًا افتتاحيًا من تاريخ الالتحاق
                    ولا تفترض قيمًا؛ أدخل عدد الأيام يدويًا. نتحقق من صلاحيتك عند الإرسال.</p>
                </div>
                <ul className="record-list">{(['opening', 'annual_grant', 'adjustment'] as PostingKind[])
                  .map((kind) => <li className="record-card" key={kind}>
                    <div className="record-main">
                      <div className="record-title-row"><h3>{postingKindLabel(kind)}</h3></div>
                      <p className="record-meta">{kind === 'opening' ? 'قيد واحد فقط لكل حساب حتى لو تغيّرت نسخة السياسة.'
                        : kind === 'annual_grant' ? 'منحة واحدة فقط لكل حساب. أدخل عدد الأيام يدويًا.'
                          : 'إضافة أيام إلى الرصيد أو خصم أيام منه.'}</p>
                    </div>
                    <PendingLink className="secondary-button" href={pairHref({ kind })}>اختيار</PendingLink>
                  </li>)}</ul>
              </section>
              : null}

            {canPost && pair && query.kind !== '' && <>
              <section className="workspace-records-panel" aria-labelledby="balances-period-title">
                <div className={styles.panelHeading}>
                  <h2 id="balances-period-title">فترة القيد · {postingKindLabel(query.kind as PostingKind)}</h2>
                  <p>اختر الفترة من قائمة الفترات المخزّنة، كل فترة مرتّبة بتاريخ بدايتها.</p>
                </div>
                {periodsResult && periodsResult.error
                  ? <div className="empty-state" role="alert">
                    <h2>تعذّر تحميل فترات الإجازات</h2>
                    <p>لم يتغير أي شيء. أعد المحاولة.</p>
                    <PendingLink className="secondary-button"
                      href={pairHref(selectedTypeQuery)}>إعادة المحاولة</PendingLink>
                  </div>
                  : periods === null
                    ? <div className="empty-state" role="alert">
                      <h2>تعذّر قراءة قائمة الفترات</h2>
                      <p>لم يتغير أي شيء. أعد المحاولة.</p>
                      <PendingLink className="secondary-button"
                        href={pairHref({ kind: query.kind })}>إعادة المحاولة</PendingLink>
                    </div>
                    : query.period !== ''
                      ? <div className="record-card"><div className="record-main">
                        <div className="record-title-row">
                          <h3>{selectedPeriod ? selectedPeriod.label : 'الفترة المحددة'}</h3>
                          <span className="entity-status is-active">محددة</span>
                        </div>
                        <p className="record-meta">{selectedPeriod
                          ? <>من <bdi>{selectedPeriod.startsOn}</bdi> إلى <bdi>{selectedPeriod.endsOn}</bdi></>
                          : <>معرّف الفترة: <bdi>{query.period}</bdi></>}</p>
                        <p className="record-meta">اختر فترة أخرى لعرض الأنواع المتاحة فيها.</p>
                      </div><PendingLink className="secondary-button"
                        href={pairHref({ kind: query.kind })}>تغيير الفترة</PendingLink></div>
                      : periods.items.length === 0
                        ? <div className="empty-state">
                          <h2>لا توجد فترات إجازات متاحة</h2>
                          <p>لم تُعرَّف أي فترة إجازات يمكن ربط قيد الرصيد بها.</p>
                          <PendingLink className="secondary-button"
                            href={pairHref()}>مسح نوع القيد</PendingLink>
                        </div>
                        : <>
                          <ul className="record-list">{periods.items.map((period) => <li className="record-card"
                            key={period.periodId}>
                            <div className="record-main">
                              <div className="record-title-row"><h3>{period.label}</h3></div>
                              <p className="record-meta">من <bdi>{period.startsOn}</bdi> إلى <bdi>{period.endsOn}</bdi></p>
                            </div>
                            <PendingLink className="secondary-button"
                              href={pairHref({ kind: query.kind, period: period.periodId, pcs: query.pcs, pcp: query.pcp })}>اختيار الفترة</PendingLink>
                          </li>)}</ul>
                          <nav className={styles.pagination} aria-label="صفحات فترات القيد">
                            <span>حتى {PAGE_SIZE} فترة في الصفحة</span>
                            <span className={styles.paginationNav}>
                              {query.pcs !== '' && <PendingLink className="secondary-button"
                                href={pairHref({ kind: query.kind })}>أول صفحة</PendingLink>}
                              {periods.hasMore && periods.next && <PendingLink className="primary-button"
                                href={pairHref({ kind: query.kind, pcs: periods.next.start, pcp: periods.next.id })}>
                                التالي</PendingLink>}
                            </span>
                          </nav>
                        </>}
              </section>

              {query.period !== '' && <section className="workspace-records-panel" aria-labelledby="balances-type-title">
                <div className={styles.panelHeading}>
                  <h2 id="balances-type-title">نوع الإجازة</h2>
                  <p>اختر نوع الإجازة داخل الفترة المحددة. الأنواع التي لا يقبل قيدها تُعرض بحالتها دون رابط.</p>
                </div>
                {typesResult && typesResult.error
                  ? <div className="empty-state" role="alert">
                    <h2>تعذّر تحميل أنواع الإجازات</h2>
                    <p>لم يتغير أي شيء. {readFailure(typesResult.error.code) === 'scope'
                      ? 'الفترة المختارة لا تخص جهة العمل المحددة.'
                      : 'أعد المحاولة.'}</p>
                    <PendingLink className="secondary-button"
                      href={readFailure(typesResult.error.code) === 'scope'
                        ? pairHref({ kind: query.kind }) : pairHref(selectedTypeQuery)}>
                      {readFailure(typesResult.error.code) === 'scope' ? 'اختيار فترة أخرى' : 'إعادة المحاولة'}
                    </PendingLink>
                  </div>
                  : types === null
                    ? <div className="empty-state" role="alert">
                      <h2>تعذّر قراءة قائمة الأنواع</h2>
                      <p>لم يتغير أي شيء. أعد المحاولة.</p>
                      <PendingLink className="secondary-button"
                        href={pairHref(selectedTypeQuery)}>إعادة المحاولة</PendingLink>
                    </div>
                    : query.type !== ''
                      ? <>{query.kind === 'annual_grant' && pair?.canAdjust && <PendingLink className="primary-button"
                        href={`/tenant/${tenantId}/leave/balances/annual?employee=${query.employee}&employer=${query.employer}&type=${query.type}&period=${query.period}`}>
                        حساب الاستحقاق السنوي تلقائيًا</PendingLink>}{postingForm}</>
                      : types.items.length === 0
                        ? <div className="empty-state">
                          <h2>لا توجد أنواع إجازات في هذه الفترة</h2>
                          <p>لم يُعرَّف أي نوع إجازة يمكن تسجيل قيده في الفترة المحددة.</p>
                          <PendingLink className="secondary-button"
                            href={pairHref({ kind: query.kind })}>تغيير الفترة</PendingLink>
                        </div>
                        : <>
                          <ul className="record-list">{types.items.map((item) => <li className="record-card"
                            key={item.leaveTypeId}>
                            <div className="record-main">
                              <div className="record-title-row">
                                <h3>{item.name}</h3>
                                <span className={`entity-status ${item.canPost ? 'is-active' : 'is-pending'}`}>
                                  {item.canPost ? 'يقبل قيدًا' : blockedReasonLabel(item.postingBlockedReason, false)}
                                </span>
                              </div>
                              <p className="record-meta">رقم النوع: <bdi>{item.code}</bdi>
                                {' · '}{item.isActive ? 'النوع مفعّل' : 'النوع غير مفعّل'}
                                {' · '}النسخة {item.typeVersion} سارية من <bdi>{item.effectiveFrom}</bdi></p>
                              <p className="record-meta">الرصيد الحالي لهذا النوع:
                                {' '}<bdi>{formatDays(item.balanceDays)}</bdi> يوم
                                {' · '}تاريخ الاستحقاق <bdi>{item.policyDate}</bdi></p>
                            </div>
                            {item.canPost
                              ? <PendingLink className="secondary-button"
                                href={pairHref({
                                  kind: query.kind, period: query.period, type: item.leaveTypeId,
                                  tcs: query.tcs, tct: query.tct, pcs: query.pcs, pcp: query.pcp,
                                })}>اختيار النوع</PendingLink>
                              : <span className="secondary-button" aria-disabled="true">غير متاح</span>}
                          </li>)}</ul>
                          <nav className={styles.pagination} aria-label="صفحات أنواع القيد">
                            <span>حتى {PAGE_SIZE} نوعًا في الصفحة</span>
                            <span className={styles.paginationNav}>
                              {query.tcs !== '' && <PendingLink className="secondary-button"
                                href={pairHref(selectedPeriodQuery)}>
                                أول صفحة</PendingLink>}
                              {types.hasMore && types.next && <PendingLink className="primary-button"
                                href={pairHref({
                                  ...selectedPeriodQuery,
                                  tcs: types.next.code, tct: types.next.id,
                                })}>التالي</PendingLink>}
                            </span>
                          </nav>
                        </>}
                {types === null && postingForm}
              </section>}
            </>}
          </>)}

    <PendingLink className="secondary-button" href={`/tenant/${tenantId}/leave`}>العودة إلى طلبات الإجازة</PendingLink>
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
