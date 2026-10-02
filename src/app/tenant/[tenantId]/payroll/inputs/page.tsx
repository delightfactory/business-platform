import Link from 'next/link';
import {notFound,redirect} from 'next/navigation';
import {PageFrame} from '@/components/context-navigation';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid,displayDate} from '../rules';
import {InputForm} from './InputForm';
import {CorrectionForm} from './CorrectionForm';
import {kindNames,statusNames,type InputKind,type InputRecord} from './rules';
import styles from '../payroll.module.css';
export const dynamic='force-dynamic';
type Period={id:string;starts_on:string;ends_on:string};
type Employee={id:string;full_name:string;employee_code:string;pay_basis:string;readiness:string};
type Workspace={access:Record<string,boolean>;period:Period;employees:Employee[];records:(InputRecord&{employee_name:string|null})[];records_more:boolean;component_choices:{id:string;name:string;behavior:string;classification:string;calculation:string;active:boolean;effective_from:string;effective_until:string|null}[];component_choices_more:boolean};
export default async function InputsPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<Record<string,string|undefined>>}) {
 const {tenantId}=await params;if(!uuid(tenantId))notFound();const query=await searchParams;
 const path=`/tenant/${tenantId}/payroll/inputs`,keep=Object.fromEntries(Object.entries(query).filter((x):x is [string,string]=>typeof x[1]==='string'));
 const href=(extra:Record<string,string>)=>`${path}?${new URLSearchParams({...keep,...extra})}`;
 const failure=(text:string)=><PageFrame><section className={styles.card} dir="rtl"><h1>مدخلات الرواتب</h1><p role="alert">{text}</p><Link href={href({})}>إعادة المحاولة بنفس الاختيار</Link></section></PageFrame>;
 for(const key of ['employer','period','after','records_after','head','after_id'])if(query[key]&&!uuid(query[key]!))return failure('راجع رابط الجهة والفترة ثم أعد المحاولة.');
 const client=await createSupabaseServerClient();if(!client)return failure('تعذر الاتصال ببيانات الرواتب.');const {data:{user}}=await client.auth.getUser();if(!user)redirect(`/auth/login?next=${encodeURIComponent(href({}))}`);
 const employers=await client.rpc('payroll_input_employers',{p_tenant:tenantId,p_query:query.employer_q??'',p_after_name:query.after_name??null,p_after_id:query.after_id??null});
 if(employers.error||!employers.data)return failure('تعذر تحميل الجهات أو لم يعد الحساب مخولًا. راجع مسؤول الشركة أو أعد المحاولة.');
 const employer=query.employer??employers.data.unique_employer??'';
 if(!employer)return <PageFrame><div dir="rtl" className={styles.workspace}><h1>اختر جهة مدخلات الرواتب</h1><form method="get" className={styles.filters}><label>البحث عن جهة<input name="employer_q" defaultValue={query.employer_q??''} maxLength={120}/></label><button>بحث</button></form>{employers.data.items.length===0?<p>لا توجد جهة مطابقة. راجع إعداد الجهات مع مسؤول الشركة.</p>:<ul>{employers.data.items.map((e:{id:string;name:string})=><li key={e.id}><Link href={href({employer:e.id})}>{e.name}</Link></li>)}</ul>}{employers.data.items.length===30&&<Link href={href({after_id:employers.data.items[29].id,after_name:employers.data.items[29].name})}>جهات إضافية</Link>}</div></PageFrame>;
 const periodsResult=await client.rpc('payroll_input_periods',{p_tenant:tenantId,p_employer:employer,p_before:query.before??null});if(periodsResult.error)return failure('تعذر تحميل الفترات المحفوظة.');const periods=periodsResult.data as Period[];
 const period=query.period||periods[0]?.id;
 const calendar=`/tenant/${tenantId}/payroll?${new URLSearchParams({employer})}`;
 if(!period)return <PageFrame><section className={styles.card} dir="rtl"><h1>مدخلات الرواتب</h1><p>يلزم تحديد فترة محفوظة أولًا. المسؤول عن الإعداد: مدير دورة الرواتب.</p><Link href={calendar}>العودة إلى دورة الجهة</Link></section></PageFrame>;
 const result=await client.rpc('payroll_input_workspace',{p_tenant:tenantId,p_employer:employer,p_period:period,p_query:query.q??'',p_after:query.after??null,p_record_after:query.records_after??null,p_limit:30});if(result.error||!result.data)return failure('تعذر تحميل مدخلات هذه الفترة. الاختيار والبحث محفوظان في الرابط.');
 const work=result.data as Workspace,access=work.access,records=work.records;
 const correctionResult=access['payroll.view']?await client.rpc('payroll_correction_items',{p_tenant:tenantId,p_employer:employer,p_period:period}):null;
 const corrections=(correctionResult?.data??[]) as {employment_id:string;name:string;requested:boolean}[];
 const kind=query.kind as InputKind|undefined,record=query.head?records.find(r=>r.id===query.head):undefined;
 if(query.head&&!record)return failure('السجل المطلوب خارج صفحة النتائج الحالية. ارجع إلى قائمة المدخلات وافتحه من صفحته.');
 if(kind&&!Object.hasOwn(kindNames,kind))return failure('نوع المدخل غير معروف.');
 const permission=(k:InputKind,approve=false)=>access[k==='component'||k==='policy'?'payroll_config.manage':k==='adjustment'?approve?'employee_finance.approve':'employee_finance.manage':k==='manual_units'&&approve?'payroll.approve':'payroll.prepare']===true;
 const employeeName=(id:string|null)=>work.employees.find(e=>e.id===id)?.full_name??'الموظف المحدد';
 const clear={head:'',kind:''},back=href(clear);
 return <PageFrame><div dir="rtl" className={styles.workspace}><header><h1>تحضير مدخلات الرواتب</h1><p>{displayDate(work.period.starts_on)} — {displayDate(work.period.ends_on)}</p><Link href={`/tenant/${tenantId}/payroll/runs?${new URLSearchParams({employer,period,q:query.q??''})}`}>العودة إلى مراجعة الرواتب للفترة</Link> · <Link href={calendar}>دورة الجهة والفترات</Link> · <Link href={path}>اختيار جهة أخرى</Link></header>
 <form method="get" className={styles.filters}><input type="hidden" name="employer" value={employer}/><label>الفترة<select name="period" defaultValue={period}>{!periods.some(p=>p.id===period)&&<option value={period}>الفترة المحددة</option>}{periods.map(p=><option value={p.id} key={p.id}>{displayDate(p.starts_on)} — {displayDate(p.ends_on)}</option>)}</select></label><label>البحث عن موظف<input name="q" defaultValue={query.q??''} maxLength={120}/></label><button className="secondary-button">عرض المدخلات</button></form>
 {periods.length===24&&<Link href={href({before:periods[23].starts_on,period:'',...clear})}>فترات أقدم</Link>}
 {!access.enabled&&<p role="status">خدمة الرواتب غير مفعلة؛ لا يمكن إعداد مدخلات جديدة. التاريخ المحفوظ متاح حسب صلاحياتك.</p>}
 <section className={styles.card}><h2>ما يلزم قبل الحساب</h2><p>{records.some(r=>r.kind==='policy')?'سياسة الشركة محفوظة.':'سياسة احتساب الجزء من الفترة غير محددة؛ المسؤول: مدير إعداد الرواتب.'}</p><p>المراجعة القانونية غير مؤهلة؛ المسؤول: مسؤول الامتثال. الحساب والإقفال والصرف غير متاحين في هذه المرحلة.</p><p>الحضور والإجازات وتمويل الموظفين مصادر اختيارية لم تُفحص هنا. غياب الخدمة الاختيارية لا يمنع تحضير المدخلات.</p></section>
 <section><h2>الموظفون المؤهلون لهذه الفترة</h2>{work.employees.length===0?<p>لا توجد علاقات توظيف مؤهلة مطابقة. راجع البحث أو أهلية الموظفين مع الموارد البشرية.</p>:<ul className={styles.periods}>{work.employees.map(e=><li className={styles.card} key={e.id}><h3>{e.full_name} · <bdi>{e.employee_code}</bdi></h3><p>{e.pay_basis==='daily'?'أجر يومي':'أجر شهري'} · {e.readiness==='compensation_missing'?'بيانات الأجر غير مكتملة؛ المسؤول: الموارد البشرية.':e.readiness==='approved_units_missing'?'يلزم اعتماد وحدات مستحقة؛ المسؤول: معد ومعتمد الرواتب.':'مدخلات قابلة للمراجعة؛ لم يُحسب مبلغ.'}</p>{access['payroll.prepare']&&e.pay_basis==='daily'&&<Link href={href({kind:'manual_units',head:'',employee:e.id})}>تحضير الوحدات المستحقة</Link>}</li>)}</ul>}{work.employees.length===30&&<Link href={href({after:work.employees[29].id,...clear})}>موظفون إضافيون</Link>}{query.after&&<Link href={href({after:'',...clear})}>أول صفحة موظفين</Link>}</section>
 {correctionResult?.error&&<p role="alert">تعذر تحميل مسؤوليات التصحيح لهذه الفترة. أعد المحاولة قبل مراجعة تاريخها.</p>}
 {corrections.length>0&&<section><h2>تاريخ راتب محمي ومسؤولية التصحيح</h2>{corrections.map(c=><div className={styles.card} key={c.employment_id}><p>{c.name} · {c.requested?'يوجد طلب تصحيح موثق.':'التغييرات المادية تتطلب طلب تصحيح.'}</p>{access['payroll.correct']&&access.enabled&&!c.requested&&<CorrectionForm tenant={tenantId} employer={employer} period={period} employment={c.employment_id} name={c.name}/>}</div>)}{corrections.length===50&&<p>النتائج محدودة؛ تواصل مع مسؤول الرواتب لمتابعة بقية مسؤوليات الفترة.</p>}</section>}
 <section><h2>المدخلات المحفوظة</h2>{records.length===0?<p>لم تُحفظ مدخلات لهذه الجهة والفترة بعد.</p>:<ul className={styles.periods}>{records.map(r=><li key={r.id} className={styles.card}><h3>{kindNames[r.kind]}{r.employee_name?` · ${r.employee_name}`:''}</h3><p>{String(r.data.name??r.data.reason)} · {statusNames[r.status]}</p><p>تبدأ {displayDate(r.effective_from)}{r.effective_until?` وتنتهي قبل ${displayDate(r.effective_until)}`:''}</p><Link href={href({kind:r.kind,head:r.id})}>عرض المدخل ومراجعته</Link></li>)}</ul>}{work.records_more&&<Link href={href({records_after:records[records.length-1].id,...clear})}>مدخلات إضافية</Link>}{query.records_after&&<Link href={href({records_after:'',...clear})}>أول صفحة مدخلات</Link>}</section>
 {access.enabled&&<nav className={styles.actions} aria-label="إضافة مدخل">{(Object.keys(kindNames) as InputKind[]).filter(k=>permission(k)&&!(k==='policy'&&records.some(r=>r.kind==='policy'))).map(k=><Link key={k} className="secondary-button" href={href({kind:k,head:''})}>{kindNames[k]}</Link>)}</nav>}
 {kind&&['recurring','adjustment'].includes(kind)&&!record&&work.component_choices_more&&<Link href={href({records_after:work.component_choices[work.component_choices.length-1].id})}>مكوّنات إضافية للاختيار</Link>}
 {kind&&<InputForm key={`${tenantId}:${employer}:${period}:${kind}:${record?.id??'new'}:${query.employee??''}`} tenant={tenantId} employer={employer} period={work.period} kind={kind} record={record} employees={[...work.employees].sort((a,b)=>a.id===query.employee?-1:b.id===query.employee?1:0).map(e=>({id:e.id,name:employeeName(e.id)}))} components={work.component_choices.filter(c=>kind==='recurring'?c.behavior==='recurring':c.behavior==='period_input'&&c.calculation==='fixed'&&c.classification!=='employer_cost').map(c=>({id:c.id,name:c.name}))} canSave={access.enabled&&permission(kind)} canApprove={access.enabled&&permission(kind,true)} back={back}/>}
 </div></PageFrame>;
}
