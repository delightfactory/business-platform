'use client';
import { Button, Input, Message, Field } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import {useActionState,useState} from 'react';
import Link from 'next/link';
import {correctionAction} from './actions';
import styles from '../payroll.module.css';
export function CorrectionForm({tenant,employer,period,employment,name}:{tenant:string;employer:string;period:string;employment:string;name:string}) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHintId = useId();
 const [reason,setReason]=useState('');const [state,action,pending]=useActionState(correctionAction,{error:'',saved:false,attempt:'',signature:''});
 const showOfflineNotice = offline && !pending && !state.saved;
 return <form action={action} onReset={e=>e.preventDefault()} className={styles.form} onSubmit={(event) => { blockOfflineSubmission(event); }}><h3>طلب تصحيح تاريخ {name}</h3><input type="hidden" name="tenant" value={tenant}/><input type="hidden" name="employer" value={employer}/><input type="hidden" name="period" value={period}/><input type="hidden" name="employment" value={employment}/><Field  id={`reason-${employment}`} label={<>وصف التغيير المطلوب</>}><Input id={`reason-${employment}`} name="reason" value={reason} onChange={e=>setReason(e.target.value)} minLength={3} maxLength={500} required/></Field><p>يوثق الطلب مسؤولية التصحيح؛ لا يفتح الراتب ولا يغيّر بيانات الموظف. يستكمل مسؤول التصحيح المخول مراجعة المقترح المؤرخ ومخرجاته المتأثرة.</p><Link href={`/tenant/${tenant}/payroll/corrections?${new URLSearchParams({employer,period,employee:employment,kind:'input_revision'})}`}>فتح مسار التصحيح للمسؤول المخول</Link>{state.error&&<Message tone="bad" role="alert">{state.error}</Message>}{state.saved&&<Message tone="info" role="status">تم توثيق طلب التصحيح.</Message>}<Button variant="ghost" type="submit" disabled={offline || (pending||state.saved)}  aria-describedby={showOfflineNotice ? offlineHintId : undefined}>توثيق طلب التصحيح</Button>{showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}</form>;
}
