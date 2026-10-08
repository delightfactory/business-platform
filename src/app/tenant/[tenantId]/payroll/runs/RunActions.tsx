'use client';
import {useActionState,useState,useSyncExternalStore} from 'react';
import {runAction} from './actions';
import Link from 'next/link';
import {money,type RunState} from './rules';
import styles from '../payroll.module.css';
type FinalScope={employer:string;starts:string;ends:string;employees:number;gross:string|null;net:string|null};
type Props={candidate:string;finalScope?:FinalScope;actor:string;tenant:string;employer:string;period:string;run:string;revision:number;status:string;stale:boolean;canExecute:boolean;anchorId?:string};
type PendingRun={version:1;attempt:string;entries:[string,string][];previous:RunState};
const recoveryEvent='payroll-run-recovery';
function readPending(key:string){try{return localStorage.getItem(key)??'';}catch{return '';}}
function decodePending(value:string):PendingRun|null{try{const p=JSON.parse(value);return p.version===1&&typeof p.attempt==='string'&&p.previous&&Array.isArray(p.entries)&&p.entries.every((e:unknown)=>Array.isArray(e)&&e.length===2&&e.every(v=>typeof v==='string'))?p:null;}catch{return null;}}
export function RunActions(props:Props){
 const storageKey='payroll-run:v1:'+JSON.stringify([props.actor,props.tenant,props.employer,props.period]);
 const serialized=useSyncExternalStore(notify=>{window.addEventListener(recoveryEvent,notify);window.addEventListener('storage',notify);return()=>{window.removeEventListener(recoveryEvent,notify);window.removeEventListener('storage',notify);};},()=>readPending(storageKey),()=> '');
 const unresolved=Boolean(serialized);
 const [recoveryError,setRecoveryError]=useState('');
 const [closed,setClosed]=useState(false);
 function writePending(record:PendingRun|null){if(record)localStorage.setItem(storageKey,JSON.stringify(record));else localStorage.removeItem(storageKey);window.dispatchEvent(new Event(recoveryEvent));}
 function clearPending(attempt:string){if(decodePending(readPending(storageKey))?.attempt!==attempt)throw new Error('pending_run_identity_changed');writePending(null);}
 async function recover(){
  if(!navigator.locks){setRecoveryError('تعذر حماية الطلب بين نوافذ المتصفح. استخدم متصفحًا يدعم حماية الطلبات قبل المتابعة.');return;}
  await navigator.locks.request(storageKey,{ifAvailable:true},async lock=>{if(!lock){setRecoveryError('طلب جارٍ في نافذة أخرى. انتظر نتيجته ثم تحقّق هنا.');return;}await recoverLocked();});
 }
 async function recoverLocked(){
  const original=decodePending(readPending(storageKey));if(!original){setRecoveryError('تعذر قراءة الطلب المحفوظ. راجع مسؤول النظام قبل إجراء جديد.');return;}
  setSaving(true);setRecoveryError('');
  try{const request=new FormData();original.entries.forEach(([k,v])=>request.append(k,v));request.set('__attempt',original.attempt);request.set('__actor',props.actor);request.set('__reconcile','true');
   const result=await runAction(original.previous,request);
   if(result.saved||result.closedUncommitted){clearPending(original.attempt);setClosed(Boolean(result.closedUncommitted));if(result.saved)setFeedback(result);}else setRecoveryError(result.error);
  }catch{setRecoveryError('لم تصل نتيجة التحقق. الطلب محفوظ على هذا الجهاز؛ أعد استعادة النتيجة.');}finally{setSaving(false);}
 }
 const [feedback,setFeedback]=useState<RunState|null>(null);
 const [saving,setSaving]=useState(false);
 const primary=props.status==='approved'?!props.stale:props.status==='draft'||!props.run||props.status==='cancelled'||props.stale;
 async function submit(previous:RunState,form:FormData){
  if(!navigator.locks)return {...previous,saved:false,error:'تعذر حماية الطلب بين نوافذ المتصفح. استخدم متصفحًا يدعم حماية الطلبات قبل المتابعة.'};
  return navigator.locks.request(storageKey,{ifAvailable:true},async lock=>lock?submitLocked(previous,form):{...previous,saved:false,error:'طلب جارٍ في نافذة أخرى. انتظر نتيجته ثم تحقّق هنا.'});
 }
 async function submitLocked(previous:RunState,form:FormData){
  if(readPending(storageKey))return {...previous,saved:false,error:'استعد نتيجة الطلب السابق أولًا.'};
  setSaving(true);setFeedback(null);setClosed(false);
  const original:PendingRun={version:1,attempt:crypto.randomUUID(),entries:Array.from(form.entries()).map(([k,v])=>[k,String(v)]),previous};
  try{writePending(original);}catch{setSaving(false);return {...previous,saved:false,error:'تعذر حفظ الطلب على هذا الجهاز. لم يُرسل؛ فعّل تخزين الموقع ثم أعد المحاولة.'};}
  form.set('__attempt',original.attempt);form.set('__actor',props.actor);
  try{
   const result=await runAction(previous,form);
   if(result.saved){clearPending(original.attempt);setFeedback(result);}
   return result;
  }catch{return {...previous,saved:false,error:'لم تصل نتيجة الطلب. استعد النتيجة الأصلية قبل إجراء جديد.'};}
  finally{setSaving(false);}
 }
 const currentFeedback=feedback?.run===props.run&&feedback.revision===props.revision&&feedback.status===props.status;
 if(!props.canExecute&&!unresolved&&!feedback&&!closed)return null;
 return <section id={props.anchorId} className={styles.card}>
  {unresolved&&<div><h2>استعادة نتيجة الطلب السابق</h2><p>لم تتأكد نتيجة الطلب. تحقّق منه أولًا قبل متابعة العمل.</p><button type="button" onClick={recover} disabled={saving}>{saving?'جارٍ التحقق…':'استعادة نتيجة الطلب الأصلي'}</button>{recoveryError&&<p role="alert">{recoveryError}</p>}</div>}
  {closed&&<p role="status">تأكدنا أن الطلب السابق لم يُحفظ. يمكنك متابعة العمل بأمان.</p>}
  {feedback?.recovered&&!currentFeedback&&<p role="status">عُثر على نتيجة الطلب السابق. راجع حالة المسير الحالية الظاهرة.</p>}
  {currentFeedback&&<p role="status">{feedback.status==='locked'?'تم تثبيت النتيجة وحفظ استهلاك مدخلاتها.':feedback.status==='cancelled'?'أُلغيت النسخة مع الاحتفاظ بتاريخها.':'جهزنا نسخة للمراجعة. راجع النتائج قبل الاعتماد.'}</p>}
  {feedback?.output&&<Link href={`/tenant/${props.tenant}/payroll/output?${new URLSearchParams({employer:props.employer,output:feedback.output})}`}>عرض النتيجة المثبتة</Link>}
  {props.canExecute&&<details open={primary}><summary>{primary?'الخطوة التالية':'إجراءات اختيارية للمسير بعد مراجعة العوائق'}</summary>
   <RunActionForm key={`${props.run}:${props.revision}:${props.status}`} {...props} saving={saving||unresolved} submit={submit}/>
  </details>}
 </section>;
}
function RunActionForm({tenant,employer,period,run,candidate,revision,status,stale,saving,submit,finalScope}:Props&{saving:boolean;submit:(previous:RunState,form:FormData)=>Promise<RunState>}){
 const [reason,setReason]=useState('');const [state,action,pending]=useActionState(submit,{error:'',saved:false,run,revision,status,signature:'',attempt:''});
 const finalizing=state.status==='approved';
 return <form action={action} onReset={e=>e.preventDefault()} className={styles.form}><h2>{finalizing?'تثبيت النتيجة المعتمدة':'تجهيز الرواتب'}</h2><input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employer" value={employer}/><input type="hidden" name="period" value={period}/><input type="hidden" name="candidate" value={candidate}/><fieldset disabled={pending||saving} className={styles.fields}>
 {finalizing?<><p>{finalScope?.employer} · {finalScope?.starts} — {finalScope?.ends}</p><p>عدد الموظفين: {finalScope?.employees} · الاستحقاقات: {money(finalScope?.gross)} · الصافي: {money(finalScope?.net)}</p><label><input type="checkbox" name="confirm" required/>راجعت هذه النتيجة وأريد تثبيتها واستهلاك مدخلاتها مرة واحدة. بعد التثبيت، يتم التعديل بمسار تصحيح يحفظ الأصل.</label><button className={stale?'secondary-button':'primary-button'} name="operation" value="finalize">تثبيت النتيجة واستهلاك المدخلات</button></>:<><button className={!state.run||state.status==='draft'||state.status==='cancelled'||stale?'primary-button':'secondary-button'} name="operation" value="calculate">{state.run&&state.status!=='cancelled'?stale?'إعادة الحساب بعد التغييرات':'تجهيز نسخة جديدة للمراجعة':'تجهيز نسخة للمراجعة'}</button>{state.run&&state.status!=='cancelled'&&<details><summary>إلغاء النسخة مع حفظ تاريخ المراجعة</summary><label htmlFor="run-cancel-reason">سبب الإلغاء<input id="run-cancel-reason" name="reason" value={reason} onChange={e=>setReason(e.target.value)} maxLength={500}/></label><button className="secondary-button" name="operation" value="cancel">إلغاء النسخة</button></details>}</>}
 </fieldset>{pending&&<p role="status">جارٍ التنفيذ وحفظ النتيجة.</p>}{state.error&&<p role="alert">{state.error}</p>}</form>;
}
