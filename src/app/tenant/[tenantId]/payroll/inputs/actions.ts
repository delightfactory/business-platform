'use server';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {revalidatePath} from 'next/cache';
import {uuid} from '../rules';
import {inputFields,inputError,type InputKind,type InputState} from './rules';
export async function inputAction(previous:InputState,form:FormData):Promise<InputState> {
 const field=(key:string)=>String(form.get(key)??'').trim();
 const tenant=field('tenant'),employer=field('employer'),kind=field('kind') as InputKind,operation=field('operation');
 const fail=(code?:string,message?:string)=>({...previous,error:inputError(code,message),saved:false});
 if(!uuid(tenant)||!uuid(employer)||!Object.hasOwn(inputFields,kind)||!['save','approve','cancel'].includes(operation)) return fail('22023');
 const data=Object.fromEntries(inputFields[kind].map(key=>[key,field(key)]));
 const args={p_tenant:tenant,p_employer:employer,p_kind:kind,p_employment:field('employment')||null,p_period:field('period')||null,p_head:previous.head||null,p_expected:previous.revision,p_from:field('from'),p_until:field('until')||null,p_data:data,p_operation:operation};
 const signature=JSON.stringify(args),attempt=previous.signature===signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID();
 const state={...previous,attempt,signature,error:'',saved:false};
 const client=await createSupabaseServerClient(); if(!client)return {...state,error:inputError()};
 const {data:{user}}=await client.auth.getUser(); if(!user)return {...state,error:inputError('42501'),attempt:'',signature:''};
 const result=await client.rpc('payroll_save_input',{...args,p_attempt:attempt});
 if(result.error)return {...state,error:inputError(result.error.code,result.error.message)};
 revalidatePath(`/tenant/${tenant}/payroll/inputs`);
 return {error:'',saved:true,head:result.data.id,revision:result.data.revision,status:result.data.status,attempt:'',signature:''};
}
export async function correctionAction(previous:{error:string;saved:boolean;attempt:string;signature:string},form:FormData) {
 const field=(key:string)=>String(form.get(key)??'').trim();
 const args={p_tenant:field('tenant'),p_employer:field('employer'),p_period:field('period'),p_employment:field('employment'),p_reason:field('reason')};
 if(![args.p_tenant,args.p_employer,args.p_period,args.p_employment].every(uuid)||args.p_reason.length<3||args.p_reason.length>500)return {...previous,error:inputError('22023'),saved:false};
 const signature=JSON.stringify(args),attempt=previous.signature===signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID(),state={error:'',saved:false,attempt,signature};
 const client=await createSupabaseServerClient();if(!client)return {...state,error:inputError()};
 const {data:{user}}=await client.auth.getUser();if(!user)return {...state,error:inputError('42501')};
 const result=await client.rpc('payroll_request_correction',{...args,p_attempt:attempt});if(result.error)return {...state,error:inputError(result.error.code,result.error.message)};
 revalidatePath(`/tenant/${args.p_tenant}/payroll/inputs`);return {...state,saved:true};
}
