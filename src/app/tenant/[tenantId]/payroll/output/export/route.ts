import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../../rules';
export const dynamic='force-dynamic';
function csv(value:string){const safe=/^[=+\-@\t\r]/.test(value)?`'${value}`:value;return `"${safe.replace(/"/g,'""')}"`;}
export async function GET(request:Request,{params}:{params:Promise<{tenantId:string}>}){
 const {tenantId}=await params,query=new URL(request.url).searchParams,employer=query.get('employer')??'',output=query.get('output')??'',after=query.get('after');
 if(![tenantId,employer,output].every(uuid)||(after&&!uuid(after)))return Response.json({error:'راجع رابط المسير والجهة.'},{status:400});
 const client=await createSupabaseServerClient();if(!client)return Response.json({error:'تعذر الاتصال.'},{status:503});
 const {data:{user}}=await client.auth.getUser();if(!user)return Response.json({error:'سجّل الدخول ثم أعد تنزيل الصفحة.'},{status:401});
 const response=await client.rpc('payroll_final_output',{p_tenant:tenantId,p_employer:employer,p_output:output,p_after:after,p_limit:30,p_export:true});
 if(response.error||!response.data)return Response.json({error:'التصدير غير متاح؛ راجع صلاحية التصدير وحالة المسير المحفوظ.'},{status:403});
 const rows=response.data.employees as {employee:{name:string;code:string};net:string;explanation:{base:string;deductions:string}}[];
 const header=['الجهة القانونية','بداية الفترة','نهاية الفترة','الموظف','كود الموظف','الأجر الأساسي','الخصومات الأخرى','صافي الراتب'];
 const lines=[header,...rows.map(r=>[response.data.legal_employer.legal_name,response.data.period.starts_on,response.data.period.ends_on,r.employee.name,r.employee.code,r.explanation.base??'',r.explanation.deductions??'',r.net])];
 return new Response('\ufeff'+lines.map(line=>line.map(csv).join(',')).join('\r\n'),{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':'attachment; filename="payroll-page.csv"','Cache-Control':'private, no-store'}});
}
