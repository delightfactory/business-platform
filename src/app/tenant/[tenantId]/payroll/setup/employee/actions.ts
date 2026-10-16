'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../../rules';
import {inputError} from '../../inputs/rules';
export type EgyptState={saved:boolean;error:string;attempt:string;signature:string;head?:string};
export async function prepareEgyptEmployee(previous:EgyptState,form:FormData):Promise<EgyptState>{
 const field=(key:string)=>String(form.get(key)??'').trim();
 const scope={p_tenant:field('tenant'),p_employer:field('employer'),p_period:field('period'),p_employment:field('employment'),p_stamp:field('stamp')};
 if(![scope.p_tenant,scope.p_employer,scope.p_period,scope.p_employment].every(uuid))return {...previous,saved:false,error:'راجع الموظف والفترة ثم أعد فتح الإعداد.'};
 const choices=Object.fromEntries(['insurance_status','insured_wage','insurance_from','insurance_until','insurance_month_disposition','tax_duration_days','tax_treatment_code','insurance_category','no_prior_income'].map(k=>[k,field(k)]));
 const signature=JSON.stringify({...scope,p_choices:choices});
 const attempt=previous.signature===signature?previous.attempt:crypto.randomUUID();
 const state={saved:false,error:'',attempt,signature};
 const client=await createSupabaseServerClient();if(!client)return {...state,error:inputError()};
 const {data,error}=await client.rpc('payroll_prepare_egypt_employee',{...scope,p_choices:choices,p_attempt:attempt});
 if(error){const messages:Record<string,string>={payroll_egypt_opening_required:'اختر وضع الأرصدة السابقة. إذا كانت موجودة، سجّلها من الإعداد المتقدم أولًا.',payroll_egypt_duration_required:'حدد أيام العمل المستحقة للأجر اليومي أو راجع مدة الحساب في الخيارات المتقدمة.',payroll_egypt_insurance_choice_required:'حدد هل تُسجّل تأمينات الشهر ضمن هذه الفترة الجزئية.',payroll_egypt_scope_unavailable:'هذه الحالة تحتاج الإعداد المتقدم أو إعداد نسخة مصرية سارية من مشغّل المنصة.'};return {...state,error:messages[error.message]??inputError(error.code,error.message)};}
 revalidatePath(`/tenant/${scope.p_tenant}/payroll`);
 return {...state,saved:true,error:'',head:data?.context?.id};
}
