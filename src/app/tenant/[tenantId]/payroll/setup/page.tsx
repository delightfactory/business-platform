import { validatePayrollPeriod } from '../period-scope';
import { Button, ButtonLink, Disclosure, Input, Message, PageHeader, Panel, Field } from '@/components/ui';
import { legacyConfigurationHref } from './configuration/navigation';
import {EmployerSelector} from '../EmployerSelector';
import {normalizeEmployerScope} from '../employer-context';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { CalendarForm, GenerateForm } from '../CalendarForm';
import { type CalendarPreview, displayDate, uuid } from '../rules';
import styles from '../payroll.module.css';
export const dynamic = 'force-dynamic';
type Employer = { id: string; name: string };
type Version = {revision:number;effective_from:string;effective_until:string|null;cutoff_day:number|null;payment_day:number;payment_month:string;timezone:string};
type Workspace = { employer_name:string; revision:number; next_start:string|null; access:{can_view:boolean;can_manage:boolean;enabled:boolean}; versions:Version[]; periods:(CalendarPreview & {is_transition:boolean})[]; next_preview?:CalendarPreview; calendar_change_review?:{open_run_period_id:string|null;locked_history:boolean;attendance_enabled:boolean;pending_attendance_date:string|null;can_review_attendance:boolean} };
export default async function PayrollSetupPage({params,searchParams}: {params:Promise<{tenantId:string}>;searchParams:Promise<{employer?:string;period?:string;review_q?:string;q?:string;after_name?:string;after_id?:string;before?:string;stage?:string;employer_scope?:string}>}) {
 const {tenantId} = await params; if(!uuid(tenantId)) notFound(); const query = await searchParams;
 const path = `/tenant/${tenantId}/payroll/setup`; const employerDestination=normalizeEmployerScope(path,'setup',query);if(employerDestination)redirect(employerDestination); const retry = `${path}?${new URLSearchParams(query).toString()}`;
 const failure = (text:string) => <PageFrame><Panel className={styles.card}><PageHeader  title={<>الرواتب</>} /><Message tone="bad" role="alert">{text}</Message><ButtonLink variant="ghost"  href={retry}>إعادة المحاولة</ButtonLink></Panel></PageFrame>;
 const client = await createSupabaseServerClient(); if(!client) return failure('تعذر الاتصال. أعد المحاولة لاستعادة بيانات الرواتب.');
 const {data:{user}} = await getWorkspaceUser(client); if(!user) redirect(`/auth/login?next=${encodeURIComponent(retry)}`);
 const {data:access,error:accessError} = await client.rpc('payroll_access_snapshot',{p_tenant:tenantId});
 if(accessError || !access) return failure(accessError?.code==='42501'?'هذا الحساب ليس لديه صلاحية للوصول إلى الرواتب. راجع مسؤول الشركة.':'تعذر تحميل صلاحيات الرواتب.');
 if((query.review_q?.length ?? 0)>120 || (query.period && !uuid(query.period)) || (query.q?.length ?? 0)>120 || (query.employer && !uuid(query.employer)) || (query.after_id && !uuid(query.after_id)) || (query.before && !/^\d{4}-\d{2}-\d{2}$/.test(query.before))) return failure('راجع رابط البحث والفترة ثم أعد المحاولة.');
 const {data:employers,error:employerError} = await client.rpc('payroll_employers',{p_tenant:tenantId,p_query:query.q??'',p_after_name:query.after_name??null,p_after_id:query.after_id??null,p_limit:30});
 if(employerError || !employers || !Array.isArray(employers.items)) return failure('تعذر تحميل الجهات. الاختيار السابق محفوظ في رابط الصفحة.');
 const items = employers.items as Employer[]; const employer = query.employer ?? employers.unique_employer ?? '';
 let workspace:Workspace|null=null;
 if(employer) { const result = await client.rpc('payroll_workspace',{p_tenant:tenantId,p_employer:employer,p_before:query.before??null,p_limit:12}); if(result.error || !result.data) return failure('تعذر تحميل دورة هذه الجهة وفتراتها. أعد المحاولة بنفس الجهة والفترة.'); workspace=result.data as Workspace; }
 let invalidPeriod=false;
 if(employer&&query.period){const listed=await client.rpc('payroll_run_periods',{p_tenant:tenantId,p_employer:employer});if(listed.error||!Array.isArray(listed.data))return failure('تعذر التحقق من فترة الرواتب.');const validity=await validatePayrollPeriod(client,tenantId,employer,query.period,listed.data);if(validity==='unavailable')return failure('تعذر التحقق من فترة الرواتب. احتفظنا بالاختيار؛ أعد المحاولة.');invalidPeriod=validity==='invalid';if(invalidPeriod)query.period=undefined;}
 const link = (extra:Record<string,string>) => `${path}?${new URLSearchParams({...(query.q?{q:query.q}:{}),...(query.period?{period:query.period}:{}),...(query.review_q?{review_q:query.review_q}:{}),...(employer?{employer}:{}),...(extra.employer&&extra.employer!==employer?{period:'',review_q:''}:{}),...extra}).toString()}`;
 const today = new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo'}).format(new Date());
 return <PageFrame><div className={styles.workspace} dir="rtl"><PageHeader title="إعدادات الرواتب" description={workspace?.employer_name}/><ButtonLink variant="ghost" href={`/tenant/${tenantId}/payroll?${new URLSearchParams({...(employer?{employer}:{})})}`}>العودة إلى المسيرات</ButtonLink>
 {!employer&&<section><h2>اختر الشركة</h2><form method="get" className={styles.filters}><Field id="payroll-settings-search" label="البحث عن الشركة"><Input id="payroll-settings-search" name="q" defaultValue={query.q??''} maxLength={120} placeholder="مثال: شركة النور"/></Field><Button variant="ghost" type="submit">بحث</Button></form><ul className={styles.periods}>{items.map(item=><li key={item.id}><Link href={link({employer:item.id})}>{item.name}</Link></li>)}</ul>{!items.length&&<p>لا توجد شركة مطابقة.</p>}{items.length===30&&<Link href={link({after_name:items[29].name,after_id:items[29].id})}>شركات أخرى</Link>}</section>}
 {invalidPeriod&&<Message tone="info">الفترة المختارة لا تخص هذه الشركة. يمكنك اختيار مسير آخر من قائمة المسيرات.</Message>}
 {workspace&&<><EmployerSelector path={path} page="setup" employer={employer} name={workspace.employer_name} choices={items} context={query} singleEmployer={employers.unique_employer===employer}/>{!workspace.access.enabled&&<Message tone="info">خدمة الرواتب متوقفة حاليًا. الإعدادات السابقة محفوظة.</Message>}
 <nav className={styles.runTabs} aria-label="إعدادات الرواتب"><a href="#payroll-settings-dates">مواعيد الرواتب</a><Link href={legacyConfigurationHref(tenantId,{employer,period:query.period,review_q:query.review_q})}>بنود الراتب وطريقة الحساب</Link>{workspace.periods.length>0&&<Link href={`/tenant/${tenantId}/payroll/setup/employee?${new URLSearchParams({employer,period:query.period??''})}`}>بيانات الموظفين</Link>}</nav>
 <section id="payroll-settings-dates" className={styles.runSection}><div className={styles.formHeading}><h2>مواعيد الرواتب</h2>{workspace.access.can_manage&&workspace.access.enabled&&workspace.versions.length>0&&query.stage!=='setup'&&<ButtonLink variant="ghost" href={link({stage:'setup'})}>تغيير المواعيد القادمة</ButtonLink>}</div>
 {workspace.versions.length>0&&<dl className={styles.figureStrip}><div><dt>نهاية الفترة</dt><dd>{workspace.versions[0].cutoff_day?`يوم ${workspace.versions[0].cutoff_day} من الشهر`:'آخر يوم من الشهر'}</dd></div><div><dt>يوم الصرف</dt><dd>يوم {workspace.versions[0].payment_day} {workspace.versions[0].payment_month==='following'?'من الشهر التالي':'من شهر نهاية الفترة'}</dd></div></dl>}
 {!workspace.versions.length&&<p>حدد المواعيد مرة واحدة. سنستخدمها تلقائيًا عند إنشاء المسيرات التالية.</p>}
 {workspace.access.can_manage&&workspace.access.enabled&&(query.stage==='setup'||!workspace.versions.length)&&<>
 {workspace.calendar_change_review?.open_run_period_id?<Message tone="warn">أكمل المسير المفتوح أو أعده للمراجعة وألغِه قبل تغيير المواعيد. <Link href={`/tenant/${tenantId}/payroll/runs?${new URLSearchParams({employer,period:workspace.calendar_change_review.open_run_period_id})}`}>فتح المسير</Link></Message>:<CalendarForm key={`${employer}:${workspace.revision}`} tenant={tenantId} employer={employer} start={workspace.next_start??today} last={workspace.next_start?new Date(new Date(`${workspace.next_start}T12:00:00Z`).getTime()-86400000).toISOString().slice(0,10):null} defaults={workspace.versions[0]}/>}
 {workspace.calendar_change_review?.pending_attendance_date&&<Message tone="info">توجد أيام حضور تحتاج مراجعة بدءًا من {displayDate(workspace.calendar_change_review.pending_attendance_date)}. {workspace.calendar_change_review.can_review_attendance&&<Link href={`/tenant/${tenantId}/attendance/review?date=${workspace.calendar_change_review.pending_attendance_date}`}>فتح الحضور</Link>}</Message>}
 {workspace.calendar_change_review?.locked_history&&<p className="field-hint">التغيير يخص الفترات القادمة. المسيرات المقفلة ستبقى كما هي.</p>}</>}
 {workspace.access.can_manage&&workspace.access.enabled&&workspace.next_preview&&<Disclosure summary="إضافة فترة لاحقة دون حسابها"><GenerateForm key={`${employer}:${workspace.revision}`} tenant={tenantId} employer={employer} revision={workspace.revision} preview={workspace.next_preview}/></Disclosure>}
 </section>
 <Disclosure summary="سجل المواعيد والفترات السابقة"><ul className={styles.periods}>{workspace.versions.map(version=><li key={version.revision}>من {displayDate(version.effective_from)} · نهاية الفترة {version.cutoff_day??'آخر الشهر'} · الصرف يوم {version.payment_day}{version.effective_until?` · حتى ${displayDate(version.effective_until)}`:''}</li>)}</ul><h3>الفترات المحفوظة</h3><ul className={styles.periods}>{workspace.periods.map(period=><li key={period.starts_on}>{displayDate(period.starts_on)} — {displayDate(period.ends_on)} · الصرف {displayDate(period.payment_on)}</li>)}</ul>{workspace.periods.length===12&&<Link href={link({before:workspace.periods[11].starts_on})}>فترات أقدم</Link>}{query.before&&<Link href={link({before:''})}>أحدث الفترات</Link>}</Disclosure>
 </>}
 </div></PageFrame>;
}
