'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../rules';
import {runError} from './rules';
type State={error:string;saved:boolean;run:string;candidate:string;revision:number;status:string;attempt:string;signature:string};
export async function approvalAction(previous:State,form:FormData):Promise<State>{
 const field=(key:string)=>String(form.get(key)??'').trim();
 const tenant=field('tenant'),employer=field('employer'),period=field('period'),operation=field('operation'),reason=field('reason');
 if(![tenant,employer,period,previous.run,previous.candidate].every(uuid)||!['approve','release'].includes(operation)||reason.length<3||reason.length>500)return {...previous,error:runError('22023'),saved:false};
 const args={p_tenant:tenant,p_employer:employer,p_period:period,p_run:previous.run,p_candidate:previous.candidate,p_expected:previous.revision,p_operation:operation,p_reason:reason};
 const signature=JSON.stringify(args),attempt=previous.signature===signature&&uuid(previous.attempt)?previous.attempt:crypto.randomUUID(),state={...previous,error:'',saved:false,signature,attempt};
 const client=await createSupabaseServerClient();if(!client)return {...state,error:runError()};
 const {data:{user}}=await client.auth.getUser();if(!user)return {...state,error:runError('42501'),signature:'',attempt:''};
 const result=await client.rpc('payroll_candidate_approval',{...args,p_attempt:attempt});
 if(result.error)return {...state,error:runError(result.error.code,result.error.message)};
 revalidatePath(`/tenant/${tenant}/payroll/runs`);
 return {...state,saved:true,run:result.data.id,candidate:result.data.candidate_id,revision:result.data.revision,status:result.data.status,attempt:'',signature:''};
}
