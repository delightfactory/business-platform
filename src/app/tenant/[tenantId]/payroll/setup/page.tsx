import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { CalendarForm, DateSummary, GenerateForm } from '../CalendarForm';
import { type CalendarPreview, displayDate, uuid } from '../rules';
import styles from '../payroll.module.css';
export const dynamic = 'force-dynamic';
type Employer = { id: string; name: string };
type Version = {revision:number;effective_from:string;effective_until:string|null;cutoff_day:number|null;payment_day:number;payment_month:string;timezone:string};
type Workspace = { employer_name:string; revision:number; next_start:string|null; access:{can_view:boolean;can_manage:boolean;enabled:boolean}; versions:Version[]; periods:(CalendarPreview & {is_transition:boolean})[]; next_preview?:CalendarPreview };
export default async function PayrollSetupPage({params,searchParams}: {params:Promise<{tenantId:string}>;searchParams:Promise<{employer?:string;period?:string;review_q?:string;q?:string;after_name?:string;after_id?:string;before?:string;stage?:string}>}) {
 const {tenantId} = await params; if(!uuid(tenantId)) notFound(); const query = await searchParams;
 const path = `/tenant/${tenantId}/payroll/setup`; const retry = `${path}?${new URLSearchParams(query).toString()}`;
 const failure = (text:string) => <PageFrame><section className={styles.card}><h1>الرواتب</h1><p role="alert">{text}</p><Link className="secondary-button" href={retry}>إعادة المحاولة</Link></section></PageFrame>;
 const client = await createSupabaseServerClient(); if(!client) return failure('تعذر الاتصال. أعد المحاولة لاستعادة بيانات الرواتب.');
 const {data:{user}} = await client.auth.getUser(); if(!user) redirect(`/auth/login?next=${encodeURIComponent(retry)}`);
 const {data:access,error:accessError} = await client.rpc('payroll_access_snapshot',{p_tenant:tenantId});
 if(accessError || !access) return failure(accessError?.code==='42501'?'هذا الحساب غير مخوّل للوصول إلى الرواتب. راجع مسؤول الشركة.':'تعذر تحميل صلاحيات الرواتب.');
 if((query.review_q?.length ?? 0)>120 || (query.period && !uuid(query.period)) || (query.q?.length ?? 0)>120 || (query.employer && !uuid(query.employer)) || (query.after_id && !uuid(query.after_id)) || (query.before && !/^\d{4}-\d{2}-\d{2}$/.test(query.before))) return failure('راجع رابط البحث والفترة ثم أعد المحاولة.');
 const {data:employers,error:employerError} = await client.rpc('payroll_employers',{p_tenant:tenantId,p_query:query.q??'',p_after_name:query.after_name??null,p_after_id:query.after_id??null,p_limit:30});
 if(employerError || !employers || !Array.isArray(employers.items)) return failure('تعذر تحميل الجهات. الاختيار السابق محفوظ في رابط الصفحة.');
 const items = employers.items as Employer[]; const employer = query.employer ?? employers.unique_employer ?? '';
 let workspace:Workspace|null=null;
 if(employer) { const result = await client.rpc('payroll_workspace',{p_tenant:tenantId,p_employer:employer,p_before:query.before??null,p_limit:12}); if(result.error || !result.data) return failure('تعذر تحميل دورة هذه الجهة وفتراتها. أعد المحاولة بنفس الجهة والفترة.'); workspace=result.data as Workspace; }
 const link = (extra:Record<string,string>) => `${path}?${new URLSearchParams({...(query.q?{q:query.q}:{}),...(query.period?{period:query.period}:{}),...(query.review_q?{review_q:query.review_q}:{}),...(employer?{employer}:{}),...(extra.employer&&extra.employer!==employer?{period:'',review_q:''}:{}),...extra}).toString()}`;
 const today = new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo'}).format(new Date());
 return <PageFrame><div className={styles.workspace} dir="rtl"><header><p className="eyebrow">مساحة الشركة · إعداد الرواتب</p><h1>دورة الرواتب والفترات</h1><p>اضبط الدورة لكل جهة، وراجع تواريخ الفترات وجاهزيتها.</p><Link href={`/tenant/${tenantId}/payroll?${new URLSearchParams({...(query.employer?{employer:query.employer}:{}),...(query.period?{period:query.period}:{}),...(query.review_q?{review_q:query.review_q}:{})})}`}>العودة إلى مساحة الرواتب</Link></header>
 <form method="get" className={styles.filters}>{employer&&<input type="hidden" name="employer" value={employer}/>} {query.period&&<input type="hidden" name="period" value={query.period}/>} {query.review_q&&<input type="hidden" name="review_q" value={query.review_q}/>}<label htmlFor="payroll-employer-search">البحث عن جهة<input id="payroll-employer-search" name="q" defaultValue={query.q??''} maxLength={120}/></label><button className="secondary-button">بحث</button></form>
 {!employer && <section><h2>اختر جهة العمل</h2>{items.length===0?<p>لا توجد جهات مطابقة. عدّل البحث أو راجع إعداد الجهات مع مسؤول الشركة.</p>:<ul>{items.map(e=><li key={e.id}><Link href={link({employer:e.id})}>{e.name}</Link></li>)}</ul>}</section>}
 {items.length===30 && <Link href={link({after_name:items[29].name,after_id:items[29].id})}>جهات إضافية</Link>}
 {workspace && <><section className={styles.card}><h2>{workspace.employer_name}</h2><Link href={path}>اختيار جهة أخرى</Link>{!workspace.access.enabled && <p role="status">خدمة الرواتب غير مفعلة لهذه الشركة. يمكنك مراجعة التاريخ؛ راجع مسؤول الشركة قبل إعداد فترات جديدة.</p>}</section>
 <p><Link href={`/tenant/${tenantId}/payroll/inputs?${new URLSearchParams({employer,period:query.period??'',q:query.review_q??''})}`}>تحضير مدخلات الجهة ومراجعتها</Link> · <Link href={`/tenant/${tenantId}/payroll/runs?${new URLSearchParams({employer,period:query.period??'',q:query.review_q??''})}`}>العودة إلى حساب ومراجعة الرواتب</Link></p>
 <section><h2>الفترات المحفوظة</h2>{workspace.periods.length===0?<p>لا توجد فترات محفوظة لهذه الجهة.</p>:<ul className={styles.periods}>{workspace.periods.map(p=><li key={p.starts_on} className={styles.card}><h3>رواتب {new Intl.DateTimeFormat('ar-EG',{year:'numeric',month:'long',timeZone:'UTC'}).format(new Date(`${p.ends_on}T12:00:00Z`))}</h3>{p.is_transition && <p>فترة انتقالية تمت مراجعة تواريخها</p>}<DateSummary preview={p}/><p>التواريخ محفوظة؛ حساب مرشح تشغيلي متاح من مراجعة الرواتب. التأهيل المالي والقانوني ما زال مطلوبًا.</p></li>)}</ul>}{workspace.periods.length===12 && <Link href={link({before:workspace.periods[11].starts_on})}>فترات أقدم</Link>}{query.before && <Link href={link({})}>العودة إلى أحدث الفترات</Link>}</section>
 <section className={styles.card}><h2>جاهزية الفترة</h2><ul><li>{workspace.versions.length?'الدورة: التواريخ محددة ومحفوظة.':'الدورة: يلزم إعدادها أولًا.'}</li><li>بيانات الموظفين والتعويضات: لم تُفحص في هذه المرحلة.</li><li>الحضور والإجازات وتمويل الموظفين: لم تُفحص بعد. غياب خدمة اختيارية ليس خطأ.</li><li>حساب مرشح تشغيلي ومراجعته متاحان؛ التأهيل القانوني والمالي لم يكتمل بعد، ولا يوجد مبلغ صالح للصرف أو إقفال مالي.</li></ul></section>
 {workspace.access.can_manage && workspace.access.enabled && (query.stage==='setup'||workspace.versions.length===0?<CalendarForm key={`${tenantId}:${employer}:${workspace.revision}`} tenant={tenantId} employer={employer} start={workspace.next_start??today} last={workspace.next_start?new Date(new Date(`${workspace.next_start}T12:00:00Z`).getTime()-86400000).toISOString().slice(0,10):null} defaults={workspace.versions[0]}/>:<section className={styles.card}>{workspace.next_preview && <GenerateForm key={`${tenantId}:${employer}:${workspace.revision}`} tenant={tenantId} employer={employer} revision={workspace.revision} preview={workspace.next_preview}/>}<p><Link href={link({stage:'setup'})}>تغيير الدورة للفترات القادمة</Link></p></section>)}
 <details className={styles.card}><summary>تاريخ إعداد الدورة</summary>{workspace.versions.length===0?<p>لم تُحفظ دورة بعد.</p>:<ul>{workspace.versions.map(v=><li key={v.revision}>تبدأ {displayDate(v.effective_from)}{v.effective_until?` وتنتهي قبل ${displayDate(v.effective_until)}`:''} · نهاية الفترة: {v.cutoff_day??'آخر يوم من الشهر'} · الصرف يوم {v.payment_day} في {v.payment_month==='following'?'الشهر التالي':'شهر نهاية الفترة'} · <bdi>{v.timezone}</bdi></li>)}</ul>}</details>
 {query.stage==='setup' && <Link href={link({})}>إلغاء والعودة إلى الفترات</Link>}
 </>}
 </div></PageFrame>;
}
