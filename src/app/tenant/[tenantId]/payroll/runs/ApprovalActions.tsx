'use client';
import {useActionState,useState} from 'react';
import {approvalAction} from './approval-actions';
import styles from '../payroll.module.css';
export function ApprovalActions({tenant,employer,period,run,candidate,revision,status}:{tenant:string;employer:string;period:string;run:string;candidate:string;revision:number;status:string}){
 const [reason,setReason]=useState('');
 const [state,action,pending]=useActionState(approvalAction,{error:'',saved:false,run,candidate,revision,status,attempt:'',signature:''});
 return <form action={action} onReset={e=>e.preventDefault()} className={styles.form}><input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employer" value={employer}/><input type="hidden" name="period" value={period}/><fieldset disabled={pending} className={styles.fields}><label>سبب {state.status==='approved'?'العودة إلى المراجعة':'اعتماد هذا المرشح'}<input name="reason" value={reason} onChange={e=>setReason(e.target.value)} minLength={3} maxLength={500} required/></label><p>يشمل الإجراء المرشح المعروض فقط. لا يطبّق المدخلات أو يقفل مبلغًا ماليًا.</p><button className="primary-button" name="operation" value={state.status==='approved'?'release':'approve'}>{state.status==='approved'?'العودة إلى المراجعة قبل إعادة الحساب':'اعتماد المرشح المعروض'}</button></fieldset>{pending&&<p role="status">جارٍ التحقق من المرشح والمصادر وحفظ الإجراء…</p>}{state.error&&<p role="alert">{state.error}</p>}{state.saved&&<p role="status">{state.status==='approved'?'حُفظ اعتماد المرشح؛ الإقفال المالي ما زال غير متاح.':'عاد المسير للمراجعة؛ يمكنك الآن معالجة المصدر وإعادة الحساب.'}</p>}</form>;
}
