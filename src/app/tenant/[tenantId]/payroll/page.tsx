import { Button, ButtonLink, Disclosure, Input, Message, PageHeader, Panel, RecordCard, Field } from '@/components/ui';
import { EmployerSelector } from './EmployerSelector';
import { normalizeEmployerScope } from './employer-context';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient, getWorkspaceUser } from '@/lib/workspace-access';
import { displayDate, uuid, type CalendarPreview } from './rules';
import { CreateRunForm } from './CreateRunForm';
import { money } from './runs/rules';
import styles from './payroll.module.css';

export const dynamic = 'force-dynamic';
type Query = Record<string, string | undefined>;
type Employer = { id: string; name: string };
type Period = { id: string; starts_on: string; ends_on: string; payment_on: string; status: string | null; period_state: string; run_id: string | null; output_id: string | null; employee_count: number | null; gross: string | null; net: string | null; paid: string | null; remaining: string | null; issue_count: number };
type Calendar = { employer_name: string; revision: number; versions: unknown[]; access: { can_view: boolean; can_manage: boolean; enabled: boolean }; next_preview?: CalendarPreview };

function stateLabel(period: Period) {
 if (period.output_id) return period.remaining === null ? 'محفوظ' : Number(period.remaining) === 0 ? 'تم تسجيل الصرف' : period.paid !== null && Number(period.paid) > 0 ? 'صرف جزئي' : 'جاهز للصرف';
 if (period.status === 'approved') return 'معتمد';
 if (period.status === 'cancelled') return 'ملغى';
 if (!period.run_id) return 'لم يُحسب بعد';
 return period.period_state === 'upcoming' ? 'فترة قادمة · حساب أولي' : period.period_state === 'ongoing' ? 'فترة جارية · حساب أولي' : 'قيد المراجعة';
}
function figure(value:string|null){return value===null?'—':money(value);}

