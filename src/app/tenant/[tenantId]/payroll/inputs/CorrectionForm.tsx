'use client';
import {useActionState,useState} from 'react';
import {correctionAction} from './actions';
import styles from '../payroll.module.css';
export function CorrectionForm({tenant,employer,period,employment,name}:{tenant:string;employer:string;period:string;employment:string;name:string}) {
 const [reason,setReason]=useState('');const [state,action,pending]=useActionState(correctionAction,{error:'',saved:false,attempt:'',signature:''});
 return <form action={action} onReset={e=>e.preventDefault()} className={styles.form}><h3>طلب تصحيح تاريخ {name}</h3><input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employer" value={employer}/><input type="hidden" name="period" value={period}/><input type="hidden" name="employment" value={employment}/><label htmlFor={`reason-${employment}`}>وصف التغيير المطلوب<input id={`reason-${employment}`} name="reason" value={reason} onChange={e=>setReason(e.target.value)} minLength={3} maxLength={500} required/></label><p>يوثق الطلب مسؤولية التصحيح؛ لا يفتح الراتب ولا يغيّر بيانات الموظف. يراجع مسؤول الرواتب الطلب قبل إجراء أي تغيير.</p>{state.error&&<p role="alert">{state.error}</p>}{state.saved&&<p role="status">تم توثيق طلب التصحيح.</p>}<button disabled={pending||state.saved} className="secondary-button">توثيق طلب التصحيح</button></form>;
}
