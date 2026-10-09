import { Button, ButtonLink, Disclosure, Input, Message, PageHeader, Panel, RecordCard, Select, Field } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import {EmployerSelector} from './EmployerSelector';
import {normalizeEmployerScope} from './employer-context';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { displayDate, uuid } from './rules';
import { issueNames, money, type Issue } from './runs/rules';
import styles from './payroll.module.css';
import { PayrollStepper, payrollCurrentStage } from './PayrollStepper';
import { issueTitles } from './issue-titles';
import { issueResponsibility } from './issue-responsibility';
import { Suspense } from 'react';
import { OvertimeNotice } from './OvertimeNotice';
import { RecordedPaymentNotice } from './RecordedPaymentNotice';

export const dynamic = 'force-dynamic';
type Query = Record<string, string | undefined>;
type Employer = { id: string; name: string };
type Period = { id: string; starts_on: string; ends_on: string; is_transition?: boolean };
type Calendar = { employer_name: string; versions: { timezone: string }[]; periods: { starts_on: string; ends_on: string; timezone: string }[]; access: { can_view: boolean; can_manage: boolean; enabled: boolean } };
type Workspace = {
  access: { can_prepare: boolean; can_configure?: boolean; can_view_final: boolean; can_payment_record: boolean; enabled: boolean };
  period: Period; run: { status: string } | null; final_output_id: string | null;
  summary: { employee_count: number; known_gross: string | null; deductions?: string | null; net?: string | null; gross_complete?: boolean; financially_qualified?: boolean } | null;
  global_issues: Issue[]; issue_count: number; stale_reasons: string[];
  stage_facts?: unknown; approval?: { ready?: unknown } | null;
};
export default async function PayrollPage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Promise<Query> }) {
  const { tenantId } = await params;
  if (!uuid(tenantId)) notFound();
  const query = await searchParams, path = `/tenant/${tenantId}/payroll`;
  const employerDestination=normalizeEmployerScope(path,'workspace',query);if(employerDestination)redirect(employerDestination);
  const kept = Object.fromEntries(Object.entries(query).filter((entry): entry is [string, string] => typeof entry[1] === 'string'));
  const retry = `${path}?${new URLSearchParams(kept)}`;
  const failure = (text: string) => <PageFrame><Panel dir="rtl" className={styles.card}><PageHeader  title={<>الرواتب</>} /><Message tone="bad" role="alert">{text}</Message><p>اختيارات الجهة والفترة محفوظة في الرابط.</p><ButtonLink variant="ghost"  href={retry}>إعادة المحاولة</ButtonLink></Panel></PageFrame>;
  if (['employer', 'period', 'after_id'].some(key => query[key] && !uuid(query[key]!)) || (query.q?.length ?? 0) > 120 || (query.review_q?.length ?? 0) > 120) return failure('راجع رابط الجهة والفترة وعبارة البحث.');
  if (query.stage === 'setup' || query.before) redirect(`${path}/setup?${new URLSearchParams(kept)}`);
  const client = await createSupabaseServerClient();
  if (!client) return failure('تعذر الاتصال ببيانات الرواتب.');
  const { data: { user } } = await client.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(retry)}`);
  const [access, navigation] = await Promise.all([client.rpc('payroll_access_snapshot', { p_tenant: tenantId }), client.rpc('payroll_navigation_access', { p_tenant: tenantId })]);
  if (access.error || !access.data) return failure(access.error?.code === '42501' ? 'هذا الحساب غير مخوّل للوصول إلى مساحة الرواتب. راجع مسؤول الشركة.' : 'تعذر تحميل صلاحيات الرواتب.');
  const found = await client.rpc('payroll_employers', { p_tenant: tenantId, p_query: query.q ?? '', p_after_name: query.after_name ?? null, p_after_id: query.after_id ?? null, p_limit: 30 });
  if (found.error || !Array.isArray(found.data?.items)) return failure('تعذر تحميل جهات العمل.');
  const employers = found.data.items as Employer[], employer = query.employer || found.data.unique_employer || '';
  const scope = (suffix: string, extra: Record<string, string> = {}) => `${path}${suffix}?${new URLSearchParams({ ...(employer ? { employer } : {}), ...(query.period ? { period: query.period } : {}), ...(query.review_q ? { q: query.review_q } : {}), ...extra })}`;
  if (!employer) return <PageFrame><div dir="rtl" className={styles.workspace}>
    <div><p className="eyebrow">مساحة الشركة · الرواتب</p><PageHeader  title={<>رواتب أي جهة ستراجع؟</>} description={<> لكل جهة دورة ومسيرات مستقلة. اختر الجهة للمتابعة. </>} /></div>
    <form method="get" className={styles.filters}><Field  id="payroll-employer-search" label={<>البحث عن جهة</>}><Input id="payroll-employer-search" name="q" maxLength={120} defaultValue={query.q ?? ''}/></Field><Button variant="ghost" type="submit" >بحث</Button></form>
    {employers.length ? <ul className={styles.periods}>{employers.map(item => <RecordCard className={styles.card} key={item.id}><Link href={`${path}?${new URLSearchParams({ employer: item.id })}`}>{item.name}</Link></RecordCard>)}</ul> : <p>لا توجد جهات مطابقة. عدّل البحث أو راجع مسؤول الشركة.</p>}
    {employers.length === 30 && <Link href={`${path}?${new URLSearchParams({ q: query.q ?? '', after_name: employers[29].name, after_id: employers[29].id })}`}>جهات إضافية</Link>}
  </div></PageFrame>;
  const loaded = await client.rpc('payroll_workspace', { p_tenant: tenantId, p_employer: employer, p_limit: 24 });
  if (loaded.error || !loaded.data) return failure('تعذر تحميل دورة الجهة.');
  const calendar = loaded.data as Calendar;
  const setupLink = scope('/setup', { q: query.q ?? '', ...(query.review_q ? { review_q: query.review_q } : {}) });
  let periods: Period[] = [], work: Workspace | null = null;
  if (calendar.access.can_view) {
    const result = await client.rpc('payroll_run_periods', { p_tenant: tenantId, p_employer: employer });
    if (result.error || !Array.isArray(result.data)) return failure('تعذر تحميل فترات الرواتب.');
    periods = result.data as Period[];
    const current = periods.find(item => {
      const saved = calendar.periods.find(boundary => boundary.starts_on === item.starts_on && boundary.ends_on === item.ends_on);
      if (!saved) return false;
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: saved.timezone }).format(new Date());
      return item.starts_on <= today && item.ends_on >= today;
    });
    const period = query.period || current?.id;
    if (period) {
      const state = await client.rpc('payroll_run_workspace', { p_tenant: tenantId, p_employer: employer, p_period: period, p_limit: 1, p_query: '', p_after: null, p_employee: null });
      if (state.error || !state.data) return failure('تعذر تحميل حالة المسير وجاهزيته.');
      work = state.data as Workspace;
    }
  }
  const periodId = work?.period.id ?? query.period ?? '', runLink = scope('/runs', { period: periodId }), inputsLink = scope('/inputs', { period: periodId });
  const sourceAction = (item: Issue) => {
    const review = { href: runLink, label: 'مراجعة المصدر في مسير الرواتب' };
    if (!work) return review;
    const input = (label: string, kind?: string) => ({
      href: scope('/inputs', { period: periodId, ...(query.review_q ? { review_q: query.review_q } : {}), ...(kind && uuid(item.employment_id ?? '') ? { kind, employee: item.employment_id! } : {}) }),
      label,
    });
    if (item.code.startsWith('payroll_deduction') && (work.access.can_prepare === true || calendar.access.can_view === true)) return input('مراجعة الخصومات المعتمدة');
    if (item.code === 'issued_labour_evidence_required') return review;
    if (item.owner === 'employee_finance' && !navigation.error && navigation.data?.can_view_advances === true) return { href: `${path}/advances?${new URLSearchParams({ employer })}`, label: 'مراجعة السلف ومسؤولياتها' };
    if (work.access.can_prepare === true && ['statutory_legal_duration_required', 'statutory_composition_context_mismatch', 'statutory_duration_outside_adapter', 'insurance_obligation_attribution_required', 'insurance_month_scope_required', 'insurance_pack_missing_or_ambiguous'].includes(item.code)) return input('مراجعة حقائق المدة القانونية', 'statutory_context');
    if (work.access.can_prepare === true && ['source_choice_required', 'source_choice_pending', 'source_time_disabled', 'source_leave_treatment_unknown', 'source_quantity_unknown', 'manual_units_ambiguous', 'approved_units_missing', 'units_exceed_eligibility', 'opening_ytd_unknown', 'opening_ytd_ambiguous', 'opening_tax_due_unknown', 'opening_tax_coverage_unknown', 'opening_tax_net_income_unknown', 'opening_ytd_after_final_requires_review', 'prior_ytd_coverage_gap', 'employee_statutory_context_missing', 'employee_statutory_context_ambiguous', 'recurring_overlap', 'daily_units_allocation_needed', 'daily_percentage_allocation_needed'].includes(item.code)) {
      if (item.code.startsWith('opening_') || item.code === 'prior_ytd_coverage_gap') return input('مراجعة الأرصدة السابقة');
      if (item.code.startsWith('employee_statutory_context_')) return input('مراجعة بيانات الضريبة والتأمينات');
      if (item.code === 'recurring_overlap') return input('مراجعة مكونات الموظف');
      return input('مراجعة الأيام المستحقة', 'manual_units');
    }
    if (item.code === 'policy_missing' && work.access.can_configure === true) return input('إعداد سياسة الشركة');
    return review;
  };
  const final = work?.run?.status === 'locked' || work?.run?.status === 'superseded', stale = Boolean(work?.stale_reasons.length);
  const candidate = Boolean(work?.run && work.run.status !== 'cancelled' && !final);
  const status = !work ? periods.length ? 'اختر الفترة التي تريد مراجعتها' : 'يلزم مراجعة الفترة المحفوظة' : !work.run || work.run.status === 'cancelled' ? 'لم يبدأ تحضير مسير لهذه الفترة' : work.run.status === 'superseded' ? 'مسير مستبدل محفوظ في التاريخ' : work.run.status === 'locked' ? 'مسير نهائي محفوظ' : stale ? 'تغيّرت بيانات تؤثر على المسير' : work.run.status === 'approved' ? 'مرشح معتمد' : work.run.status === 'review' ? 'مرشح قيد المراجعة' : work.run.status === 'draft' ? 'التحضير جارٍ' : 'حالة المسير تحتاج مراجعة';
  let primary = { href: setupLink, label: calendar.versions.length ? 'مراجعة الدورة والفترات' : 'إعداد دورة الرواتب' };
  if (work) {
    primary = { href: runLink, label: stale && work.access.can_prepare && work.access.enabled ? 'مراجعة وإعادة حساب الرواتب' : !work.run || work.run.status === 'cancelled' ? (work.access.can_prepare && work.access.enabled ? 'إعداد مسير الرواتب' : 'مراجعة الفترة') : 'متابعة مراجعة الرواتب' };
    if (work.run?.status === 'locked' && work.final_output_id) {
      if (work.access.can_payment_record) primary = { href: scope('/payments', { output: work.final_output_id }), label: 'مراجعة الدفعات والمتبقي' };
      else if (work.access.can_view_final) primary = { href: scope('/output', { output: work.final_output_id }), label: 'عرض المسير النهائي' };
    }
  }
  const primaryAction = (work || periods.length === 0) && <ButtonLink  href={primary.href}>{primary.label}</ButtonLink>;
  return <PageFrame><div dir="rtl" className={styles.workspace}>
    <div><p className="eyebrow">مساحة الشركة · الرواتب</p><PageHeader  title={<>الرواتب</>} description={<> {calendar.employer_name} </>} />

      <EmployerSelector path={path} page="workspace" employer={employer} name={calendar.employer_name} choices={employers} context={{...query,period:periodId}} singleEmployer={found.data.unique_employer===employer}/>
      <Link href={path}>اختيار جهة أخرى</Link>
      <p className="field-hint">للبحث أو عرض بقية الجهات، افتح اختيار جهة أخرى.</p>
    </div>
    {periods.length > 0 && <form method="get" className={styles.filters}><input type="hidden" name="employer" value={employer}/>{query.review_q && <input type="hidden" name="review_q" value={query.review_q}/>}
      <Field  id="payroll-period" label={<>فترة الرواتب</>}><Select id="payroll-period" name="period" defaultValue={periodId} required>
        {!periodId && <option value="" disabled>اختر فترة الرواتب</option>}
        {work && !periods.some(item => item.id === periodId) && <option value={periodId}>{displayDate(work.period.starts_on)} — {displayDate(work.period.ends_on)}</option>}
        {periods.map(item => <option key={item.id} value={item.id}>{displayDate(item.starts_on)} — {displayDate(item.ends_on)}</option>)}
      </Select></Field><Button variant={work ? "ghost" : "solid"} type="submit" className={work ? '' : ''}>عرض الفترة</Button></form>}
    {!calendar.access.enabled && <Message tone="info" role="status">خدمة الرواتب غير مفعلة لإجراءات جديدة. يمكنك متابعة التاريخ والالتزامات القائمة حسب صلاحياتك.</Message>}
    <Panel className={styles.card} aria-labelledby="payroll-stage"><h2 id="payroll-stage">{status}</h2>
      {work ? <p>{displayDate(work.period.starts_on)} — {displayDate(work.period.ends_on)}{work.period.is_transition ? ' · فترة انتقالية' : ''}</p> : <p>{periods.length ? 'لم تُحدَّد فترة حالية من التواريخ المحفوظة المعروضة. اختر فترة صراحةً؛ لن يبدأ التحضير في فترة مستقبلية تلقائيًا.' : calendar.access.can_view ? 'جهّز الدورة وفترتها الأولى، ثم ابدأ تحضير المدخلات.' : 'يمكنك مراجعة إعداد الدورة. مراجعة المسيرات تحتاج إلى مسؤول لديه صلاحية عرض الرواتب.'}</p>}
      {stale && <p>راجع المصادر المتغيرة وأعد الحساب قبل الاعتماد. القيم المعروضة محفوظة من الحساب السابق للمراجعة.</p>}
      {candidate && primaryAction}
      {candidate && work?.summary && <dl className={styles.figureStrip}><div><dt>علاقات التوظيف في المرشح</dt><dd>{new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE).format(work.summary.employee_count)}</dd></div><div><dt>{work.summary.gross_complete === true ? 'إجمالي الاستحقاقات التشغيلية' : 'الاستحقاقات المعروفة من المدخلات التي أمكن حسابها'}</dt><dd><bdi>{money(work.summary.known_gross)}</bdi></dd></div><div><dt>الخصومات التشغيلية المعروفة دون الضريبة والتأمينات</dt><dd><bdi>{money(work.summary.deductions)}</bdi></dd></div><div><dt>صافي الحساب المراجع</dt><dd>{!['draft','review','approved'].includes(work.run?.status ?? '') ? 'حالة الحساب تحتاج مراجعة قبل عرض الصافي' : stale ? 'أعد الحساب لعرض الصافي من المصادر الحالية' : work.summary.financially_qualified === true && work.summary.net != null ? <bdi>{money(work.summary.net)}</bdi> : 'يظهر بعد اكتمال التأهيل المالي لحزمة الضرائب والتأمينات.'}</dd></div></dl>}
      {candidate && work?.summary && <p>القيم مرشح للمراجعة، ولا تمثل راتبًا صالحًا للصرف قبل اكتمال التأهيل والاعتماد والتثبيت.</p>}
      {final && <p>{work?.run?.status === 'superseded' ? 'استُبدل هذا المسير. راجع المسير البديل قبل استخدام بيان الراتب أو تسجيل دفعة.' : work?.access.can_view_final || work?.access.can_payment_record ? 'المسير محفوظ. انتقل إلى تفاصيله لمراجعة المبالغ أو الدفعات والمتبقي حسب صلاحياتك.' : 'المسير محفوظ. مراجعة المبالغ والدفعات تحتاج إلى مسؤول مخوّل بعرض الرواتب أو تسجيل الدفعات.'}</p>}
      {!candidate && primaryAction}
      <PayrollStepper currentStage={payrollCurrentStage(work)} historical={work?.run?.status === 'superseded'} work={work}/>
    </Panel>
    {candidate && work && (work.global_issues.length > 0 || work.issue_count > 0) && <Panel className={styles.card}><h2>ما الذي يحتاج مراجعة؟</h2><p>هذه مراجعات على مستوى الفترة. راجع تفاصيل الموظفين في مراجعة الرواتب؛ لا تعرض هذه القائمة جميع موانعهم.</p>
      {work.global_issues.length > 0 && <ul className={styles.issues}>{work.global_issues.map((item, index) => { const action = sourceAction(item); return <li key={`${item.code}:${index}`}><Disclosure summary={<>{issueTitles[item.code] ?? 'مصدر الفترة يحتاج مراجعة'} <span className="field-hint">· {item.blocking === true ? 'مانع' : item.blocking === false ? 'تنبيه' : 'يحتاج مراجعة'} · التفاصيل</span></>}>

        <p>{issueNames[item.code] ?? 'يلزم مراجعة أحد مصادر الفترة مع مسؤول الرواتب.'}</p>
      </Disclosure><p className="field-hint">الجهة المسؤولة: {issueResponsibility(item.owner)}</p><ButtonLink variant="ghost"  href={action.href}>{action.label}</ButtonLink></li>; })}</ul>}
      {work.issue_count > 0 && <Link href={runLink}>عرض العوائق والموظفين المتأثرين</Link>}
    </Panel>}
    {work && !final && <Suspense fallback={<Message tone="info" role="status">جارٍ التحقق من تنبيه الإضافي؛ يمكنك متابعة مراجعة الرواتب.</Message>}><OvertimeNotice tenantId={tenantId} employer={employer} period={work.period} query={query}/></Suspense>}
    {work && final && work.final_output_id && <Suspense fallback={<Message tone="info" role="status">جارٍ التحقق من حالة الصرف المسجل؛ يمكنك متابعة مراجعة المسير.</Message>}><RecordedPaymentNotice tenantId={tenantId} employer={employer} output={work.final_output_id} period={work.period} query={query}/></Suspense>}
    <Disclosure summary={<>المدخلات وإعداد الدورة والفترات السابقة</>} className={styles.card}>
      {calendar.access.can_view && work && <p><Link href={inputsLink}>مدخلات الفترة ومراجعتها</Link></p>}
      <p><Link href={setupLink}>دورة الجهة والفترات المحفوظة</Link></p>
      {!navigation.error && navigation.data?.can_view_advances === true && <p><Link href={`${path}/advances?${new URLSearchParams({ employer })}`}>سلف موظفي الجهة وأقساطها</Link></p>}
      {!navigation.error && navigation.data?.can_view_reports === true && <p><Link href={`${path}/reports?${new URLSearchParams({ employer, report: navigation.data.report_kind === 'advances' ? 'advances' : 'sheet', ...(navigation.data.report_kind !== 'advances' && work?.final_output_id ? { output: work.final_output_id } : {}) })}`}>التقارير المحفوظة للجهة</Link></p>}
      {periods.length === 24 && <p><Link href={scope('/runs', { before: periods[23].starts_on, period: '' })}>فترات أقدم</Link></p>}
    </Disclosure>
  </div></PageFrame>;
}