export default async function PayrollPage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Promise<Query> }) {
 const { tenantId } = await params;
 if (!uuid(tenantId)) notFound();
 const query = await searchParams, path = `/tenant/${tenantId}/payroll`;
 const destination = normalizeEmployerScope(path, 'workspace', query);
 if (destination) redirect(destination);
 const kept = Object.fromEntries(Object.entries(query).filter((entry): entry is [string, string] => typeof entry[1] === 'string'));
 const retry = `${path}?${new URLSearchParams(kept)}`;
 const failure = (text: string) => <PageFrame><Panel dir="rtl" className={styles.card}><PageHeader title="مسيرات الرواتب"/><Message tone="bad" role="alert">{text}</Message><ButtonLink variant="ghost" href={retry}>إعادة المحاولة</ButtonLink></Panel></PageFrame>;
 if (['employer', 'period', 'after_id'].some(key => query[key] && !uuid(query[key]!)) || (query.q?.length ?? 0) > 120 || (query.before && !/^\d{4}-\d{2}-\d{2}$/.test(query.before))) return failure('راجع رابط الشركة وعبارة البحث.');
 if (query.stage === 'setup') redirect(`${path}/setup?${new URLSearchParams(kept)}`);
 const client = await getWorkspaceClient();
 if (!client) return failure('تعذر الاتصال ببيانات الرواتب.');
 const { data: { user } } = await getWorkspaceUser(client);
 if (!user) redirect(`/auth/login?next=${encodeURIComponent(retry)}`);
 const [access, navigation, runAccess] = await Promise.all([client.rpc('payroll_access_snapshot', { p_tenant: tenantId }), client.rpc('payroll_navigation_access', { p_tenant: tenantId }), client.rpc('payroll_run_access', { p_tenant: tenantId })]);
 if (access.error || !access.data) return failure(access.error?.code === '42501' ? 'عرض الرواتب غير متاح لهذا الحساب. راجع مدير الشركة.' : 'تعذر تحميل صلاحيات الرواتب.');
 const found = await client.rpc('payroll_employers', { p_tenant: tenantId, p_query: query.q ?? '', p_after_name: query.after_name ?? null, p_after_id: query.after_id ?? null, p_limit: 30 });
 if (found.error || !Array.isArray(found.data?.items)) return failure('تعذر تحميل شركاتك.');
 const employers = found.data.items as Employer[], employer = query.employer || found.data.unique_employer || '';
 if (!employer) return <PageFrame><div dir="rtl" className={styles.workspace}><PageHeader title="مسيرات الرواتب" description="اختر الشركة التي تريد العمل عليها."/><form method="get" className={styles.filters}><Field id="payroll-employer-search" label="البحث عن الشركة"><Input id="payroll-employer-search" name="q" maxLength={120} defaultValue={query.q ?? ''} placeholder="مثال: شركة النور"/></Field><Button variant="ghost" type="submit">بحث</Button></form><ul className={styles.periods}>{employers.map(item => <RecordCard className={styles.card} key={item.id}><Link href={`${path}?${new URLSearchParams({ employer: item.id })}`}>{item.name}</Link></RecordCard>)}</ul>{!employers.length && <p>لا توجد شركة مطابقة. غيّر البحث أو راجع مدير الشركة.</p>}{employers.length === 30 && <Link href={`${path}?${new URLSearchParams({ q: query.q ?? '', after_name: employers[29].name, after_id: employers[29].id })}`}>شركات أخرى</Link>}</div></PageFrame>;
 const calendarResult = await client.rpc('payroll_workspace', { p_tenant: tenantId, p_employer: employer, p_limit: 24 });
 if (calendarResult.error || !calendarResult.data) return failure('تعذر تحميل مواعيد الرواتب.');
 const calendar = calendarResult.data as Calendar;
 let periods: Period[] = [], hasMore = false;
 if (!runAccess.error) {
  const result = await client.rpc('payroll_run_collection', { p_tenant: tenantId, p_employer: employer, p_before: query.before || null, p_limit: 24 });
  if (result.error || !Array.isArray(result.data?.items)) return failure('تعذر تحميل المسيرات. أعد المحاولة؛ لم تتغير بياناتك.');
  periods = result.data.items as Period[]; hasMore = result.data.has_more === true;
 }
 const scope = (suffix: string, extra: Record<string, string> = {}) => `${path}${suffix}?${new URLSearchParams({ employer, ...extra })}`;
 const availablePeriods = periods.filter(period => !period.output_id && (!period.run_id || period.status === 'cancelled'));
 const canCreate = calendar.access.enabled && runAccess.data?.can_prepare === true && (availablePeriods.length > 0 || calendar.access.can_manage && (calendar.next_preview !== undefined || calendar.versions.length === 0));
 const listLink = scope(''), newLink = scope('', { new: '1', ...(query.before ? { before: query.before } : {}) }), setupLink = scope('/setup');
 const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(new Date());
 return <PageFrame><div dir="rtl" className={styles.workspace}>
  <div className={styles.collectionHeading}><PageHeader title="مسيرات الرواتب" description={calendar.employer_name}/>{canCreate && query.new !== '1' && <ButtonLink href={newLink}>مسير جديد</ButtonLink>}</div>
  <EmployerSelector path={path} page="workspace" employer={employer} name={calendar.employer_name} choices={employers} context={query} singleEmployer={found.data.unique_employer === employer}/>
  {!calendar.access.enabled && <Message tone="info">خدمة الرواتب متوقفة حاليًا. يمكنك مراجعة المسيرات السابقة وفق صلاحياتك.</Message>}
  {query.new === '1' && canCreate ? <><CreateRunForm actor={user.id} tenant={tenantId} employer={employer} revision={calendar.revision} next={calendar.access.can_manage ? calendar.next_preview : undefined} today={today} saved={availablePeriods} canManage={calendar.access.can_manage}/>{hasMore && periods.length > 0 && <ButtonLink variant="ghost" href={scope('', { new: '1', before: periods[periods.length - 1].starts_on })}>اختيار فترة أقدم</ButtonLink>}{query.before && <ButtonLink variant="ghost" href={scope('', { new: '1' })}>أحدث الفترات</ButtonLink>}</> : <>
   {periods.length ? <section className={styles.recordList} aria-label="قائمة مسيرات الرواتب"><div className={styles.tableScroll}><table className={`${styles.recordTable} ${styles.collectionTable}`} role="table" aria-label="مسيرات الرواتب"><thead role="rowgroup"><tr role="row"><th role="columnheader" scope="col">الفترة</th><th role="columnheader" scope="col">الحالة</th><th role="columnheader" scope="col">الموظفون</th><th role="columnheader" scope="col">الاستحقاقات</th><th role="columnheader" scope="col">الصافي</th><th role="columnheader" scope="col">المدفوع</th><th role="columnheader" scope="col">المتبقي</th><th role="columnheader" scope="col">الإجراء</th></tr></thead><tbody role="rowgroup">{periods.map(period => <tr role="row" key={period.id}>
    <th role="rowheader" scope="row"><Link href={scope('/runs', { period: period.id, view: 'all' })}>{displayDate(period.starts_on)} — {displayDate(period.ends_on)}</Link><small>الصرف المقرر {displayDate(period.payment_on)}</small></th>
    <td role="cell"><span className={styles.collectionLabel} aria-hidden="true">الحالة</span><span className={styles.recordStatus}>{stateLabel(period)}</span></td>
    <td role="cell"><span className={styles.collectionLabel} aria-hidden="true">الموظفون</span><span className={styles.collectionValue}>{period.employee_count ?? '—'}</span></td>
    <td role="cell"><span className={styles.collectionLabel} aria-hidden="true">الاستحقاقات</span><span className={styles.collectionValue}>{figure(period.gross)}</span></td>
    <td role="cell"><span className={styles.collectionLabel} aria-hidden="true">الصافي</span><span className={styles.collectionValue}>{figure(period.net)}</span></td>
    <td role="cell"><span className={styles.collectionLabel} aria-hidden="true">المدفوع</span><span className={styles.collectionValue}>{figure(period.paid)}</span></td>
    <td role="cell"><span className={styles.collectionLabel} aria-hidden="true">المتبقي</span><span className={styles.collectionValue}>{figure(period.remaining)}</span></td>
    <td role="cell" className={styles.collectionAction}><ButtonLink variant="ghost" href={scope('/runs', { period: period.id, view: 'all' })}>فتح المسير</ButtonLink></td>
   </tr>)}</tbody></table></div><p className={styles.listNote}>المبالغ من آخر حساب محفوظ. «—» تعني أن القيمة لم تكتمل أو لا تتاح لهذا الحساب؛ لا تعني صفرًا.</p></section> : <Panel className={styles.emptyWorkspace}><h2>{runAccess.error ? 'إعدادات الرواتب' : 'ابدأ أول مسير'}</h2><p>{runAccess.error ? 'يمكنك ضبط مواعيد الرواتب. عرض المسيرات وحسابها متاح للحسابات المصرح لها.' : 'اختر الفترة، وسنجمع الموظفين المشمولين ونحسب الرواتب ونوضح ما يحتاج مراجعة.'}</p>{canCreate ? <ButtonLink href={newLink}>مسير جديد</ButtonLink> : calendar.access.can_manage ? <ButtonLink href={setupLink}>إعداد مواعيد الرواتب</ButtonLink> : <p>اطلب من مدير الشركة تجهيز أول فترة للرواتب.</p>}</Panel>}
   {hasMore && periods.length > 0 && <ButtonLink variant="ghost" href={scope('', { before: periods[periods.length - 1].starts_on })}>مسيرات أقدم</ButtonLink>}{query.before && <ButtonLink variant="ghost" href={listLink}>أحدث المسيرات</ButtonLink>}
  </>}
  <nav className={styles.collectionTools} aria-label="أدوات الرواتب">{calendar.access.can_manage && <Link href={setupLink}>إعدادات الرواتب</Link>}{!navigation.error && navigation.data?.can_view_advances && <Link href={scope('/advances')}>السلف</Link>}{!navigation.error && navigation.data?.can_view_reports && <Link href={scope('/reports', { report: navigation.data.report_kind === 'advances' ? 'advances' : 'sheet' })}>التقارير</Link>}{calendar.access.can_view && <Disclosure summary="أدوات إضافية"><ButtonLink variant="ghost" href={scope('/inputs')}>إضافات وخصومات وبيانات سابقة</ButtonLink></Disclosure>}</nav>
 </div></PageFrame>;
}
