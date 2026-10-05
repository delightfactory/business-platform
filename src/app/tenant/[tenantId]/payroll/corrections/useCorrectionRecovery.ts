'use client';
import {useActionState,useEffect,useEffectEvent,useRef,useState,useSyncExternalStore} from 'react';
import {correctionAction} from './actions';
import type {CorrectionState} from './rules';
type Scope={actor:string;tenant:string;employer:string;output:string};
type Pending={version:1;form:string;href:string;attempt:string;entries:[string,string][];previous:CorrectionState};
const empty:CorrectionState={error:'',saved:false,signature:'',attempt:''};
const event='payroll-correction-pending';
const key=(s:Scope)=>'payroll-correction:v1:'+JSON.stringify([s.actor,s.tenant,s.employer,s.output]);
function read(storageKey:string){try{return localStorage.getItem(storageKey)??'';}catch{return '';}}
function decode(value:string):Pending|null{try{const p=JSON.parse(value);return p.version===1&&typeof p.form==='string'&&typeof p.attempt==='string'&&Array.isArray(p.entries)&&p.entries.every((x:unknown)=>Array.isArray(x)&&x.length===2&&x.every(v=>typeof v==='string'))?p:null;}catch{return null;}}
export function useCorrectionRecovery(scope:Scope,form:string,restore:(data:FormData)=>void){
 const [previewValid,setPreviewValid]=useState(false);
 const storageKey=key(scope),onRestore=useEffectEvent(restore);
 const serialized=useSyncExternalStore(callback=>{window.addEventListener(event,callback);window.addEventListener('storage',callback);window.addEventListener('pageshow',callback);return()=>{window.removeEventListener(event,callback);window.removeEventListener('storage',callback);window.removeEventListener('pageshow',callback);};},()=>read(storageKey),()=> '');
 const record=decode(serialized),lastRestored=useRef('');
 useEffect(()=>{if(serialized&&serialized!==lastRestored.current&&record?.form===form){lastRestored.current=serialized;const data=new FormData();record.entries.forEach(([k,v])=>data.append(k,v));onRestore(data);}},[serialized,form,record]);
 const write=(p:Pending|null)=>{if(p)localStorage.setItem(storageKey,JSON.stringify(p));else localStorage.removeItem(storageKey);window.dispatchEvent(new Event(event));};
 const [state,action,pending]=useActionState(async(previous:CorrectionState,data:FormData)=>{
  const existing=decode(read(storageKey));if(!existing)previous={...previous,recoverPending:false,signature:'',attempt:''};
  if(form==='receipt-recovery'&&!existing)return {...previous,saved:false,error:'حُسم الطلب السابق بالفعل. حدّث المراجعة قبل إجراء جديد.'};
  if(existing&&existing.form!==form&&form!=='receipt-recovery')return {...previous,saved:false,error:'يلزم استعادة نتيجة الطلب السابق من نموذجه قبل تنفيذ إجراء آخر.'};
  const operation=String(data.get('operation')??'');
  if(!existing&&operation==='preview'){setPreviewValid(false);try{const result=await correctionAction({...previous,previewHash:undefined},data);setPreviewValid(Boolean(result.previewHash)&&!result.error);return result;}catch{return {...previous,previewHash:undefined,saved:false,error:'تعذر تأكيد المعاينة. أعد المعاينة قبل الحفظ.'};}}
  let original=existing;
  if(!original){data.set('__actor',scope.actor);const attempt=crypto.randomUUID();data.set('__attempt',attempt);original={version:1,form,href:window.location.pathname+window.location.search,attempt,entries:Array.from(data.entries()).map(([k,v])=>[k,String(v)]),previous};try{write(original);}catch{return {...previous,saved:false,error:'تعذر حفظ هوية الطلب على هذا الجهاز. لم يُرسل الإجراء؛ فعّل تخزين الموقع ثم أعد المحاولة.'};}}
  const request=new FormData();original.entries.forEach(([k,v])=>request.append(k,v));request.set('__attempt',original.attempt);request.set('__actor',scope.actor);
  try{const result=await correctionAction({...original.previous,recoverPending:Boolean(existing)||original.previous.recoverPending},request);if(result.saved||!existing&&!result.recoverPending)write(null);else write({...original,previous:{...original.previous,...result,recoverPending:true,previewHash:original.previous.previewHash}});return result;}
  catch{return {...original.previous,saved:false,recoverPending:true,error:'لم تصل نتيجة الطلب. القيم وهوية الطلب محفوظة؛ استعد النتيجة الأصلية قبل أي إجراء جديد.'};}
 },empty);
 return {state,action,pending,previewValid,invalidatePreview:()=>setPreviewValid(false),unresolved:Boolean(serialized),owns:record?.form===form||form==='receipt-recovery',summary:record?.entries.filter(([k])=>['amount','date','reference','reason'].includes(k))??[],originalHref:record?.href.startsWith(`/tenant/${scope.tenant}/payroll/corrections`)?record.href:`/tenant/${scope.tenant}/payroll/corrections`,originalOperation:record?.entries.find(([k])=>k==='operation')?.[1]??''};
}
