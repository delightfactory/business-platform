'use client';
import {useActionState,useRef,useState} from 'react';
import {issueRules} from './issuance-actions';

export type IssuanceState={saved:boolean;error:string;uncertain:boolean;stale:boolean};
export function IssuanceForm({head,revision,actor,stamp}:{head:string;revision:number;actor:string;stamp:string}){
 const [reason,setReason]=useState(''),[reviewed,setReviewed]=useState(false);
 const request=useRef<{signature:string;attempt:string}|null>(null);
 async function submit(previous:IssuanceState,form:FormData):Promise<IssuanceState>{
  const signature=JSON.stringify([head,revision,actor,stamp,reason,reviewed]);
  if(!request.current)request.current={signature,attempt:crypto.randomUUID()};
  if(request.current.signature!==signature)return {...previous,saved:false,error:'استعد نتيجة المحاولة السابقة قبل تغيير بيانات المراجعة.'};
  form.set('attempt',request.current.attempt);
  try{const result=await issueRules(previous,form);if(!result.uncertain)request.current=null;return result;}
  catch{return {...previous,saved:false,uncertain:true,error:'لم تصل نتيجة الإصدار. أعد المحاولة بنفس البيانات أو أعد فتح الصفحة للتحقق من الحالة.'};}
 }
 const [state,action,pending]=useActionState(submit,{saved:false,error:'',uncertain:false,stale:false});
 const frozen=pending||state.uncertain||state.stale||state.saved;
 return <form action={action} className="auth-form" aria-busy={pending}>
  <input type="hidden" name="head" value={head}/><input type="hidden" name="revision" value={revision}/><input type="hidden" name="actor" value={actor}/><input type="hidden" name="stamp" value={stamp}/>
  <input type="hidden" name="reason" value={reason}/><input type="hidden" name="reviewed" value={String(reviewed)}/>
  <fieldset disabled={frozen}><legend>مراجعة إصدار الضريبة والتأمين</legend>
   <label htmlFor="issuance-reason">مرجع المراجعة وسبب الاعتماد</label><textarea id="issuance-reason" required minLength={10} maxLength={1000} value={reason} onChange={event=>setReason(event.target.value)}/>
   <label htmlFor="issuance-reviewed"><input id="issuance-reviewed" type="checkbox" required checked={reviewed} onChange={event=>setReviewed(event.target.checked)}/>راجعت أصل النتائج الرسمية، وانطباقها على الفئة والفترة، وتغطية حالات الضريبة والتأمين. تصنيف الحالة وحده لا يثبت أنها رسمية أو ممثلة.</label>
  </fieldset>
  <p className="field-hint">الإصدار يثبت هذه النسخة وأدلتها للضريبة والتأمين فقط. لا يعتمد قواعد العمل الإضافي أو حدود الخصم، ولا يفتح تثبيت المسير المالي.</p>
  {state.error&&<p role="alert" className="form-message form-error">{state.error}</p>}
  {state.saved?<p role="status">صدر تعريف الضريبة والتأمين لهذه النسخة. تأهيل المسير المالي الكامل ما زال مطلوبًا.</p>:state.stale?<a href={'/operator/statutory/comparisons?head='+encodeURIComponent(head)} target="_blank" rel="noopener noreferrer">فتح حالة المراجعة الحالية في نافذة جديدة</a>:<button className="primary-button" disabled={pending}>{pending?'جارٍ إصدار القواعد…':state.uncertain?'استعادة نتيجة الإصدار':'إصدار قواعد الضريبة والتأمين'}</button>}
 </form>;
}
