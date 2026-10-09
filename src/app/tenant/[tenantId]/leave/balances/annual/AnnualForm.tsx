'use client';
import { Button, Card, Disclosure, Field, Input, KeyValueStrip, Message, Panel, RecordCard, Textarea } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { useActionState,useState } from 'react';
import { formatDays } from '../../rules';
import { annualAction } from './actions';
import { EMPTY_ANNUAL_STATE,type Policy,type Rate } from './rules';
export function AnnualForm({tenant,employee,employer,type,period,policy,canManage,asOf,serviceStart,initialRates,initialSource}:{tenant:string;employee:string;employer:string;type:string;period:string;policy:Policy;canManage:boolean;asOf:string;serviceStart:string;initialRates:Rate[];initialSource:string}){
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHintId = useId();
 const [state,action,pending]=useActionState(annualAction,EMPTY_ANNUAL_STATE);
 const [date,setDate]=useState(asOf),[source,setSource]=useState(initialSource),[reason,setReason]=useState(''),[rates,setRates]=useState<Rate[]>(initialRates);
 const [first,setFirst]=useState(String(policy.first_year_days)),[later,setLater]=useState(String(policy.later_year_days)),[minimum,setMinimum]=useState(String(policy.minimum_service_days)),[basis,setBasis]=useState(String(policy.year_days));
 const [policySource,setPolicySource]=useState(''),[policyReason,setPolicyReason]=useState(''),[key,setKey]=useState(()=>crypto.randomUUID());
 const current=state.policy??policy,signature=JSON.stringify([date,source.trim(),rates]),quote=state.quote,ready=quote!==null&&state.reviewedInput===signature&&!state.posted;
 function change(){setKey(crypto.randomUUID());}
 function updateRate(index:number,patch:Partial<Rate>){change();setRates(rates.map((r,i)=>i===index?{...r,...patch}:r));}
 const showOfflineNotice = offline && !pending;
 return <form action={action} className="auth-form" aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
  {Object.entries({tenant,employee,employer,type,period}).map(([name,value])=><input key={name} type="hidden" name={name} value={value}/>)}
  <input type="hidden" name="rates" value={JSON.stringify(rates)}/><input type="hidden" name="reviewHash" value={quote?.review_hash??''}/><input type="hidden" name="operationKey" value={key}/><input type="hidden" name="policyVersion" value={current.version}/>
  <fieldset disabled={pending} style={{border:0,padding:0,minWidth:0}}>
   <p>خدمة الموظف تبدأ في <bdi>{serviceStart}</bdi>. تتراكم المنحة عن الأيام الفعلية، ويُسجّل الفرق فقط؛ استهلاك الإجازات يبقى محفوظًا.</p>
   <Field id="annual-date" label={<>حساب الخدمة حتى</>} required><Input id="annual-date" name="asOf" type="date" required max={asOf} value={date} onChange={e=>{change();setDate(e.target.value);}}/></Field>
   <Field id="annual-source" label={<>مرجع التحقق من فئة استحقاق الموظف</>} required><Input id="annual-source" name="source" required minLength={3} maxLength={300} value={source} onChange={e=>{change();setSource(e.target.value);}}/></Field>
   <p className="field-hint">قاعدة الشركة المعروضة {formatDays(current.first_year_days)} يوم في السنة الأولى، ثم {formatDays(current.later_year_days)} يوم؛ الأهلية بعد {current.minimum_service_days} يوم خدمة، ومقام الحساب {current.year_days}. تُقرّب الحصيلة لأعلى إلى 0.01 يوم. HR مسؤول عن توثيق الفئات الخاصة ومزاياها.</p>
   <Disclosure  summary={<>فئات خاصة أو تغيّر موثّق في الاستحقاق</>}><p className="field-hint">أضف تاريخ بداية كل فئة وقيمتها السنوية ومرجع التحقق. تطبّق القيمة من ذلك التاريخ حتى التغيير التالي؛ لا تُستنتج الفئة تلقائيًا.</p>
    {rates.map((rate,index)=><Card  key={index}>
     <Field id={`annual-from-${index}`} label={<>بداية الفئة {index+1}</>} required><Input id={`annual-from-${index}`} type="date" required min={serviceStart} max={date} value={rate.from} onChange={e=>updateRate(index,{from:e.target.value})}/></Field>
     <Field id={`annual-days-${index}`} label={<>الاستحقاق السنوي للفئة {index+1}</>} required><Input id={`annual-days-${index}`} type="number" required min={15} max={366} step="0.01" value={rate.annual_days} onChange={e=>updateRate(index,{annual_days:Number(e.target.value)})}/></Field>
     <Field id={`annual-evidence-${index}`} label={<>مرجع الفئة {index+1}</>} required><Input id={`annual-evidence-${index}`} required minLength={3} maxLength={300} value={rate.source} onChange={e=>updateRate(index,{source:e.target.value})}/></Field>
     <Button variant="ghost" type="button"  onClick={()=>{change();setRates(rates.filter((_,i)=>i!==index));}}>حذف هذه الفئة من الحساب</Button>
    </Card>)}
    <Button variant="ghost" type="button"  disabled={rates.length>=32} onClick={()=>{change();setRates([...rates,{from:date,annual_days:30,source:''}]);}}>إضافة فئة موثّقة</Button>
   </Disclosure>
   <Button variant="ghost"  type="submit" name="intent" value="preview" aria-describedby={showOfflineNotice ? offlineHintId : undefined} disabled={offline}>عرض حساب الاستحقاق</Button>
   {quote&&<Panel aria-labelledby="annual-result"><h2 id="annual-result">الحساب المعروض</h2>
    <p className="field-hint">القاعدة المستخدمة في هذا الحساب: {formatDays(quote.policy.first_year_days)} / {formatDays(quote.policy.later_year_days)} يوم سنويًا؛ حدّ الخدمة {quote.policy.minimum_service_days} يوم ومقام الحساب {quote.policy.year_days}.</p>
    {!ready&&!state.posted&&<p className="field-hint">أعد عرض الحساب بعد تغيير بياناته.</p>}
    <KeyValueStrip items={[{ label: <>الخدمة الفعلية</>, value: <>{quote.service_days} يوم</> }, { label: <>الاستحقاق التراكمي</>, value: <>{formatDays(quote.target_total)} يوم</> }, { label: <>منه مسجّل سابقًا</>, value: <>{formatDays(quote.already_granted)} يوم</> }, { label: <>الفرق المطلوب تسجيله</>, value: <>{formatDays(quote.delta)} يوم</> }]} />
    {!quote.eligible&&<p role="status">لم يكتمل حدّ الخدمة؛ لا تتاح المنحة بعد.</p>}
    <ul className="record-list">{quote.segments.map((s,i)=><RecordCard key={i} ><bdi>{s.from}</bdi> إلى <bdi>{s.to}</bdi> · {s.days} يوم خدمة بمعدل {formatDays(s.annual_days)} يوم سنويًا<p>{s.source}</p></RecordCard>)}</ul>
    <Field id="annual-reason" label={<>سبب تسجيل الاستحقاق</>}><Textarea id="annual-reason" name="reason" minLength={3} maxLength={500} value={reason} onChange={e=>{setReason(e.target.value);setKey(crypto.randomUUID());}}/></Field>
    <Button variant="solid"  type="submit" name="intent" value="post" disabled={offline || (!ready||!quote.eligible||reason.trim().length<3)} aria-describedby={showOfflineNotice ? offlineHintId : undefined}>تأكيد تسجيل فرق الاستحقاق</Button>
   </Panel>}
   {canManage&&<Disclosure  summary={<>تعديل قاعدة الشركة لهذا النوع</>}><p className="field-hint">يُحفظ التغيير كنسخة جديدة لهذه الشركة ونوع الإجازة. الحدود تسمح بمزايا أفضل، وتبقى القيود السابقة محفوظة.</p>
    {([['firstYear','أيام السنة الأولى',first,setFirst,15,366],['laterYear','أيام السنوات التالية',later,setLater,21,366],['minimumService','حدّ الخدمة بالأيام',minimum,setMinimum,0,180],['yearDays','مقام حساب السنة',basis,setBasis,360,365]] as const).map(([name,label,value,set,min,max])=><div key={name}><Field id={name} label={<>{label}</>}><Input id={name} name={name} type="number" min={min} max={max} step={name==='firstYear'||name==='laterYear'?'0.01':'1'} value={value} onChange={e=>set(e.target.value)}/></Field></div>)}
    <Field id="annual-policy-source" label={<>مرجع قاعدة الشركة</>}><Input id="annual-policy-source" name="policySource" maxLength={300} value={policySource} onChange={e=>setPolicySource(e.target.value)}/></Field>
    <Field id="annual-policy-reason" label={<>سبب تعديل القاعدة</>}><Textarea id="annual-policy-reason" name="policyReason" maxLength={500} value={policyReason} onChange={e=>setPolicyReason(e.target.value)}/></Field>
    <Button variant="ghost" type="submit" name="intent" value="policy"  formNoValidate aria-describedby={showOfflineNotice ? offlineHintId : undefined} disabled={offline}>حفظ قاعدة الشركة</Button>
   </Disclosure>}
  </fieldset>
  {pending&&<p role="status">جارٍ تنفيذ العملية…</p>}{state.error&&<Message tone="bad"  role="alert">{state.error}</Message>}{state.message&&<Message tone="info"  role="status">{state.message}</Message>}
  {state.posted&&state.accountId&&<a className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenant}/leave/balances/${state.accountId}?employee=${employee}&employer=${employer}`}>فتح سجل حساب الاستحقاق</a>}
 {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}</form>;
}
