'use client';
import { Checkbox, Message } from '@/components/ui';
import { Button, Textarea } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import {startTransition,useActionState,useRef,useState} from 'react';
import {issueRules} from './issuance-actions';

export type IssuanceState={saved:boolean;error:string;uncertain:boolean;stale:boolean};
export function IssuanceForm({head,revision,actor,stamp}:{head:string;revision:number;actor:string;stamp:string}){
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHintId = useId();
 const [reason,setReason]=useState(''),[reviewed,setReviewed]=useState(false);
 const [opened,setOpened]=useState(false);
 const request=useRef<{signature:string;attempt:string}|null>(null);
 const inFlight=useRef(false);
 async function submit(previous:IssuanceState,form:FormData):Promise<IssuanceState>{
  try{
  const signature=JSON.stringify([head,revision,actor,stamp,reason,reviewed]);
  if(!request.current)request.current={signature,attempt:crypto.randomUUID()};
  if(request.current.signature!==signature)return {...previous,saved:false,error:'استعد نتيجة المحاولة السابقة قبل تغيير بيانات المراجعة.'};
  form.set('attempt',request.current.attempt);
  try{const result=await issueRules(previous,form);if(!result.uncertain)request.current=null;return result;}
  catch{return {...previous,saved:false,uncertain:true,error:'لم تصل نتيجة الإصدار. أعد المحاولة بنفس البيانات أو أعد فتح الصفحة للتحقق من الحالة.'};}
  }finally{inFlight.current=false;}
 }
 const [state,action,pending]=useActionState(submit,{saved:false,error:'',uncertain:false,stale:false});
 const frozen=pending||state.uncertain||state.stale||state.saved;
 const activeTask=Boolean(reason)||reviewed||pending||state.uncertain||state.stale||state.saved||Boolean(state.error);
 const showOfflineNotice = offline && !pending && !state.stale && !state.saved;
 return <details open={opened||activeTask} onToggle={event=>{if(activeTask&&!event.currentTarget.open){event.currentTarget.open=true;return;}setOpened(event.currentTarget.open);}}><summary className="primary-button" onClick={event=>{if(activeTask)event.preventDefault();}}>مراجعة الإصدار</summary><form action={action} onSubmit={event=>{if(blockOfflineSubmission(event))return;event.preventDefault();if(inFlight.current||pending||state.saved||state.stale)return;const form=new FormData(event.currentTarget);inFlight.current=true;startTransition(()=>action(form));}} className="auth-form" aria-busy={pending}>
  <input type="hidden" name="head" value={head}/><input type="hidden" name="revision" value={revision}/><input type="hidden" name="actor" value={actor}/><input type="hidden" name="stamp" value={stamp}/>
  <input type="hidden" name="reason" value={reason}/><input type="hidden" name="reviewed" value={String(reviewed)}/>
  <fieldset disabled={frozen}><legend>مراجعة إصدار الضريبة والتأمين</legend>
   <label htmlFor="issuance-reason">مرجع المراجعة وسبب الاعتماد</label><Textarea id="issuance-reason" required minLength={10} maxLength={1000} value={reason} onChange={event=>setReason(event.target.value)}/>
   <label htmlFor="issuance-reviewed"><Checkbox id="issuance-reviewed"  required checked={reviewed} onChange={event=>setReviewed(event.target.checked)}/>راجعت أصل النتائج الرسمية، وانطباقها على الفئة والفترة، وتغطية حالات الضريبة والتأمين. تصنيف الحالة وحده لا يثبت أنها رسمية أو ممثلة.</label>
  </fieldset>
  <p className="field-hint">الإصدار يثبت هذه النسخة وأدلتها للضريبة والتأمين فقط. لا يعتمد قواعد العمل الإضافي أو حدود الخصم، ولا يسمح بحفظ المسير المالي نهائيًا.</p>
  {state.error&&<Message tone="bad" role="alert" >{state.error}</Message>}
  {state.saved?<p role="status">صدر تعريف الضريبة والتأمين لهذه النسخة. استكمال شروط حساب المسير المالي ما زال مطلوبًا.</p>:state.stale?<a className="primary-button" href={'/operator/statutory/comparisons?head='+encodeURIComponent(head)} target="_blank" rel="noopener noreferrer">فتح حالة المراجعة الحالية في نافذة جديدة</a>:<Button variant="solid" type="submit"  disabled={offline || (pending)} aria-describedby={showOfflineNotice ? offlineHintId : undefined}>{pending?'جارٍ إصدار القواعد…':state.uncertain?'استعادة نتيجة الإصدار':'إصدار قواعد الضريبة والتأمين'}</Button>}
 {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose={state.uncertain ? "recovery" : "continuation"} />}</form></details>;
}
