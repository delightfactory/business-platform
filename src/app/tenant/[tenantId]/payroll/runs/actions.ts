'use server';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {revalidatePath} from 'next/cache';
import {uuid} from '../rules';
import {runError,type RunState} from './rules';
export async function runAction(previous:RunState,form:FormData):Promise<RunState>{
 const field=(key:string)=>String(form.get(key)??'').trim();const tenant=field('tenant'),employer=field('employer'),period=field('period'),operation=field('operation'),reason=field('reason');
 const fail=(code?:string)=>({...previous,error:runError(code),saved:false});
 if(![tenant,employer,period].every(uuid)||!['calculate','cancel','finalize'].includes(operation)||(operation==='cancel'&&(reason.length<3||reason.length>500))||operation==='finalize'&&(!uuid(previous.run)||!uuid(field('candidate'))||field('confirm')!=='on'))return fail('22023');
 const scope={p_tenant:tenant,p_employer:employer,p_period:period,p_run:previous.status==='cancelled'?null:previous.run||null,p_expected:previous.status==='cancelled'?0:previous.revision};
 const args=operation==='finalize'?{...scope,p_candidate:field('candidate')}:{...scope,p_operation:operation,p_reason:operation==='cancel'?reason:''};
 const submittedAttempt=field('__attempt');if(submittedAttempt&&!uuid(submittedAttempt))return fail('22023');
 const signature=JSON.stringify(args),attempt=submittedAttempt||(previous.signature===signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID()),state={...previous,error:'',saved:false,signature,attempt};
 const client=await createSupabaseServerClient();if(!client)return {...state,error:runError()};const {data:{user}}=await client.auth.getUser();if(!user||field('__actor')&&field('__actor')!==user.id)return {...state,error:runError('42501'),signature:'',attempt:''};
 const recovering=field('__reconcile')==='true';
 const rpc=operation==='finalize'?(recovering?'payroll_run_finalization_reconcile':'payroll_run_finalize'):(recovering?'payroll_run_reconcile':'payroll_run_command');
 const result=await client.rpc(rpc,{...args,p_attempt:attempt});if(result.error)return {...state,error:runError(result.error.code,result.error.message)};
 if(recovering&&result.data.outcome==='closed_uncommitted')return {...state,closedUncommitted:true,error:'',signature:'',attempt:''};
 if(recovering&&result.data.outcome!=='committed')return {...state,error:runError()};
 const receipt=recovering?result.data.result:result.data;
 revalidatePath(`/tenant/${tenant}/payroll/runs`);revalidatePath(`/tenant/${tenant}/payroll`);
 return {error:'',saved:true,recovered:recovering,run:receipt.id,revision:receipt.revision,status:receipt.status,output:receipt.output,signature:'',attempt:''};
}
