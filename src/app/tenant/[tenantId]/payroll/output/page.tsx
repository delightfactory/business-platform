import Link from 'next/link';
import {notFound,redirect} from 'next/navigation';
import {PageFrame} from '@/components/context-navigation';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid,displayDate} from '../rules';
import {money} from '../runs/rules';
import styles from '../payroll.module.css';
export const dynamic='force-dynamic';
type Row={employment_id:string;employee:{name:string;code:string};net:string;explanation:{base:string;deductions:string;lines:{name:string;classification:string;amount:string}[]}};
type Output={output_id:string;legal_employer:{display_name:string;legal_name:string};period:{starts_on:string;ends_on:string};replacement_output_id?:string;superseded:boolean;employees:Row[]};
export default async function OutputPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<{employer?:string;output?:string;after?:string}>}){
 const {tenantId}=await params,query=await searchParams;
 if(!uuid(tenantId)||!uuid(query.employer??'')||!uuid(query.output??'')||(query.after&&!uuid(query.after)))notFound();
 const context=new URLSearchParams({employer:query.employer!,output:query.output!,...(query.after?{after:query.after}:{})});
 const path=`/tenant/${tenantId}/payroll/output`,client=await createSupabaseServerClient();
 const failure=(text:string)=><PageFrame><section dir="rtl" className={styles.card}><h1>مخرجات الرواتب النهائية</h1><p role="alert">{text}</p><Link href={`${path}?${context}`}>إعادة المحاولة بنفس المخرج</Link></section></PageFrame>;
 if(!client)return failure('تعذر الاتصال بالمخرج المحفوظ.');
 const {data:{user}}=await client.auth.getUser();if(!user)redirect(`/auth/login?next=${encodeURIComponent(`${path}?${context}`)}`);
 const response=await client.rpc('payroll_final_output',{p_tenant:tenantId,p_employer:query.employer,p_output:query.output,p_after:query.after??null,p_limit:30});
 if(response.error||!response.data)return failure('المخرج غير متاح أو لم يعد الحساب مخولًا لعرضه. مرشح المراجعة لا يُعرض كقسيمة راتب.');
 const result=response.data as Output;
 return <PageFrame><section dir="rtl" className={styles.workspace}><header><h1>مخرجات الرواتب النهائية</h1><h2>{result.legal_employer.display_name}</h2><p>الجهة القانونية: {result.legal_employer.legal_name}</p><p>{displayDate(result.period.starts_on)} — {displayDate(result.period.ends_on)}</p></header>{result.superseded?<p role="alert">استُبدل هذا المخرج. يُعرض للتاريخ فقط؛ لا تستخدمه للتوزيع أو الصرف.</p>:<p>هذه النسخة محفوظة من المسير النهائي. تُسجّل عمليات عرضها وتصديرها حسب الصلاحيات.</p>}{result.replacement_output_id&&<Link href={`${path}?${new URLSearchParams({employer:query.employer!,output:result.replacement_output_id})}`}>فتح المخرج البديل</Link>}{result.employees.map(e=><article key={e.employment_id} className={styles.card}><h2>{e.employee.name} · <bdi>{e.employee.code}</bdi></h2><p>الأجر الأساسي {money(e.explanation.base)}</p><ul>{e.explanation.lines.map((line,i)=><li key={i}>{line.name} · {money(line.amount)}</li>)}</ul><p>صافي الراتب {money(e.net)}</p></article>)}{!result.superseded&&<p><a href={`${path}/export?${context}`}>تنزيل كشف هذه الصفحة حسب صلاحية التصدير</a></p>}{result.employees.length===30&&<Link href={`${path}?${new URLSearchParams({employer:query.employer!,output:query.output!,after:result.employees[29].employment_id})}`}>موظفون إضافيون</Link>}<Link href={`/tenant/${tenantId}/payroll/payments?${new URLSearchParams({employer:query.employer!,output:query.output!})}`}>مطابقة الدفعات الخارجية</Link><Link href={`/tenant/${tenantId}/payroll/runs?${new URLSearchParams({employer:query.employer!})}`}>العودة إلى مراجعة الرواتب</Link></section></PageFrame>;
}
