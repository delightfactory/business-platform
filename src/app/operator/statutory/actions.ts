'use server';
import {revalidatePath} from 'next/cache';
import {createSupabaseServerClient} from '@/lib/supabase/server';
import type {DraftState} from './DraftForm';
import {draftReceipt} from './dto';
const uuid=(s:string)=>/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(s);
export async function saveDraftAction(previous:DraftState,form:FormData):Promise<DraftState>{
 const value=(key:string)=>String(form.get(key)??'').trim();
 const fail=(error:string,uncertain=false,stale=false)=>({...previous,saved:false,error,uncertain,stale});
 const attempt=value('__attempt'),actor=value('__actor'),version=value('version'),from=value('from'),until=value('until'),reason=value('reason');
 if(!uuid(attempt)||!uuid(actor)||(previous.head&&!uuid(previous.head))||!Number.isInteger(previous.revision)||previous.revision<0||version.length<3||version.length>100||!/^\d{4}-\d{2}-\d{2}$/.test(from)||(until&&!/^\d{4}-\d{2}-\d{2}$/.test(until))||reason.length<3||reason.length>500)return fail('راجع اسم النسخة والتواريخ وسبب الحفظ.');
 const titles=form.getAll('sourceTitle').map(String),urls=form.getAll('sourceUrl').map(String);if(titles.length!==urls.length||titles.length>6)return fail('راجع أسماء المراجع وروابطها.');
 const sources=titles.map((title,i)=>({title:title.trim(),url:urls[i].trim()})).filter(s=>s.title||s.url);
 if(sources.length<1||sources.some(s=>s.title.length<3||s.title.length>160||s.url.length>2048||!/^https:\/\//.test(s.url)))return fail('أدخل اسم المرجع ورابطه الذي يبدأ بـ https لكل مرجع مستخدم.');
 const rulesText=value('numericRules');let numericRules:unknown;
 try{if(!rulesText||rulesText.length>65536)return fail('راجع القواعد الرقمية وحدود عدد الشرائح.');numericRules=JSON.parse(rulesText);}catch{return fail('تعذر قراءة القواعد الرقمية. الحقول كما هي؛ راجعها قبل الحفظ.');}
 const client=await createSupabaseServerClient();if(!client)return fail('تعذر الاتصال. الحقول كما هي؛ أعد المحاولة.');
 const {data:{user}}=await client.auth.getUser();if(!user||user.id!==actor)return fail('تغيرت الجلسة أو لم تعد متاحة. سجّل الدخول بالحساب المصرّح له ثم راجع المسودة.');
 const {data,error}=await client.rpc('statutory_draft_save',{p_head:previous.head||null,p_expected:previous.revision,p_attempt:attempt,p_version:version,p_from:from,p_until:until||null,p_sources:sources,p_reason:reason,p_rules:numericRules});
 if(error){
  if(error.code==='42501')return fail('لم تعد مهمة إدارة القواعد القانونية متاحة لحسابك. راجع مسؤول تشغيل المنصة.');
  if(error.message.includes('statutory_draft_exists'))return fail('توجد مسودة باسم النسخة نفسه. راجع المسودات المحفوظة قبل إعادة الحفظ.');
  if(error.code==='PT409')return fail('تغيرت المسودة منذ فتحها. الحقول كما هي هنا؛ افتح النسخة الحالية في نافذة جديدة للمقارنة وإجراء تعديل عليها.',false,true);
  if(error.message.includes('statutory_numeric')||error.message.includes('payroll_arithmetic_input_invalid'))return fail('راجع القواعد الرقمية: الحدود متزايدة، والشريحة والجدول الأخيران بلا حد نهائي، والنسب بين صفر و100، وفروع التأمين بلا تكرار. الحقول كما هي؛ لم تُحفظ هذه البيانات.');
  if(error.code==='22023'||error.code?.startsWith('22'))return fail('راجع التواريخ والمراجع؛ لم تُحفظ هذه البيانات.');
  return fail('تعذر تأكيد الحفظ. أعد المحاولة بنفس البيانات لاستعادة النتيجة.',true);
 }
 if(!draftReceipt(data,previous.head,previous.revision))return fail('تعذر تأكيد الحفظ. أعد المحاولة بنفس البيانات لاستعادة النتيجة.',true);
 revalidatePath('/operator/statutory');return {head:data.head,revision:data.revision,saved:true,error:'',uncertain:false,stale:false};
}
