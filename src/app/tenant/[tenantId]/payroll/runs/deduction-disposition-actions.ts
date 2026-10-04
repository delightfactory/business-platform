'use server';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {revalidatePath} from 'next/cache';
import {uuid} from '../rules';
import {inputError} from '../inputs/rules';
export type DispositionState={error:string;status:'idle'|'committed'|'not_committed'|'unresolved';result?:{original_amount:number;payroll_amount:number;residual_amount:number;disposition:string;retracted?:boolean}};
export async function deductionDispositionAction(previous:DispositionState,form:FormData):Promise<DispositionState>{
 const field=(key:string)=>String(form.get(key)??'').trim();
 const scope={p_tenant:field('tenant'),p_employer:field('employer'),p_period:field('period'),p_employment:field('employment'),p_claim:field('claim'),p_attempt:field('attempt')};
 if(![scope.p_tenant,scope.p_employer,scope.p_period,scope.p_employment,scope.p_attempt].every(uuid))return {status:'not_committed',error:inputError('22023')};
 const client=await createSupabaseServerClient();if(!client)return {...previous,status:'unresolved',error:'تعذر التحقق من نتيجة الطلب. استعد الإيصال قبل إنشاء طلب آخر.'};
 const {data:{user}}=await client.auth.getUser();if(!user)return {...previous,status:'unresolved',error:inputError('42501')};
 if(field('operation')==='recover'){
  const recovery=await client.rpc('payroll_deduction_reconcile',scope);
  if(recovery.error)return {...previous,status:'unresolved',error:inputError(recovery.error.code,recovery.error.message)};
  if(recovery.data.status==='committed'){revalidatePath(`/tenant/${scope.p_tenant}/payroll/runs`);return {status:'committed',error:'',result:recovery.data.result};}
  return {status:'not_committed',error:''};
 }
 if(field('operation')==='retract'){
  if(!uuid(field('disposition'))||field('confirmed')!=='yes')return {status:'not_committed',error:inputError('22023')};
  const result=await client.rpc('payroll_deduction_disposition_retract',{p_tenant:scope.p_tenant,p_employer:scope.p_employer,p_period:scope.p_period,p_disposition:field('disposition'),p_reference:field('reference'),p_reason:field('reason'),p_attempt:scope.p_attempt});
  if(result.error)return {status:'unresolved',error:inputError(result.error.code,result.error.message)};
  revalidatePath(`/tenant/${scope.p_tenant}/payroll/runs`);revalidatePath(`/tenant/${scope.p_tenant}/payroll/inputs`);return {status:'committed',error:'',result:result.data};
 }
 const args={...scope,p_run:field('run'),p_candidate:field('candidate'),p_revision:Number(field('revision')),p_payroll_amount:field('amount'),p_disposition:field('mode'),p_target_period:field('target')||null,p_occurred_on:field('date')||null,p_reference:field('reference'),p_reason:field('reason')};
 if(!uuid(args.p_run)||!uuid(args.p_candidate)||!Number.isSafeInteger(args.p_revision)||!/^\d{1,12}(\.\d{1,2})?$/.test(args.p_payroll_amount)||!['carry','external_settlement'].includes(args.p_disposition)||field('confirmed')!=='yes')return {status:'not_committed',error:inputError('22023')};
 const result=await client.rpc('payroll_deduction_disposition',args);
 if(result.error)return {status:'unresolved',error:inputError(result.error.code,result.error.message)};
 revalidatePath(`/tenant/${scope.p_tenant}/payroll/runs`);revalidatePath(`/tenant/${scope.p_tenant}/payroll/inputs`);
 return {status:'committed',error:'',result:result.data};
}
