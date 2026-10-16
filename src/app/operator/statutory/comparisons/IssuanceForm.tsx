'use client';
import { Message } from '@/components/ui';
import { Button, Textarea } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import {startTransition,useActionState,useRef,useState} from 'react';
import {issueRules} from './issuance-actions';

export type IssuanceState={saved:boolean;error:string;uncertain:boolean;stale:boolean};
export function IssuanceForm({head,revision,actor,stamp}:{head:string;revision:number;actor:string;stamp:string}){
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHintId = useId();
 const [reason,setReason]=useState('');
 const [opened,setOpened]=useState(false);
 const request=useRef<{signature:string;attempt:string}|null>(null);
 const inFlight=useRef(false);
 async function submit(previous:IssuanceState,form:FormData):Promise<IssuanceState>{
  try{
  const signature=JSON.stringify([head,revision,actor,stamp,reason]);
  if(!request.current)request.current={signature,attempt:crypto.randomUUID()};
  if(request.current.signature!==signature)return {...previous,saved:false,error:'استعد نتيجة المحاولة السابقة قبل تغيير بيانات المراجعة.'};
  form.set('attempt',request.current.attempt);
  try{const result=await issueRules(previous,form);if(!result.uncertain)request.current=null;return result;}
  catch{return {...previous,saved:false,uncertain:true,error:'لم تصل نتيجة الإصدار. أعد المحاولة بنفس البيانات أو أعد فتح الصفحة للتحقق من الحالة.'};}
  }finally{inFlight.current=false;}
 }
 const [state,action,pending]=useActionState(submit,{saved:false,error:'',uncertain:false,stale:false});
 const frozen=pending||state.uncertain||state.stale||state.saved;
 const activeTask=Boolean(reason)||pending||state.uncertain||state.stale||state.saved||Boolean(state.error);
 const showOfflineNotice = offline && !pending && !state.stale && !state.saved;
 return <details open={opened||activeTask} onToggle={event=>{if(activeTask&&!event.currentTarget.open){event.currentTarget.open=true;return;}setOpened(event.currentTarget.open);}}><summary className="primary-button" onClick={event=>{if(activeTask)event.preventDefault();}}>تفعيل للحساب</summary><form action={action} onSubmit={event=>{if(blockOfflineSubmission(event))return;event.preventDefault();if(inFlight.current||pending||state.saved||state.stale)return;const form=new FormData(event.currentTarget);inFlight.current=true;startTransition(()=>action(form));}} className="auth-form" aria-busy={pending}>
  <input type="hidden" name="head" value={head}/><input type="hidden" name="revision" value={revision}/><input type="hidden" name="actor" value={actor}/><input type="hidden" name="stamp" value={stamp}/>
  <input type="hidden" name="reason" value={reason}/>
  <fieldset disabled={frozen}><legend>تفعيل إعدادات الحساب</legend>
   <label htmlFor="issuance-reason">ملاحظة التفعيل (اختيارية)</label><Textarea id="issuance-reason" maxLength={1000} value={reason} onChange={event=>setReason(event.target.value)} placeholder="مثال: إعدادات الرواتب المعتمدة داخل الشركة"/>
  </fieldset>
  <p className="field-hint">التفعيل يتيح استخدام الإعدادات في الحساب. المراجعة المحاسبية والمقارنات اختيارية، ومسؤوليتها لدى الشركة.</p>
  {state.error&&<Message tone="bad" role="alert" >{state.error}</Message>}
  {state.saved?<p role="status">تم تفعيل الإعدادات للحساب.</p>:state.stale?<a className="primary-button" href={'/operator/statutory/comparisons?head='+encodeURIComponent(head)} target="_blank" rel="noopener noreferrer">فتح حالة المراجعة الحالية في نافذة جديدة</a>:<Button variant="solid" type="submit"  disabled={offline || (pending)} aria-describedby={showOfflineNotice ? offlineHintId : undefined}>{pending?'جارٍ التفعيل…':state.uncertain?'استعادة نتيجة التفعيل':'تفعيل إعدادات الحساب'}</Button>}
 {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose={state.uncertain ? "recovery" : "continuation"} />}</form></details>;
}
