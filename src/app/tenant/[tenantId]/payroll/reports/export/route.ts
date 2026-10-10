import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../../rules';
import {csvDocument,isReportKind,type ReportRow,type ReportWorkspace} from '../rules';
export const dynamic='force-dynamic';
const maximumBytes=20*1024*1024;
const labels:Record<string,string>={base:'الأجر الأساسي',gross:'إجمالي الاستحقاقات',deductions:'الخصومات الأخرى',statutory_deductions:'خصومات الضريبة والتأمينات',net:'صافي الراتب',paid:'المدفوع المسجل',remaining:'المتبقي للصرف',previous:'صافي الفترة السابقة',difference:'فرق الصافي',principal:'أصل السلفة',outstanding:'الرصيد المتبقي',amount:'قيمة البند',insured_wage:'الأجر التأميني'};
export async function GET(request:Request,{params}:{params:Promise<{tenantId:string}>}){
 const {tenantId}=await params,q=new URL(request.url).searchParams,employer=q.get('employer')??'',report=q.get('report')??'sheet';
 const fail=(error:string,status:number)=>Response.json({error},{status,headers:{'Cache-Control':'private, no-store'}});
 if(!uuid(tenantId)||!uuid(employer)||!isReportKind(report))return fail('راجع الجهة ونوع التقرير.',400);
 const output=report==='advances'?null:q.get('output')||null,previous=report==='variance'?q.get('previous')||null:null,employee=['advances','variance'].includes(report)?null:q.get('employee')||null,query=q.get('q')??'',site=report==='advances'?null:q.get('site')||null,department=report==='advances'?null:q.get('department')||null;
 if((report!=='advances'&&!output)||[output,previous,employee,site,department].some(id=>id&&!uuid(id))||query.length>120)return fail('راجع النسخة النهائية والفترة السابقة والموظف.',400);
 const client=await createSupabaseServerClient();if(!client)return fail('تعذر الاتصال بالتقرير المحفوظ.',503);
 const {data:{user}}=await client.auth.getUser();if(!user)return fail('سجّل الدخول ثم أعد تنزيل التقرير.',401);
 const args={p_tenant:tenantId,p_employer:employer,p_output:output,p_report:report,p_previous:previous,p_employee:employee,p_query:query,p_site:site,p_department:department,p_limit:50,p_export:true};
 let cursor:string|null=null,workspace:ReportWorkspace|null=null,source=q.get('revision')||null,bytes=0;
 const records:ReportRow[]=[],seen=new Set<string>();
 // Every response is collected and proved complete before sending the CSV body.
 // A changed source or denied later page produces an error, not a partial report.
 for(let page=0;;page++){
  const response=await client.rpc('payroll_report_workspace',{...args,p_after:cursor,p_expected_revision:source});
  if(response.error||!response.data)return fail(response.error?.code==='PT409'?'تغير التقرير أثناء جمعه. حدّث التقرير ثم أعد التصدير.':'التصدير غير متاح بهذه الصلاحية أو النسخة؛ لم يُصدر ملف جزئي.',response.error?.code==='PT409'?409:403);
  const current=response.data as ReportWorkspace;
  if(!Number.isSafeInteger(current.total_count)||current.total_count<0||!Array.isArray(current.rows)||current.rows.length>50||current.issues.length||current.superseded)return fail('تعذر إثبات اكتمال التقرير. لم يُصدر ملف جزئي.',409);
  if(!workspace){workspace=current;source=current.source_revision;}
  if(current.source_revision!==source||current.total_count!==workspace.total_count||JSON.stringify(current.summary)!==JSON.stringify(workspace.summary))return fail('تغيرت أرقام التقرير أثناء جمعه. حدّث التقرير ثم أعد التصدير.',409);
  if(page>Math.ceil(workspace.total_count/50))return fail('تعذر استكمال صفحات التقرير. لم يُصدر ملف جزئي.',409);
  for(const row of current.rows){if(!uuid(row.id)||seen.has(row.id))return fail('تعذر مطابقة سجلات التقرير. لم يُصدر ملف جزئي.',409);seen.add(row.id);records.push(row);bytes+=Buffer.byteLength(JSON.stringify(row),'utf8');}
  if(bytes>maximumBytes)return fail('نطاق التصدير كبير. حدّد اسم الموظف أو كوده لتصدير نطاق أصغر.',413);
  if(records.length>workspace.total_count)return fail('تعذر مطابقة العدد الإجمالي للتقرير.',409);
  if(!current.next)break;
  if(current.rows.length===0||!uuid(current.next)||cursor&&current.next<=cursor||current.next!==current.rows[current.rows.length-1].id)return fail('تعذر استكمال صفحات التقرير. لم يُصدر ملف جزئي.',409);
  cursor=current.next;
 }
 if(!workspace||records.length!==workspace.total_count)return fail('لم تكتمل سجلات التقرير. لم يُصدر ملف جزئي.',409);
 const verified=await client.rpc('payroll_report_workspace',{...args,p_after:null,p_limit:1,p_expected_revision:source});
 if(verified.error||verified.data?.source_revision!==source||verified.data?.total_count!==records.length)return fail('تغير المصدر أو الصلاحية قبل اكتمال التصدير. حدّث التقرير ثم أعد المحاولة.',409);
 const columns=report==='payments'?['net','paid','remaining']:report==='variance'?['net','previous','difference']:report==='advances'?['principal','outstanding']:report==='components'?['amount']:report==='statutory'?['insured_wage','statutory_deductions','net']:['base','gross','deductions','statutory_deductions','net'];
 const withStatus=['variance','advances','components'].includes(report);
 const statusLabels:Record<string,string>={active:'نشطة',settled:'مسددة',record_corrected:'تسجيل خاطئ صُحح',new:'ظهر في نطاق الفترة الحالية',left:'غير موجود في نطاق الفترة الحالية',continuing:'موجود في نطاق الفترتين',earning:'استحقاق',deduction:'خصم',employer_cost:'تكلفة صاحب العمل'};
 const header=['الجهة القانونية','بداية الفترة','نهاية الفترة','الموظف أو البند','كود الموظف',...columns.map(key=>labels[key]),...(withStatus?['الحالة']:[]),...(report==='statutory'?['سنة الحساب','الفئة المحفوظة','أشهر الالتزام','مصدر الأجر التأميني']:[])];
 const rows=records.map(row=>[workspace!.employer.legal_name,workspace!.period?.starts_on??'',workspace!.period?.ends_on??'',row.employee?.name??row.label??'',row.employee?.code??'',...columns.map(key=>String(row[key as keyof ReportRow]??'')),...(withStatus?[row.status?statusLabels[row.status]??'تحتاج إلى مراجعة':'']:[]),...(report==='statutory'?[String(row.statutory_context?.calendar_year??''),row.statutory_context?.category??'',row.statutory_context?.obligation_months?.join('، ')??'',row.statutory_context?.insured_wage_source??'']:[])]);
 const body=csvDocument([header,...rows]);if(Buffer.byteLength(body,'utf8')>maximumBytes)return fail('نطاق التصدير كبير. حدّد اسم الموظف أو كوده لتصدير نطاق أصغر.',413);
 return new Response(body,{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':`attachment; filename="payroll-${report}.csv"`,'Cache-Control':'private, no-store'}});
}
