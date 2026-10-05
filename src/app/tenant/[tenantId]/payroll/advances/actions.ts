'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '../rules';
import {advanceError,operations,type AdvanceJournal,type AdvanceResult} from './rules';
export async function advanceAction(journal:AdvanceJournal,resolve:boolean):Promise<AdvanceResult>{
 if(journal.version!==1||![journal.actor,journal.tenant,journal.employer,journal.attempt,journal.intent.advance,journal.intent.employment].every(uuid)||!operations.includes(journal.intent.operation)||!Number.isSafeInteger(journal.intent.expected)||journal.intent.expected<0||Object.keys(journal.intent.data).length>16||Object.values(journal.intent.data).some(v=>typeof v!=='string'||v.length>500))return {error:advanceError('22023')};
 try{
  const client=await createSupabaseServerClient();if(!client)return {error:advanceError()};
  const {data:{user}}=await client.auth.getUser();if(!user||user.id!==journal.actor)return {error:advanceError('42501')};
  const response=await client.rpc(resolve?'payroll_resolve_advance_attempt':'payroll_advance_command',{p_tenant:journal.tenant,p_employer:journal.employer,p_intent:journal.intent,p_attempt:journal.attempt});
  if(response.error)return {error:advanceError(response.error.code,response.error.message)};
  revalidatePath(`/tenant/${journal.tenant}/payroll/advances`);
  revalidatePath(`/tenant/${journal.tenant}/payroll/runs`);
  return resolve?response.data:{resolution:'committed',result:response.data};
 }catch{return {error:advanceError()};}
}
