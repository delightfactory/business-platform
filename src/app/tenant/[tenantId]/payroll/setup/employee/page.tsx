import {PageFrame} from '@/components/context-navigation';
import {PageHeader,Panel,ButtonLink,Select,Button,Message,Input} from '@/components/ui';
import {getWorkspaceClient,getWorkspaceUser} from '@/lib/workspace-access';
import {notFound,redirect} from 'next/navigation';
import {uuid} from '../../rules';
import {EgyptForm,type EgyptContext} from './EgyptForm';
import styles from '../../payroll.module.css';
export const dynamic='force-dynamic';
export default async function EgyptSetupPage({params,searchParams}:{params:Promise<{tenantId:string}>;searchParams:Promise<Record<string,string|undefined>>}){
 const {tenantId}=await params;const q=await searchParams;
 if(!uuid(tenantId))notFound();
 const fromRun=q.task==='fix'&&uuid(q.period??'');
 const back=`/tenant/${tenantId}/payroll/${fromRun?'runs':'setup'}?${new URLSearchParams({employer:q.employer??'',period:q.period??''})}`;
 const error=(text:string)=><PageFrame><Panel><PageHeader title="تجهيز بيانات الموظف"/><Message tone="warn">{text}</Message><ButtonLink href={back}>العودة إلى إعداد الرواتب</ButtonLink></Panel></PageFrame>;
 if(!uuid(q.employer??'')||q.period&&!uuid(q.period)||q.employee&&!uuid(q.employee))return error('اختر جهة وفترة محفوظة أولًا.');
 const client=await getWorkspaceClient();if(!client)return error('تعذر الاتصال. أعد فتح الإعداد بنفس الفترة.');
 const {data:{user}}=await getWorkspaceUser(client);if(!user)redirect('/auth/login');
 if(!q.period){const periods=await client.rpc('payroll_input_periods',{p_tenant:tenantId,p_employer:q.employer});if(periods.error||!periods.data?.length)return error('احفظ دورة الرواتب وفترتها الأولى قبل تجهيز الموظفين.');redirect(`/tenant/${tenantId}/payroll/setup/employee?${new URLSearchParams({employer:q.employer!,period:periods.data[0].id})}`);}
 const result=await client.rpc('payroll_input_workspace',{p_tenant:tenantId,p_employer:q.employer,p_period:q.period,p_query:q.q??'',p_after:q.after??null,p_limit:30});
 if(result.error||!result.data)return error('تعذر تحميل الموظفين أو لا تتوفر صلاحية إعداد الرواتب.');
 const work=result.data as {access:Record<string,boolean>;employees:{id:string;full_name:string;employee_code:string}[];employees_more:boolean;period:{starts_on:string;ends_on:string}};
 if(!work.access['payroll.prepare'])return error('اطلب من مدير الشركة أو معد الرواتب استكمال الإعداد.');
 const employee=work.employees.find(e=>e.id===q.employee);
 const facts=employee?await client.rpc('payroll_egypt_setup_context',{p_tenant:tenantId,p_employer:q.employer,p_period:q.period,p_employment:employee.id}):null;
 const scope=new URLSearchParams({employer:q.employer!,period:q.period!});
 const review=`/tenant/${tenantId}/payroll/runs?${scope}`;
 const advanced=`/tenant/${tenantId}/payroll/inputs?${scope}&employee=${employee?.id??''}`;
 return <PageFrame><div dir="rtl" className={styles.workspace}><PageHeader title="تجهيز رواتب الموظفين" description="ابدأ بالأساس المصري، وعدّل ما يختلف في حالة الموظف."/>
 {!fromRun&&<><form method="get" className={styles.filters}><input type="hidden" name="employer" value={q.employer}/><input type="hidden" name="period" value={q.period}/><label>اسم الموظف أو رمزه<Input name="q" defaultValue={q.q??''} maxLength={120} placeholder="مثال: أحمد محمد"/></label><Button type="submit" variant="ghost">بحث</Button></form>
 <form method="get" className={styles.filters}><input type="hidden" name="employer" value={q.employer}/><input type="hidden" name="period" value={q.period}/><input type="hidden" name="q" value={q.q??''}/><label>الموظف<Select name="employee" defaultValue={employee?.id??''} required><option value="" disabled>اختر الموظف</option>{work.employees.map(e=><option value={e.id} key={e.id}>{e.full_name} · {e.employee_code}</option>)}</Select></label><Button type="submit">استكمال بياناته</Button></form>
 </>}
 {q.employee&&!employee&&<Message tone="warn">الموظف خارج نتائج البحث الحالية؛ ابحث باسمه أو رمزه. لم نختر موظفًا آخر بدلًا منه.</Message>}
 {work.employees.length===0&&<Message tone="info">لا يوجد موظف مطابق مشمول في رواتب هذه الفترة. راجع ملف الموظف وتفعيل إدراجه في الرواتب.</Message>}
 {employee&&<Panel className={styles.card}><h2>{employee.full_name}</h2>{facts?.data?<EgyptForm key={employee.id+q.period} tenant={tenantId} employer={q.employer!} period={q.period!} employment={employee.id} facts={facts.data as EgyptContext} advanced={advanced} review={review}/>:<Message tone="warn">تعذر تحميل إعداد الموظف. أعد فتح بياناته؛ لم يتغير شيء.</Message>}</Panel>}
 <nav className={styles.actions}><ButtonLink variant="ghost" href={back}>{fromRun?'العودة إلى نفس المسير':'إعداد رواتب الجهة'}</ButtonLink>{!fromRun&&<ButtonLink variant="ghost" href={review}>حساب ومراجعة الرواتب</ButtonLink>}<ButtonLink variant="ghost" href={advanced}>الإعدادات المتقدمة</ButtonLink></nav>
 </div></PageFrame>;
}
