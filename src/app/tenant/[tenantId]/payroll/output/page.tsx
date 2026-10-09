import { ButtonLink, Message, PageHeader, Panel, Avatar } from '@/components/ui';
import {EmployerSelector} from '../EmployerSelector';
import {normalizeEmployerScope} from '../employer-context';
import Link from 'next/link';
import {notFound,redirect} from 'next/navigation';
import {PageFrame} from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import {uuid,displayDate} from '../rules';
import {money} from '../runs/rules';
import styles from '../payroll.module.css';
export const dynamic='force-dynamic';
type Row={employment_id:string;employee:{name:string;code:string};net:string;explanation:{base:string;deductions:string;lines:{name:string;classification:string;amount:string;deduction_disposition?:{original_amount:number;payroll_amount:number;residual_amount:number;disposition:string;reference:string}}[]}};
type Output={output_id:string;legal_employer:{display_name:string;legal_name:string};period:{starts_on:string;ends_on:string};replacement_output_id?:string;superseded:boolean;employees:Row[]};
export default async function OutputPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<{employer_scope?:string;employer?:string;output?:string;after?:string}>}){
 const {tenantId}=await params,query=await searchParams;
 if(!uuid(tenantId))notFound();
 const path=`/tenant/${tenantId}/payroll/output`;
 const employerDestination=normalizeEmployerScope(path,'output',query);if(employerDestination)redirect(employerDestination);
 if(!uuid(query.employer??'')||!uuid(query.output??'')||(query.after&&!uuid(query.after)))notFound();
 const context=new URLSearchParams({employer:query.employer!,output:query.output!,...(query.after?{after:query.after}:{})});
 const client=await createSupabaseServerClient();
 const failure=(text:string)=><PageFrame><Panel dir="rtl" className={styles.card}><PageHeader  title={<>مسير الرواتب النهائي</>} /><Message tone="bad" role="alert">{text}</Message><Link href={`${path}?${context}`}>إعادة المحاولة بنفس المسير</Link></Panel></PageFrame>;
 if(!client)return failure('تعذر الاتصال بالمخرج المحفوظ.');
 const {data:{user}}=await getWorkspaceUser(client);if(!user)redirect(`/auth/login?next=${encodeURIComponent(`${path}?${context}`)}`);
 const response=await client.rpc('payroll_final_output',{p_tenant:tenantId,p_employer:query.employer,p_output:query.output,p_after:query.after??null,p_limit:30});
 if(response.error||!response.data)return failure('المخرج غير متاح أو لم يعد الحساب مخولًا لعرضه. مرشح المراجعة لا يُعرض كقسيمة راتب.');
 const employerList=await client.rpc('payroll_report_employers',{p_tenant:tenantId,p_report:'sheet',p_query:'',p_after_name:null,p_after_id:null});
 const result=response.data as Output;const correctionAccess=await client.rpc('payroll_correction_access',{p_tenant:tenantId});
 return <PageFrame><section dir="rtl" className={styles.workspace}>
 <div><PageHeader  title={<>مسير الرواتب النهائي</>} /><h2>{result.legal_employer.display_name}</h2><p>الجهة القانونية: {result.legal_employer.legal_name}</p><p>{displayDate(result.period.starts_on)} — {displayDate(result.period.ends_on)}</p>{!employerList.error&&<EmployerSelector path={path} page="output" employer={query.employer!} name={result.legal_employer.display_name} hint="تغيير الجهة يفتح تقاريرها لاختيار النسخة؛ احفظ تعديلاتك قبل الانتقال." choices={employerList.data?.items??[]} context={query}/>}{employerList.error&&<p className="field-hint">{employerList.error?.code==='42501'?'اختيار جهة أخرى يحتاج إلى مسؤول مخول بعرض تقارير الرواتب.':employerList.error?'تعذر تحميل قائمة الجهات. أعد اختيار الجهة والنسخة من التقارير.':'عند تغيير الجهة تختار نسختها النهائية من التقارير.'}</p>}{employerList.error?.code!=='42501'&&<Link href={`/tenant/${tenantId}/payroll/reports?report=sheet`}>اختيار جهة ونسخة أخرى</Link>}</div>
 {result.superseded?<Message tone="bad" role="alert">استُبدل هذا المخرج. يُعرض للتاريخ فقط؛ لا تستخدمه للتوزيع أو الصرف.</Message>:<p>هذه النسخة محفوظة من المسير النهائي. تُسجّل عمليات عرضها وتصديرها حسب الصلاحيات.</p>}
 <nav className={styles.reviewNavigation} aria-label="أدوات المخرج">
 {result.replacement_output_id&&<ButtonLink className={result.superseded?'':''} href={`${path}?${new URLSearchParams({employer:query.employer!,output:result.replacement_output_id})}`}>فتح المخرج البديل</ButtonLink>}
 {!result.superseded&&correctionAccess.data?.can_correct&&<Link href={`/tenant/${tenantId}/payroll/corrections?${context}`}>إعداد تصحيح مؤرخ مع حفظ الأصل</Link>}
 {!result.superseded&&<a href={`${path}/export?${context}`}>تنزيل كشف هذه الصفحة حسب صلاحية التصدير</a>}
 <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/payroll/payments?${new URLSearchParams({employer:query.employer!,output:query.output!})}`}>مطابقة الدفعات الخارجية</ButtonLink>
 <Link href={`/tenant/${tenantId}/payroll/runs?${new URLSearchParams({employer:query.employer!})}`}>العودة إلى مراجعة الرواتب</Link>
 </nav>
 <div className={styles.outputCards}>{result.employees.map(e=><Panel as="article" key={e.employment_id} className={styles.card}><div className={styles.recordHeading}><Avatar name={e.employee.name}/><h2>{e.employee.name} · <bdi>{e.employee.code}</bdi></h2></div><dl className={styles.figureStrip}><div><dt>الأجر الأساسي</dt><dd>{money(e.explanation.base)}</dd></div><div><dt>{result.superseded?'صافي الراتب المحفوظ للتاريخ (مسير مستبدل)':'صافي الراتب'}</dt><dd>{money(e.net)}</dd></div></dl><ul>{e.explanation.lines.map((line,i)=><li key={i}>{line.name} · {money(line.amount)}{line.deduction_disposition&&<p>أصل الالتزام {money(line.deduction_disposition.original_amount)}؛ خصم هذه الفترة {money(line.deduction_disposition.payroll_amount)}؛ المتبقي {money(line.deduction_disposition.residual_amount)} — {line.deduction_disposition.disposition==='carry'?'مرحّل إلى فترة لاحقة':'سُوّي خارج الرواتب'}، المرجع: {line.deduction_disposition.reference}.</p>}</li>)}</ul></Panel>)}</div>
 {result.employees.length===30&&<Link href={`${path}?${new URLSearchParams({employer:query.employer!,output:query.output!,after:result.employees[29].employment_id})}`}>موظفون إضافيون</Link>}
 </section></PageFrame>;
}
