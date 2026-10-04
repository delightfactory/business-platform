'use client';
import {useState,useSyncExternalStore} from 'react';
import {useRouter} from 'next/navigation';
import {uuid} from '../rules';
import {deductionDispositionAction} from './deduction-disposition-actions';
import styles from '../payroll.module.css';
export const deductionRecoveryEvent='cube4-deduction-recovery';
type Scope={actor:string;tenant:string;employer:string;period:string};
type Request={key:string;attempt:string;employment:string;claim:string;retraction:boolean};
function readRequests(prefix:string){
 try{return JSON.stringify(Object.keys(localStorage).sort().filter(key=>key.startsWith(prefix)).flatMap(key=>{
  const suffix=key.slice(prefix.length),employment=suffix.slice(0,36),parts=suffix.slice(37).split(':retract:'),claim=parts[0],attempt=localStorage.getItem(key)??'';
  if(suffix[36]!==':'||!uuid(employment)||!uuid(attempt)||!uuid(claim.replace(/^recurring:/,''))||parts.length>2||(parts.length===2&&!uuid(parts[1])))return [];
  return [{key,attempt,employment,claim,retraction:parts.length===2}];
 }));}catch{return '[]';}
}
export function DeductionRecovery(p:Scope){
 const router=useRouter(),prefix=`cube4:deduction:${p.actor}:${p.tenant}:${p.employer}:${p.period}:`;
 const serialized=useSyncExternalStore(notify=>{window.addEventListener('storage',notify);window.addEventListener(deductionRecoveryEvent,notify);return()=>{window.removeEventListener('storage',notify);window.removeEventListener(deductionRecoveryEvent,notify);};},()=>readRequests(prefix),()=> '[]');
 const requests=JSON.parse(serialized) as Request[];
 const [pending,setPending]=useState(''),[message,setMessage]=useState('');
 async function recover(request:Request){
  setPending(request.key);setMessage('');
  try{const form=new FormData();Object.entries({tenant:p.tenant,employer:p.employer,period:p.period,employment:request.employment,claim:request.claim,attempt:request.attempt,operation:'recover'}).forEach(([key,value])=>form.set(key,value));
   const result=await deductionDispositionAction({error:'',status:'idle'},form);
   if(result.status==='committed'||result.status==='not_committed'){
    if(localStorage.getItem(request.key)===request.attempt)localStorage.removeItem(request.key);
    window.dispatchEvent(new CustomEvent(deductionRecoveryEvent,{detail:request.key}));
    setMessage(result.status==='committed'?'تم التحقق من نتيجة الطلب المحفوظ. راجع الحالة الحالية في سجل المعالجات.':'تأكدنا أن الطلب لم يُنفّذ. يمكنك إرسال المعالجة بعد مراجعتها.');router.refresh();
   }else setMessage(result.error||'تعذر التحقق الآن. احتفظنا بمعرّف الطلب لاستعادته.');
  }catch{setMessage('تعذر التحقق الآن. احتفظنا بمعرّف الطلب؛ استعد نتيجته قبل إرسال معالجة أخرى.');}finally{setPending('');}
 }
 if(!requests.length&&!message)return null;
 return <section className={styles.card}><h2>طلبات معالجة تحتاج استعادة النتيجة</h2><p>لا تُرسل معالجة جديدة قبل التحقق من الطلب المحفوظ. تبقى الاستعادة متاحة حتى لو تغيرت حالة المصدر أو سُحب اعتماد المعالجة.</p>{requests.map(request=><button key={request.key} type="button" disabled={Boolean(pending)} onClick={()=>recover(request)}>{request.retraction?'استعادة نتيجة سحب الاعتماد':'استعادة نتيجة معالجة الالتزام'}</button>)}{message&&<p role="status">{message}</p>}</section>;
}
