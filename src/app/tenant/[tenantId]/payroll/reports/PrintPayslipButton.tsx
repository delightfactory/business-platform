'use client';
import {useEffect,useRef,useState} from 'react';
import {startPayslipPrint} from './print-session';
import {authorizePayslipPrint,type PayslipPrintScope} from './print-actions';
export function PrintPayslipButton({scope,refreshHref}:{scope:PayslipPrintScope;refreshHref:string}){
 const cleanup=useRef<(()=>void)|null>(null),signature=JSON.stringify(scope);
 useEffect(()=>()=>{cleanup.current?.();cleanup.current=null;},[signature]);
 const [pending,setPending]=useState(false),[error,setError]=useState('');
 async function print(){
  setPending(true);setError('');
  try{const result=await authorizePayslipPrint(scope);if(result.allowed){const root=document.getElementById('payroll-report');if(!root||root.getAttribute('data-print-scope')!==signature){setError('تغيرت القسيمة المفتوحة. حدّثها قبل الطباعة.');return;}cleanup.current?.();cleanup.current=startPayslipPrint(root,window);}else setError(result.error);}
  catch{setError('تعذر التحقق من صلاحية القسيمة. أعد طلب الطباعة بعد عودة الاتصال.');}
  finally{setPending(false);}
 }
 return <div><button type="button" className="secondary-button" disabled={pending} onClick={print}>{pending?'جارٍ التحقق قبل الطباعة…':'طباعة القسيمة أو حفظها PDF'}</button>{error&&<p role="alert">{error} <a href={refreshHref}>تحديث القسيمة</a></p>}</div>;
}
