'use client';
import { Button, Input, Message, Select, Textarea, Checkbox } from '@/components/ui';
import {useActionState,useEffect,useId,useState} from 'react';
import {OfflineSubmissionNotice,useOfflineSubmission} from '@/components/offline-submission';
import {useRouter} from 'next/navigation';
import {deductionRecoveryEvent} from './DeductionRecovery';
import {deductionDispositionAction,type DispositionState} from './deduction-disposition-actions';
import {money} from './rules';
import styles from '../payroll.module.css';
type Props={actor:string;tenant:string;employer:string;period:string;run:string;candidate:string;revision:number;employment:string;claim:string;original:number;capacity:number;today:string;periods:{id:string;starts_on:string;ends_on:string}[];canExternal:boolean;retraction?:string};
export function DeductionDisposition(p:Props){
 const {offline,blockOfflineSubmission}=useOfflineSubmission(),offlineHintId=useId();
 const router=useRouter();
 const storageKey=`cube4:deduction:${p.actor}:${p.tenant}:${p.employer}:${p.period}:${p.employment}:${p.claim}${p.retraction?':retract:'+p.retraction:''}`;
 const [attempt,setAttempt]=useState(''),[unresolved,setUnresolved]=useState(false),[mode,setMode]=useState('carry'),[amount,setAmount]=useState(String(p.capacity)),[target,setTarget]=useState(p.periods[0]?.id??''),[date,setDate]=useState(p.today),[reference,setReference]=useState(''),[reason,setReason]=useState(''),[confirmed,setConfirmed]=useState(false);
 const [state,action,pending]=useActionState<DispositionState,FormData>(async(previous,form)=>{
  try{if(localStorage.getItem(storageKey)!==String(form.get('attempt')))return {status:'not_committed',error:'تعذر حفظ معرّف الطلب. لم تُرسل المعالجة؛ تحقق من إتاحة التخزين في المتصفح.'};}catch{return {status:'not_committed',error:'تعذر حفظ معرّف الطلب. لم تُرسل المعالجة.'};}
  const result=await deductionDispositionAction(previous,form);
  if(['committed','not_committed'].includes(result.status)){try{localStorage.removeItem(storageKey);}catch{}window.dispatchEvent(new CustomEvent(deductionRecoveryEvent,{detail:storageKey}));}
  return result;
 },{error:'',status:'idle'});
 useEffect(()=>{
  let active=true;
  queueMicrotask(()=>{if(!active)return;let saved='';try{saved=localStorage.getItem(storageKey)??'';}catch{}
   setAttempt(saved||crypto.randomUUID());setUnresolved(Boolean(saved));});
  return ()=>{active=false;};
 },[storageKey]);
 useEffect(()=>{
  if(!['committed','not_committed'].includes(state.status))return;
  let active=true;queueMicrotask(()=>{if(!active)return;try{localStorage.removeItem(storageKey);}catch{}
   setUnresolved(false);if(state.status==='committed')router.refresh();else setAttempt(crypto.randomUUID());});
  return ()=>{active=false;};
 },[state,storageKey,router]);
 useEffect(()=>{const clear=(event:Event)=>{if((event as CustomEvent).detail===storageKey){setUnresolved(false);setAttempt(crypto.randomUUID());}};window.addEventListener(deductionRecoveryEvent,clear);return()=>window.removeEventListener(deductionRecoveryEvent,clear);},[storageKey]);
 const showOfflineNotice=offline&&!pending;
 const scope=<>{Object.entries({tenant:p.tenant,employer:p.employer,period:p.period,employment:p.employment,claim:p.claim,attempt}).map(([key,value])=><input key={key} type="hidden" name={key} value={value}/>)}</>;
 if(state.status==='committed'&&p.retraction)return <Message tone="info" role="status">سُحب اعتماد المعالجة مع حفظ سجلها وأصل الالتزام. أعد الحساب قبل الاعتماد.</Message>;
 if(state.status==='committed')return <Message tone="info" role="status">اعتمدت المعالجة: خصم {money(state.result?.payroll_amount)}، ومتبقي {money(state.result?.residual_amount)}. أعد حساب المسير ثم راجع النتيجة واعتمدها.</Message>;
 if(unresolved)return <section><p>يوجد طلب معالجة لم تُحسم نتيجته. استعد نتيجته من قسم الطلبات المحفوظة قبل إرسال معالجة أخرى.</p>{state.error&&<Message tone="bad" role="alert">{state.error}</Message>}</section>;
 if(p.retraction)return <form action={action} onReset={e=>e.preventDefault()} onSubmit={event=>{if(blockOfflineSubmission(event))return;try{localStorage.setItem(storageKey,attempt);window.dispatchEvent(new Event(deductionRecoveryEvent));}catch{}setUnresolved(true);}} className={styles.form}>{scope}<input type="hidden" name="disposition" value={p.retraction}/><fieldset disabled={pending} className={styles.fields}><legend>سحب اعتماد معالجة لم تُستهلك بعد</legend><p>يبقى أصل الالتزام محفوظًا. يُلغى مدخل المتبقي المرتبط بهذه المعالجة فقط. بعد الحفظ النهائي استخدم مسار تصحيح الرواتب المعتمد.</p><label>مرجع التصحيح<Input name="reference" required minLength={3} maxLength={160} value={reference} onChange={e=>setReference(e.target.value)}/></label><label>سبب سحب الاعتماد<Textarea name="reason" required minLength={3} maxLength={500} value={reason} onChange={e=>setReason(e.target.value)}/></label><label><Checkbox  name="confirmed" value="yes" required checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>أؤكد تصحيح اعتماد هذه المعالجة. لا يسجل ذلك ردًا لأي مبلغ تمت تسويته خارجيًا.</label><Button variant="solid" type="submit" name="operation" value="retract" disabled={pending||!attempt||offline} aria-describedby={showOfflineNotice?offlineHintId:undefined}>سحب اعتماد المعالجة</Button></fieldset>{showOfflineNotice&&<OfflineSubmissionNotice id={offlineHintId}/>} {state.error&&<Message tone="bad" role="alert">{state.error}</Message>}</form>;
 return <form action={action} onReset={e=>e.preventDefault()} onSubmit={event=>{if(blockOfflineSubmission(event))return;try{localStorage.setItem(storageKey,attempt);window.dispatchEvent(new Event(deductionRecoveryEvent));}catch{}setUnresolved(true);}} className={styles.form}><h5>معالجة متبقي الالتزام</h5>{scope}{Object.entries({run:p.run,candidate:p.candidate,revision:p.revision}).map(([key,value])=><input key={key} type="hidden" name={key} value={value}/>)}
 <p>أصل الالتزام: {money(p.original)}. أقصى خصم متاح لهذا المصدر: {money(p.capacity)}. لا يؤدي الاعتماد إلى تخفيض أصل الالتزام.</p>
 <fieldset disabled={pending} className={styles.fields}>
 <label>الجزء الذي سيخصم في هذه الفترة<Input name="amount" inputMode="decimal" pattern="[0-9]{1,12}(\.[0-9]{1,2})?" required value={amount} onChange={e=>setAmount(e.target.value)}/></label>
 <p>المتبقي: {money(/^[0-9]{1,12}(\.[0-9]{1,2})?$/.test(amount)?(Math.round(p.original*100)-Math.round(Number(amount)*100))/100:null)}</p>
 <label>معالجة المتبقي<Select name="mode" value={mode} onChange={e=>setMode(e.target.value)}><option value="carry">ترحيل إلى فترة لاحقة</option>{p.canExternal&&<option value="external_settlement">تسوية تمت خارج الرواتب</option>}</Select></label>
 {mode==='carry'?<label>فترة استقطاع المتبقي<Select name="target" required value={target} onChange={e=>setTarget(e.target.value)}><option value="">اختر فترة لاحقة مفتوحة</option>{p.periods.map(period=><option key={period.id} value={period.id}>{period.starts_on} — {period.ends_on}</option>)}</Select></label>:<label>تاريخ التسوية الفعلية<Input type="date" name="date" required max={p.today} value={date} onChange={e=>setDate(e.target.value)}/></label>}
 <label>مرجع المستند<Input name="reference" required minLength={3} maxLength={160} value={reference} onChange={e=>setReference(e.target.value)}/></label>
 <label>سبب المعالجة<Textarea name="reason" required minLength={3} maxLength={500} value={reason} onChange={e=>setReason(e.target.value)}/></label>
 <label><Checkbox  name="confirmed" value="yes" required checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>{mode==='carry'?'أعتمد الجزء المستقطع وترحيل المتبقي. سيعاد فحص الحد القانوني في الفترة التالية.':'أؤكد أن المتبقي تمت تسويته فعليًا خارج الرواتب وفق المستند؛ لا يسجل هذا الطلب دفعًا للراتب.'}</label>
 <Button variant="solid" type="submit" name="operation" value="approve" disabled={pending||!attempt||offline||(mode==='carry'&&!target)} aria-describedby={showOfflineNotice?offlineHintId:undefined}>اعتماد معالجة المتبقي</Button></fieldset>{showOfflineNotice&&<OfflineSubmissionNotice id={offlineHintId}/>} {state.error&&<Message tone="bad" role="alert">{state.error}</Message>}</form>;
}
