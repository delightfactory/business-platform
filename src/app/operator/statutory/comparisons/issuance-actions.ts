'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '@/app/tenant/[tenantId]/payroll/rules';
import type {IssuanceState} from './IssuanceForm';
import {issueReceipt} from '../dto';

export async function issueRules(previous:IssuanceState,form:FormData):Promise<IssuanceState>{
 const value=(key:string)=>String(form.get(key)??'');
 const fail=(error:string,uncertain=false,stale=false)=>({...previous,saved:false,error,uncertain,stale});
 const head=value('head'),actor=value('actor'),attempt=value('attempt'),stamp=value('stamp'),revision=Number(value('revision')),reason=value('reason').trim();
 if(!uuid(head)||!uuid(actor)||!uuid(attempt)||!Number.isInteger(revision)||revision<1||!/^[a-f0-9]{32}$/.test(stamp)||reason.length<10||reason.length>1000||value('reviewed')!=='true')return fail('أكمل مرجع المراجعة وتأكيد التحقق من النتائج الرسمية.');
 const client=await createSupabaseServerClient();if(!client)return fail('تعذر الاتصال. بيانات المراجعة محفوظة هنا؛ أعد المحاولة.');
 const {data:{user}}=await client.auth.getUser();if(!user||user.id!==actor)return fail('تغيرت الجلسة. سجّل الدخول بحساب المراجع المصرّح له.');
 const {data,error}=await client.rpc('statutory_draft_issue',{p_head:head,p_expected:revision,p_attempt:attempt,p_evidence_stamp:stamp,p_reviewed:true,p_reason:reason});
 if(error){
  if(error.code==='42501')return fail('لم تعد مهمة إدارة القواعد القانونية متاحة لحسابك.');
  if(error.code==='PT409')return fail('تغيرت القواعد أو أدلة المقارنة. افتح الحالة الحالية لمراجعتها؛ البيانات هنا محفوظة.',false,true);
  if(error.code==='23514')return fail('لم تكتمل شروط الإصدار. راجع النواقص والاختلافات في حالة التأهيل.',false,true);
  if(error.code?.startsWith('22'))return fail('راجع مرجع المراجعة وتأكيد التحقق قبل الإصدار.');
  return fail('لم تتأكد نتيجة الإصدار. استعدها بنفس البيانات أو أعد فتح الصفحة للتحقق.',true);
 }
 if(!issueReceipt(data,revision))return fail('لم تتأكد نتيجة الإصدار. استعدها بنفس البيانات.',true);
 revalidatePath('/operator/statutory');revalidatePath('/operator/statutory/comparisons');
 return {saved:true,error:'',uncertain:false,stale:false};
}
