import Link from 'next/link';
import {notFound,redirect} from 'next/navigation';
import {PageFrame} from '@/components/context-navigation';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid,displayDate} from '../rules';
import {money} from '../runs/rules';
import {PaymentForm} from './PaymentForm';
import {paymentError,type PaymentEmployee} from './rules';
import styles from '../payroll.module.css';
export const dynamic='force-dynamic';
type History={id:string;kind:string;original_event:string|null;paid_on:string;reference:string;reason:string;actor_label:string;amount:string;employee_count:number;compensated:boolean};
type Workspace={access:{can_record:boolean;can_correct_record:boolean;enabled:boolean};today:string;output_id:string;employer:{display_name:string};period:{starts_on:string;ends_on:string};revision:number;selected_entry:{reference:string;kind:string;paid_on:string}|null;summary:{payable:string;recorded:string;compensated:string;paid:string;remaining:string;remaining_count:number;status:string;ever_paid:boolean};employees:PaymentEmployee[];history:History[];superseded:boolean};
export default async function PaymentsPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<Record<string,string|undefined>>}){
 const {tenantId}=await params,query=await searchParams;if(!uuid(tenantId))notFound();
 const path=`/tenant/${tenantId}/payroll/payments`,keep=Object.fromEntries(Object.entries(query).filter((x):x is [string,string]=>typeof x[1]==='string'));
 const href=(extra:Record<string,string>)=>`${path}?${new URLSearchParams({...keep,...extra})}`;
 const failure=(text:string)=><PageFrame><section dir="rtl" className={styles.card}><h1>مطابقة الدفعات الخارجية</h1><p role="alert">{text}</p><Link href={href({})}>إعادة المحاولة بنفس المخرج</Link></section></PageFrame>;
 for(const key of ['employer','output','after','history_before','event'])if(query[key]&&!uuid(query[key]!))return failure('راجع رابط الجهة والمخرج النهائي.');
 if((query.q?.length??0)>120)return failure('اختصر اسم الموظف أو رمزه في البحث.');
 const client=await createSupabaseServerClient();if(!client)return failure('تعذر الاتصال بسجل الدفعات.');
 const {data:{user}}=await client.auth.getUser();if(!user)redirect(`/auth/login?next=${encodeURIComponent(href({}))}`);
 const access=await client.rpc('payroll_payment_access',{p_tenant:tenantId});if(access.error)return failure(paymentError(access.error.code,access.error.message));
 if(!query.employer||!query.output)return <PageFrame><section dir="rtl" className={styles.card}><h1>مطابقة الدفعات الخارجية</h1><p>اختر مخرجًا نهائيًا محفوظًا. المرشح التشغيلي لا ينشئ مبلغًا صالحًا للصرف قبل التأهيل القانوني والإقفال.</p>{access.data?.can_review_entry?<Link href={`/tenant/${tenantId}/payroll/runs`}>اختيار مسير من مراجعة الرواتب</Link>:<p>اطلب من مسؤول الرواتب رابط المخرج الذي يخص مهمتك.</p>}</section></PageFrame>;
 const response=await client.rpc('payroll_payment_workspace',{p_tenant:tenantId,p_employer:query.employer,p_output:query.output,p_query:query.q??'',p_after:query.after||null,p_history_before:query.history_before||null,p_event:query.event||null});
 if(response.error||!response.data)return failure(paymentError(response.error?.code,response.error?.message));
 const correctionAccess=await client.rpc('payroll_correction_access',{p_tenant:tenantId});
  const w=response.data as Workspace,s=w.summary,canRecord=w.access.can_record&&!w.superseded;
  const today=w.today;
  const pendingRequest=canRecord?await client.rpc('payroll_payment_request_get',{p_tenant:tenantId,p_employer:query.employer,p_output:query.output}):{data:null};
  if('error' in pendingRequest&&pendingRequest.error)return failure('تعذر التحقق من الطلب المعلّق. أعد المحاولة قبل تسجيل دفعة جديدة.');
  const recoveryAttempt=typeof pendingRequest.data?.attempt==='string'?pendingRequest.data.attempt:undefined;
  const props={actor:user.id,tenant:tenantId,employer:query.employer,output:query.output,revision:w.revision,today,employees:w.employees,remaining:s.remaining,remainingCount:s.remaining_count,recoveryAttempt};
 return <PageFrame><div dir="rtl" className={styles.workspace}><header><h1>مطابقة الدفعات الخارجية</h1><h2>{w.employer.display_name}</h2><p>{displayDate(w.period.starts_on)} — {displayDate(w.period.ends_on)}</p></header>
 <section id="payroll-payment-summary" className={styles.card}><h2>{w.superseded?'مخرج مستبدل للتاريخ':s.status==='paid'?'تم تسجيل كامل المستحق':s.status==='partially_paid'?'تم تسجيل جزء من المستحق':'لا توجد دفعات قائمة في المطابقة'}</h2><dl className={styles.figureStrip} aria-label={w.superseded?'مطابقة تاريخ المخرج المستبدل':'مطابقة المخرج الحالي'}><div><dt>{w.superseded?'المتبقي في سجل المخرج المستبدل':'المتبقي للتسجيل'}</dt><dd>{money(s.remaining)}</dd></div><div><dt>المسجل بعد التصحيح</dt><dd>{money(s.paid)}</dd></div></dl><details><summary>تفصيل المطابقة</summary><p>المستحق النهائي {money(s.payable)} · الدفعات الأصلية {money(s.recorded)} · تصحيح القيود {money(s.compensated)}</p></details>{s.ever_paid&&<p>سبق تسجيل صرف لهذا المسير؛ يظل هذا التاريخ محفوظًا حتى بعد تصحيح قيد خاطئ.</p>}{!w.access.enabled&&canRecord&&<p>الخدمة غير مفعلة لأعمال جديدة؛ يقتصر الإجراء هنا على إغلاق هذا الالتزام النهائي المحفوظ.</p>}</section>
 <PaymentForm {...props} recoveryOnly/>
 <nav className={styles.reviewNavigation} aria-label="أقسام مطابقة الدفعات"><a href="#payroll-payment-summary">ملخص المطابقة</a><a href="#payroll-payment-employees">مطابقة الموظفين</a><a href="#payroll-payment-history">سجل الدفعات</a></nav>
 <section id="payroll-payment-employees" className={styles.card}><h2>{w.selected_entry?`تخصيص القيد: ${w.selected_entry.reference}`:'مطابقة الموظفين'}</h2>{w.selected_entry&&<Link href={href({event:'',after:''})}>العودة إلى جميع الموظفين</Link>}<form method="get" className={styles.filters}><input type="hidden" name="employer" value={query.employer}/><input type="hidden" name="output" value={query.output}/><label>اسم الموظف أو رمزه<input name="q" defaultValue={query.q??''} maxLength={120}/></label><button className="secondary-button">بحث</button></form>{w.employees.map(e=><article key={e.employment_id}><h3>{e.employee_snapshot.name} · <bdi>{e.employee_snapshot.code}</bdi></h3>{e.entry_amount!=null&&<p>مبلغ هذا القيد {money(e.entry_amount)}</p>}<p>المستحق {money(e.payable)} · المسجل {money(e.paid)} · المتبقي {money(e.remaining)}</p></article>)}{w.employees.length===0&&<p>لا يوجد موظف مطابق لهذا البحث في المخرج.</p>}{w.employees.length===30&&<Link href={href({after:w.employees[29].employment_id})}>موظفون إضافيون</Link>}</section>

 {canRecord&&s.remaining_count>0?<section className={styles.card}><PaymentForm key={query.output} {...props}/></section>:!w.access.can_record?<p>لتسجيل دفعة أو تصحيح قيد خاطئ، راجع مسؤول تسجيل دفعات الرواتب.</p>:null}
 {!w.superseded&&correctionAccess.data?.can_correct&&<Link href={`/tenant/${tenantId}/payroll/corrections?${new URLSearchParams({employer:query.employer!,output:query.output!})}`}>تصحيح مصدر الراتب مع حفظ سجل الدفع الأصلي</Link>}
 <details id="payroll-payment-history" className={styles.card}><summary>سجل الدفعات وتصحيح القيود</summary>{w.history.length===0?<p>لم تُسجّل دفعة لهذا المخرج بعد.</p>:w.history.map(e=><article key={e.id}><h3>{e.kind==='compensation'?'تصحيح قيد خاطئ':e.compensated?'دفعة صُحح قيدها بالكامل':'دفعة خارجية مسجلة'} · {money(e.amount)}</h3><p>{displayDate(e.paid_on)} · المرجع: <bdi>{e.reference}</bdi> · {e.employee_count} موظفًا</p><Link href={href({event:e.id,after:''})}>عرض تخصيص هذا القيد للموظفين</Link><p>{e.reason}</p><p>سجّل القيد: <bdi>{e.actor_label}</bdi></p>{canRecord&&w.access.can_correct_record&&e.kind==='payment'&&!e.compensated&&<details><summary>القيد مسجل بالخطأ؟</summary><PaymentForm {...props} original={e.id} originalAmount={e.amount}/></details>}{canRecord&&!w.access.can_correct_record&&e.kind==='payment'&&!e.compensated&&<p>لتصحيح قيد خاطئ، راجع مسؤول تصحيح الرواتب المخول بتسجيل الدفعات.</p>}</article>)}{w.history.length===20&&<Link href={href({history_before:w.history[19].id})}>قيود أقدم</Link>}</details>
 {access.data?.can_review_entry&&<Link href={`/tenant/${tenantId}/payroll/runs?${new URLSearchParams({employer:query.employer})}`}>العودة إلى مراجعة الرواتب</Link>}
 </div></PageFrame>;
}
