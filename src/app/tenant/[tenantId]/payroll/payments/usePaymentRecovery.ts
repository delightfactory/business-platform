'use client';
import {useActionState,useSyncExternalStore} from 'react';
import {paymentAction} from './actions';
import type {PaymentState} from './rules';
import {uuid} from '../rules';
type Scope={actor:string;tenant:string;employer:string;output:string;revision:number;recoveryAttempt?:string};
type Pending={version:2;attempt:string;actor:string;tenant:string;employer:string;output:string};
type Legacy={version:1;attempt:string;entries:[string,string][]};
const event='payroll-payment-pending';
function read(key:string){try{return localStorage.getItem(key)??'';}catch{return '';}}
function decode(value:string):Pending|null{try{const p=JSON.parse(value);return p.version===2&&uuid(p.attempt)&&p.actor&&p.tenant&&p.employer&&p.output?p:null;}catch{return null;}}
function decodeLegacy(value:string):Legacy|null{try{const p=JSON.parse(value);return p.version===1&&uuid(p.attempt)&&Array.isArray(p.entries)&&p.entries.every((e:unknown)=>Array.isArray(e)&&e.length===2&&e.every(v=>typeof v==='string')&&(['tenant','employer','output','original','revision','operation','employee','date','reference','reason','confirmed'].includes(e[0])||/^amount:[0-9a-f-]{36}$/i.test(e[0])))?p:null;}catch{return null;}}
export function usePaymentRecovery(scope:Scope){
 const key='payroll-payment:v2:'+JSON.stringify([scope.actor,scope.tenant,scope.employer,scope.output]);
 const legacyKey='payroll-payment:v1:'+JSON.stringify([scope.actor,scope.tenant,scope.employer,scope.output]);
 const snapshot=useSyncExternalStore(notify=>{window.addEventListener(event,notify);window.addEventListener('storage',notify);window.addEventListener('pageshow',notify);return()=>{window.removeEventListener(event,notify);window.removeEventListener('storage',notify);window.removeEventListener('pageshow',notify);};},()=>JSON.stringify([read(key),read(legacyKey)]),()=> '["",""]');
 const [serialized,legacyRaw]=JSON.parse(snapshot) as [string,string];
 function write(record:Pending|null){try{if(record)localStorage.setItem(key,JSON.stringify(record));else localStorage.removeItem(key);window.dispatchEvent(new Event(event));return true;}catch{return false;}}
 const initial:PaymentState={error:'',saved:false,revision:scope.revision,signature:'',attempt:''};
 const [state,action,pending]=useActionState(async(previous:PaymentState,form:FormData)=>{
  if(!navigator.locks)return {...previous,saved:false,error:'تعذر حماية الطلب بين نوافذ المتصفح. استخدم متصفحًا يدعم حماية الطلبات قبل المتابعة.'};
  return navigator.locks.request(key,{ifAvailable:true},async lock=>{
   if(!lock)return {...previous,saved:false,error:'يوجد طلب قيد التنفيذ في صفحة أخرى. انتظر نتيجته ثم تحقّق هنا.'};
   const v2=read(key),v1=read(legacyKey),decoded=decode(v2),existing=decoded&&decoded.actor===scope.actor&&decoded.tenant===scope.tenant&&decoded.employer===scope.employer&&decoded.output===scope.output?decoded:null,legacy=decodeLegacy(v1),cancel=form.get('__cancel')==='yes',recover=form.get('__recover')==='yes'||cancel;
   if((v2&&!existing)||(v1&&!legacy)||(v1&&v2&&legacy&&existing&&legacy.attempt!==existing.attempt))return {...previous,saved:false,error:'يوجد طلب محفوظ لم تتأكد نتيجته أو تختلف بياناته. استرجع نتيجته أو راجع مسؤول النظام قبل تسجيل دفعة أخرى.'};
   if((existing||legacy)&&!recover)return {...previous,saved:false,error:'استعد نتيجة طلب الدفعة السابق أولًا.'};
   if(recover&&!existing&&!legacy&&!scope.recoveryAttempt)return {...previous,saved:false,error:'حُسم الطلب السابق بالفعل. حدّث المطابقة قبل إجراء جديد.'};
   const attempt=existing?.attempt||legacy?.attempt||scope.recoveryAttempt||crypto.randomUUID();
   if(legacy&&recover&&!cancel){form.delete('__recover');form.set('__migrate','yes');legacy.entries.forEach(([k,v])=>form.append(k,v));}
   if(!existing&&!legacy&&!recover&&!write({version:2,attempt,actor:scope.actor,tenant:scope.tenant,employer:scope.employer,output:scope.output}))return {...previous,saved:false,error:'تعذر حفظ مرجع الطلب على هذا الجهاز؛ لم يُرسل أي طلب.'};
   form.set('tenant',scope.tenant);form.set('employer',scope.employer);form.set('output',scope.output);form.set('__attempt',attempt);form.set('__actor',scope.actor);
   try{const result=await paymentAction({...previous,recoverPending:Boolean(existing)||Boolean(legacy)||Boolean(scope.recoveryAttempt)},form);if(legacy&&result.prepared&&!result.saved&&write({version:2,attempt,actor:scope.actor,tenant:scope.tenant,employer:scope.employer,output:scope.output})){try{localStorage.removeItem(legacyKey);window.dispatchEvent(new Event(event));}catch{}}if(result.saved||result.cancelled){write(null);try{localStorage.removeItem(legacyKey);}catch{}}return result;}
   catch{return {...previous,saved:false,recoverPending:true,attempt,error:'لم تصل نتيجة الطلب. استعد نتيجة الطلب الأصلي قبل تسجيل دفعة أخرى.'};}
  });
 },initial);
 const v2Record=decode(serialized),v2Valid=v2Record&&v2Record.actor===scope.actor&&v2Record.tenant===scope.tenant&&v2Record.employer===scope.employer&&v2Record.output===scope.output,legacyRecord=decodeLegacy(legacyRaw);
 return {state,action,pending,unresolved:Boolean((serialized&&!v2Valid)||(legacyRaw&&!legacyRecord)||v2Valid||legacyRecord||(scope.recoveryAttempt&&!state.saved&&!state.cancelled))};
}
