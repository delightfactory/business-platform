import { validatePayrollPeriod } from './period-scope';
import { Button, ButtonLink, Disclosure, Input, Message, PageHeader, Panel, RecordCard, Field } from '@/components/ui';
import {EmployerSelector} from './EmployerSelector';
import {normalizeEmployerScope} from './employer-context';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { displayDate, uuid } from './rules';
import styles from './payroll.module.css';
import { GenerateForm } from './CalendarForm';

export const dynamic = 'force-dynamic';
type Query = Record<string, string | undefined>;
type Employer = { id: string; name: string };
type Period = { id: string; starts_on: string; ends_on: string; is_transition?: boolean };
type Calendar = { employer_name: string; versions: { timezone: string }[]; periods: { starts_on: string; ends_on: string; timezone: string }[]; access: { can_view: boolean; can_manage: boolean; enabled: boolean }; revision:number; next_preview?:import('./rules').CalendarPreview };
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
  const { data: { user } } = await getWorkspaceUser(client);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(retry)}`);
  const [access, navigation] = await Promise.all([client.rpc('payroll_access_snapshot', { p_tenant: tenantId }), client.rpc('payroll_navigation_access', { p_tenant: tenantId })]);
  if (access.error || !access.data) return failure(access.error?.code === '42501' ? 'هذا الحساب ليس لديه صلاحية للوصول إلى مساحة الرواتب. راجع مسؤول الشركة.' : 'تعذر تحميل صلاحيات الرواتب.');
  const found = await client.rpc('payroll_employers', { p_tenant: tenantId, p_query: query.q ?? '', p_after_name: query.after_name ?? null, p_after_id: query.after_id ?? null, p_limit: 30 });
  if (found.error || !Array.isArray(found.data?.items)) return failure('تعذر تحميل جهات العمل.');
  const employers = found.data.items as Employer[], employer = query.employer || found.data.unique_employer || '';
  const scope = (suffix: string, extra: Record<string, string> = {}) => `${path}${suffix}?${new URLSearchParams({ ...(employer ? { employer } : {}), ...(query.period ? { period: query.period } : {}), ...(query.review_q ? { q: query.review_q } : {}), ...extra })}`;
  if (!employer) return <PageFrame><div dir="rtl" className={styles.workspace}>
    <div><p className="eyebrow">مساحة الشركة · الرواتب</p><PageHeader  title={<>اختر جهة العمل</>} description={<> ابدأ باختيار جهة العمل، ثم اختر فترة الرواتب. </>} /></div>
    <form method="get" className={styles.filters}><Field  id="payroll-employer-search" label={<>البحث عن جهة</>}><Input id="payroll-employer-search" name="q" maxLength={120} defaultValue={query.q ?? ''} placeholder="مثال: شركة النور"/></Field><Button variant="ghost" type="submit" >بحث</Button></form>
    {employers.length ? <ul className={styles.periods}>{employers.map(item => <RecordCard className={styles.card} key={item.id}><Link href={`${path}?${new URLSearchParams({ employer: item.id })}`}>{item.name}</Link></RecordCard>)}</ul> : <p>لا توجد جهات مطابقة. عدّل البحث أو راجع مسؤول الشركة.</p>}
    {employers.length === 30 && <Link href={`${path}?${new URLSearchParams({ q: query.q ?? '', after_name: employers[29].name, after_id: employers[29].id })}`}>جهات إضافية</Link>}
  </div></PageFrame>;
  const loaded = await client.rpc('payroll_workspace', { p_tenant: tenantId, p_employer: employer, p_limit: 24 });
  if (loaded.error || !loaded.data) return failure('تعذر تحميل دورة الجهة.');
  const calendar = loaded.data as Calendar;
  let periods: Period[] = [];
  let invalidPeriod = false;
  if (calendar.access.can_view) {
    const result = await client.rpc('payroll_run_periods', { p_tenant: tenantId, p_employer: employer });
    if (result.error || !Array.isArray(result.data)) return failure('تعذر تحميل فترات الرواتب.');
    periods = result.data as Period[];
    if (query.period) {
      const validity=await validatePayrollPeriod(client,tenantId,employer,query.period,periods);
      if(validity==='unavailable')return failure('تعذر التحقق من فترة الرواتب. احتفظنا بالاختيار؛ أعد المحاولة.');
      invalidPeriod=validity==='invalid';if(invalidPeriod)query.period='';
    }
    if(query.period&&!invalidPeriod)redirect(scope('/runs',{period:query.period}));
  }
  const setupLink = scope('/setup', { period: query.period ?? '', q: query.q ?? '', ...(query.review_q ? { review_q: query.review_q } : {}) });
  return <PageFrame><div dir="rtl" className={styles.workspace}>
    <PageHeader title="مسيرات الرواتب" description={calendar.employer_name}/>
    <EmployerSelector path={path} page="workspace" employer={employer} name={calendar.employer_name} choices={employers} context={query} singleEmployer={found.data.unique_employer===employer}/>
    {invalidPeriod&&<Message tone="warn">الفترة المختارة لا تخص هذه الجهة. اختر المسير من القائمة.</Message>}
    {!calendar.access.enabled&&<Message tone="info">خدمة الرواتب غير مفعلة لإجراءات جديدة؛ التاريخ متاح حسب الصلاحيات.</Message>}
    <section><h2>افتح المسير الذي تريد إنجازه</h2>{periods.length===0?<Message tone="info">لا توجد فترة محفوظة بعد. ابدأ بإعداد دورة الرواتب.</Message>:<ul className={styles.cardGrid}>{periods.map(p=><RecordCard key={p.id} className={styles.card}><h3>{displayDate(p.starts_on)} — {displayDate(p.ends_on)}</h3><ButtonLink href={scope('/runs',{period:p.id})}>فتح المسير</ButtonLink></RecordCard>)}</ul>}</section>
    {calendar.access.can_manage&&calendar.access.enabled&&(calendar.next_preview?<Disclosure summary="إنشاء المسير للفترة التالية" open={periods.length===0}><GenerateForm tenant={tenantId} employer={employer} revision={calendar.revision} preview={calendar.next_preview}/></Disclosure>:calendar.versions.length===0?<ButtonLink href={setupLink}>إعداد دورة الرواتب والفترة الأولى</ButtonLink>:null)}
    <Disclosure summary="إعدادات وأدوات الرواتب"><nav className={styles.actions}><ButtonLink variant="ghost" href={setupLink}>الدورة وإعدادات الرواتب</ButtonLink>{calendar.access.can_view&&<ButtonLink variant="ghost" href={scope('/inputs')}>المدخلات المتقدمة</ButtonLink>}{!navigation.error&&navigation.data?.can_view_advances&&<ButtonLink variant="ghost" href={scope('/advances')}>السلف والأقساط</ButtonLink>}{!navigation.error&&navigation.data?.can_view_reports&&<ButtonLink variant="ghost" href={scope('/reports',{report:navigation.data.report_kind==='advances'?'advances':'sheet'})}>تقارير الرواتب</ButtonLink>}</nav></Disclosure>
    {periods.length===24&&<Link href={scope('/runs',{before:periods[23].starts_on,period:''})}>فترات أقدم</Link>}
  </div></PageFrame>;
}
