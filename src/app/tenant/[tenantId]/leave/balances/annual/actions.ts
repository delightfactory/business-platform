'use server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject,isUuid } from '../../rules';
import { annualError,readPolicy,readQuote,type AnnualState } from './rules';
export async function annualAction(previous:AnnualState,form:FormData):Promise<AnnualState>{
 const field=(name:string)=>String(form.get(name)??'').trim();
 const intent=field('intent');
 const fail=(message:string):AnnualState=>({...previous,quote:intent==='preview'?null:previous.quote,error:annualError(message),message:'',posted:false});
 const tenant=field('tenant'),employer=field('employer'),employee=field('employee'),type=field('type'),period=field('period');
 if(![tenant,employer,employee,type,period].every(isUuid))return fail('input_invalid');
 const supabase=await createSupabaseServerClient();if(!supabase)return fail('connection');
 const {data:{user}}=await supabase.auth.getUser();if(!user)return fail('forbidden');
 if(intent==='policy'){
  if(['policyVersion','firstYear','laterYear','minimumService','yearDays'].some(k=>!/^\d+(\.\d{1,2})?$/.test(field(k))))return fail('input_invalid');
  if(['policyVersion','minimumService','yearDays'].some(k=>!Number.isInteger(Number(field(k)))))return fail('input_invalid');
  const {data,error}=await supabase.rpc('leave_save_annual_policy',{p_tenant:tenant,p_employer:employer,p_type:type,p_expected_version:Number(field('policyVersion')),p_first_year_days:Number(field('firstYear')),p_later_year_days:Number(field('laterYear')),p_minimum_service_days:Number(field('minimumService')),p_year_days:Number(field('yearDays')),p_source:field('policySource'),p_reason:field('policyReason')});
  if(error)return fail(error.message);const policy=readPolicy(data);if(!policy)return fail('unknown');
  return {...previous,policy,quote:null,posted:false,error:'',message:'تم حفظ نسخة جديدة من قاعدة الشركة.',accountId:null};
 }
 if(intent!=='preview'&&intent!=='post')return fail('input_invalid');
 let rates:unknown;try{rates=JSON.parse(field('rates'));}catch{return fail('rates_invalid');}
 if(!Array.isArray(rates)||!/^\d{4}-\d{2}-\d{2}$/.test(field('asOf')))return fail('input_invalid');
 const payload={p_tenant:tenant,p_employee:employee,p_employer:employer,p_type:type,p_period:period,p_as_of:field('asOf'),p_rates:rates,p_source:field('source')};
 if(intent==='preview'){
  const {data,error}=await supabase.rpc('leave_preview_annual_entitlement',payload);if(error)return fail(error.message);
  const quote=readQuote(data);if(!quote)return fail('unknown');return {...previous,quote,posted:false,error:'',message:'راجع الحساب قبل تسجيل الفرق في الرصيد.',accountId:null,reviewedInput:JSON.stringify([payload.p_as_of,payload.p_source,payload.p_rates])};
 }
 if(!isUuid(field('operationKey'))||!/^[a-f0-9]{64}$/.test(field('reviewHash')))return fail('input_invalid');
 const {data,error}=await supabase.rpc('leave_post_annual_entitlement',{...payload,p_review_hash:field('reviewHash'),p_reason:field('reason'),p_key:field('operationKey')});
 if(error)return fail(error.message);if(!isObject(data)||!['posted','up_to_date'].includes(String(data.state)))return fail('unknown');
 return {...previous,error:'',posted:true,quote:readQuote(data.quote),accountId:isUuid(data.account_id)?data.account_id:null,message:data.state==='up_to_date'?'الاستحقاق مسجّل حتى هذا التاريخ؛ لم تُضف حركة أخرى.':'تم تسجيل فرق الاستحقاق السنوي في الرصيد.'};
}
