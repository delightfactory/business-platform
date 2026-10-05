'use client';
import {useActionState,useState} from 'react';
import {useRouter} from 'next/navigation';
import {paymentAction} from './actions';
import {money} from '../runs/rules';
import type {PaymentEmployee} from './rules';
import styles from '../payroll.module.css';
type Props={tenant:string;employer:string;output:string;revision:number;today:string;employees:PaymentEmployee[];remaining:string;remainingCount:number;original?:string;originalAmount?:string};
export function PaymentForm(p:Props){
 const router=useRouter();
 const [state,action,pending]=useActionState(paymentAction,{error:'',saved:false,revision:p.revision,signature:'',attempt:''});
 const [mode,setMode]=useState('allocations'),[date,setDate]=useState(p.today),[reference,setReference]=useState(''),[reason,setReason]=useState(''),[confirmed,setConfirmed]=useState(false),[selected,setSelected]=useState<string[]>([]),[amounts,setAmounts]=useState<Record<string,string>>({}),[another,setAnother]=useState(false);
 const [selectedRows,setSelectedRows]=useState<Record<string,PaymentEmployee>>({});
 const choices=[...p.employees,...selected.filter(id=>!p.employees.some(e=>e.employment_id===id)).map(id=>selectedRows[id]).filter(Boolean)];
 const correction=!!p.original;
 if(state.saved&&!another&&!pending)return <div role="status"><p>{correction?'حُفظ تصحيح القيد الخاطئ دون حذف الدفعة الأصلية.':'حُفظ تسجيل الدفعة الخارجية.'} المبلغ {money(state.amount)} · المتبقي {money(state.remaining)}</p>{!correction&&<button type="button" className="secondary-button" onClick={()=>{setAnother(true);setReference('');setReason('');setConfirmed(false);setSelected([]);setAmounts({});}}>تسجيل دفعة أخرى</button>}</div>;
 return <form action={action} onSubmit={()=>setAnother(false)} onReset={e=>e.preventDefault()} className={styles.form}>
 <input type="hidden" name="tenant" value={p.tenant}/><input type="hidden" name="employer" value={p.employer}/><input type="hidden" name="output" value={p.output}/><input type="hidden" name="original" value={p.original??''}/><input type="hidden" name="revision" value={Math.max(p.revision,state.revision)}/>
 <fieldset disabled={pending} className={styles.paymentFields}><legend>{correction?'تصحيح قيد خاطئ فقط':'تسجيل دفعة تم صرفها خارج النظام'}</legend>
 {correction?<><input type="hidden" name="operation" value="compensate"/><p>سيُعكس كامل هذا القيد ({money(p.originalAmount)}) مع الاحتفاظ به في السجل. هذا الإجراء لا يسترد مالًا من الموظف أو البنك.</p></>:<><label>نطاق الدفعة<select name="operation" value={mode} onChange={e=>setMode(e.target.value)}><option value="allocations">مبالغ محددة لموظفين</option><option value="remaining">كامل المتبقي لهذا المسير</option></select></label>{mode==='remaining'?<p>تُسجّل {money(p.remaining)} لكامل المتبقي لدى {p.remainingCount} موظفًا. راجع أن هذا المبلغ صُرف بالفعل.</p>:<><p>اختر من الموظفين المعروضين وحدد مبلغ كل موظف. لا يُوزّع مبلغ إجمالي تلقائيًا.</p>{choices.filter(e=>selected.includes(e.employment_id)||!/^0(?:\.0*)?$/.test(e.remaining)).map(e=><div key={e.employment_id}><label><input type="checkbox" name="employee" value={e.employment_id} checked={selected.includes(e.employment_id)} onChange={event=>{setSelectedRows(rows=>({...rows,[e.employment_id]:e}));setSelected(list=>event.target.checked?[...list,e.employment_id]:list.filter(id=>id!==e.employment_id));}}/>{e.employee_snapshot.name} · المتبقي {money(e.remaining)}</label>{selected.includes(e.employment_id)&&<label>المبلغ<input name={`amount:${e.employment_id}`} inputMode="decimal" pattern="[0-9]{1,16}(\.[0-9]{1,2})?" required value={amounts[e.employment_id]??''} onChange={event=>setAmounts(values=>({...values,[e.employment_id]:event.target.value}))}/></label>}</div>)}</>}</>}
 <label>{correction?'تاريخ تصحيح القيد':'تاريخ الصرف الفعلي'}<input name="date" type="date" required max={p.today} value={date} onChange={e=>setDate(e.target.value)}/></label>
 <label>مرجع القيد<input name="reference" minLength={3} maxLength={160} required value={reference} onChange={e=>setReference(e.target.value)}/></label>
 <label>{correction?'سبب خطأ القيد':'بيان الدفعة'}<textarea name="reason" required minLength={3} maxLength={500} value={reason} onChange={e=>setReason(e.target.value)}/></label>
 <label><input name="confirmed" type="checkbox" value="yes" required checked={confirmed} onChange={e=>setConfirmed(e.target.checked)}/>{correction?'أؤكد أن هذا تصحيح لقيد خاطئ فقط، وليس استردادًا لمال صُرف.':'أؤكد أن هذه المبالغ صُرفت خارج النظام وأن المرجع يخص هذه الدفعة.'}</label>
 <button disabled={pending||(!correction&&mode==='allocations'&&!selected.length)}>{pending?'جارٍ التحقق والحفظ…':state.recoverPending?'التحقق من نتيجة نفس الطلب':correction?'حفظ تصحيح القيد':'تسجيل الدفعة الخارجية'}</button></fieldset>{state.error&&<div role="alert"><p>{state.error}</p>{state.needsRefresh&&<button type="button" disabled={pending} className="secondary-button" onClick={()=>router.refresh()}>تحديث المطابقة مع الاحتفاظ بالحقول</button>}</div>}
 </form>;
}
