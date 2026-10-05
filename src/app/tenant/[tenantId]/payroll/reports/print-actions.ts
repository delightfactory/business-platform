'use server';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../rules';
export type PayslipPrintScope={tenant:string;employer:string;output:string;employee:string;revision:string;site:string|null;department:string|null;query:string};
export async function authorizePayslipPrint(scope:PayslipPrintScope):Promise<{allowed:boolean;error:string}>{
 if(!scope||![scope.tenant,scope.employer,scope.output,scope.employee].every(uuid)||[scope.site,scope.department].some(id=>id!==null&&!uuid(id))||typeof scope.query!=='string'||scope.query.length>120||typeof scope.revision!=='string'||!/^[a-f0-9]{32}$/.test(scope.revision))return {allowed:false,error:'راجع الجهة والموظف والنسخة قبل طباعة القسيمة.'};
 const client=await createSupabaseServerClient();if(!client)return {allowed:false,error:'تعذر الاتصال. أعد طلب الطباعة بعد عودة الاتصال.'};
 const {data:{user}}=await client.auth.getUser();if(!user)return {allowed:false,error:'سجّل الدخول ثم افتح القسيمة من جديد.'};
 const result=await client.rpc('payroll_report_workspace',{p_tenant:scope.tenant,p_employer:scope.employer,p_output:scope.output,p_report:'payslip',p_employee:scope.employee,p_query:scope.query,p_site:scope.site,p_department:scope.department,p_limit:1,p_expected_revision:scope.revision,p_export:true});
 if(result.error)return {allowed:false,error:result.error.code==='PT409'?'تغيرت النسخة منذ فتحها. حدّث القسيمة قبل الطباعة.':'الطباعة غير متاحة بهذه الصلاحية أو النسخة. راجع مسؤول الرواتب.'};
 if(!result.data||result.data.source_revision!==scope.revision||result.data.superseded||result.data.issues?.length!==0||result.data.total_count!==1||result.data.rows?.length!==1||result.data.rows[0].id!==scope.employee)return {allowed:false,error:'لم تُثبت صلاحية القسيمة للتوزيع. حدّثها وراجع التفاصيل.'};
 return {allowed:true,error:''};
}
