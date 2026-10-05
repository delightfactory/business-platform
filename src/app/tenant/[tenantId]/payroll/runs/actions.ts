'use server';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {revalidatePath} from 'next/cache';
import {uuid} from '../rules';
import {runError,type RunState} from './rules';
export async function runAction(previous:RunState,form:FormData):Promise<RunState>{
 const field=(key:string)=>String(form.get(key)??'').trim();const tenant=field('tenant'),employer=field('employer'),period=field('period'),operation=field('operation'),reason=field('reason');
 const fail=(code?:string)=>({...previous,error:runError(code),saved:false});
 if(![tenant,employer,period].every(uuid)||!['calculate','cancel'].includes(operation)||(operation==='cancel'&&(reason.length<3||reason.length>500)))return fail('22023');
 const args={p_tenant:tenant,p_employer:employer,p_period:period,p_run:previous.status==='cancelled'?null:previous.run||null,p_expected:previous.status==='cancelled'?0:previous.revision,p_operation:operation,p_reason:operation==='cancel'?reason:''};
 const signature=JSON.stringify(args),attempt=previous.signature===signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID(),state={...previous,error:'',saved:false,signature,attempt};
 const client=await createSupabaseServerClient();if(!client)return {...state,error:runError()};const {data:{user}}=await client.auth.getUser();if(!user)return {...state,error:runError('42501'),signature:'',attempt:''};
 const result=await client.rpc('payroll_run_command',{...args,p_attempt:attempt});if(result.error)return {...state,error:runError(result.error.code,result.error.message)};
 revalidatePath(`/tenant/${tenant}/payroll/runs`);revalidatePath(`/tenant/${tenant}/payroll`);
 return {error:'',saved:true,run:result.data.id,revision:result.data.revision,status:result.data.status,signature:'',attempt:''};
}
