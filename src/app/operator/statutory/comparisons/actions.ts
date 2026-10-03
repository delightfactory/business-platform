'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import {uuid} from '@/app/tenant/[tenantId]/payroll/rules';
import type {ComparisonState} from './ComparisonForm';
export async function saveComparison(previous:ComparisonState,form:FormData):Promise<ComparisonState>{
 const value=(name:string)=>String(form.get(name)??'');const fail=(error:string,uncertain=false,stale=false)=>({...previous,saved:false,error,uncertain,stale});
 const head=value('head'),actor=value('actor'),attempt=value('attempt'),revision=Number(value('revision')),raw=value('case');
 if(!uuid(head)||!uuid(actor)||!uuid(attempt)||!Number.isInteger(revision)||revision<1||raw.length>16384)return fail('راجع الحالة ونسخة القواعد المختارة.');let caseData:unknown;try{caseData=JSON.parse(raw);}catch{return fail('تعذر قراءة بيانات المقارنة. الحقول كما هي؛ راجعها قبل الحفظ.');}
 const client=await createSupabaseServerClient();if(!client)return fail('تعذر الاتصال. أعد المحاولة بنفس الحقول.');const {data:{user}}=await client.auth.getUser();if(!user||user.id!==actor)return fail('تغيرت الجلسة. سجّل الدخول بالحساب المصرّح له قبل متابعة المراجعة.');
 const {data,error}=await client.rpc('statutory_draft_compare',{p_head:head,p_expected:revision,p_attempt:attempt,p_case:caseData});
 if(error){if(error.code==='42501')return fail('لم تعد مهمة مراجعة القواعد القانونية متاحة لحسابك.');if(error.code==='PT409')return fail('تغيرت نسخة القواعد أو سبق استخدام محاولة الحفظ لبيانات أخرى. افتح النسخة الحالية للمقارنة، مع الاحتفاظ بالحقول هنا.',false,true);if(error.code?.startsWith('22'))return fail('راجع المبالغ والتواريخ وأيام المدة وأجر الاشتراك ومصدر النتيجة. لم تُحفظ المقارنة؛ الحقول كما هي.');return fail('لم تتأكد نتيجة الحفظ. أعد المحاولة بنفس البيانات لاستعادة النتيجة.',true);}
 if(!data||typeof data.matched!=='boolean'||data.qualified!==false)return fail('لم تتأكد نتيجة الحفظ. أعد المحاولة بنفس البيانات لاستعادة النتيجة.',true);
 revalidatePath('/operator/statutory/comparisons');return {saved:true,error:'',uncertain:false,stale:false,matched:data.matched};
}
