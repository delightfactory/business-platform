'use client';
import Link from 'next/link';
import {startTransition,useActionState,useRef,useState} from 'react';
import {saveDraftAction} from './actions';
import {NumericRulesEditor,type NumericRules} from './NumericRules';
export type DraftState={head:string;revision:number;saved:boolean;error:string;uncertain:boolean;stale?:boolean};
export type Source={title:string;url:string};
type Props={actor:string;head?:string;revision?:number;version?:string;from?:string;until?:string|null;sources?:Source[];numericRules?:NumericRules|null;next?:string;issued?:boolean;secondary?:boolean};
export function DraftForm(props:Props){
 const pendingRequest=useRef<{signature:string;attempt:string}|null>(null);
 const inFlight=useRef(false);
 const [dirty,setDirty]=useState(false);
 const [editing,setEditing]=useState(false);
 const [values,setValues]=useState({version:props.version??'',from:props.from??'',until:props.until??'',reason:'',sources:Array.from({length:6},(_,i)=>props.sources?.[i]??{title:'',url:''})});
 const setField=(field:'version'|'from'|'until'|'reason',value:string)=>setValues(current=>({...current,[field]:value}));
 const setSource=(index:number,field:'title'|'url',value:string)=>setValues(current=>({...current,sources:current.sources.map((source,i)=>i===index?{...source,[field]:value}:source)}));
 async function submit(previous:DraftState,form:FormData):Promise<DraftState>{
  try{
  const signature=JSON.stringify(Array.from(form.entries()));
  if(pendingRequest.current&&previous.uncertain&&pendingRequest.current.signature!==signature)return {...previous,saved:false,error:'استعد نتيجة الحفظ السابق بنفس البيانات أولًا.'};
  if(!pendingRequest.current||pendingRequest.current.signature!==signature)pendingRequest.current={signature,attempt:crypto.randomUUID()};
  form.set('__attempt',pendingRequest.current.attempt);form.set('__actor',props.actor);
  try{const result=await saveDraftAction(previous,form);if(!result.uncertain)pendingRequest.current=null;if(result.saved){setDirty(false);if(props.head)setEditing(false);setValues(current=>({...current,reason:''}));}return result;}
  catch{return {...previous,saved:false,uncertain:true,error:'لم تصل نتيجة الحفظ. الحقول كما هي؛ أعد المحاولة بنفس البيانات لاستعادة النتيجة.'};}
  }finally{inFlight.current=false;}
 }
 const [state,action,pending]=useActionState(submit,{head:props.head??'',revision:props.revision??0,saved:false,error:'',uncertain:false});
 const fields=values.sources;
 const source=(i:number)=><div className="limit-fields" key={i}><label htmlFor={`draft-source-title-${i}`}>اسم المرجع {i+1}<input id={`draft-source-title-${i}`} name="sourceTitle" value={fields[i].title} onChange={event=>setSource(i,'title',event.target.value)} maxLength={160} required={i===0} readOnly={state.uncertain||pending||state.stale}/></label><label htmlFor={`draft-source-url-${i}`}>رابط المرجع {i+1}<input id={`draft-source-url-${i}`} name="sourceUrl" type="url" dir="ltr" value={fields[i].url} onChange={event=>setSource(i,'url',event.target.value)} maxLength={2048} required={i===0} readOnly={state.uncertain||pending||state.stale}/></label></div>;
 const activeEdit=dirty||pending||state.uncertain||state.stale||Boolean(state.error);
 const acknowledgement=state.saved&&!dirty&&!pending?<p role="status" className="form-message">حُفظت المسودة مع الاحتفاظ بالنسخ السابقة. لم تُعتمد حزمة لحساب الرواتب.</p>:null;
 const form=<form action={action} onSubmit={event=>{event.preventDefault();if(inFlight.current||pending||state.stale)return;const form=new FormData(event.currentTarget);inFlight.current=true;startTransition(()=>action(form));}} onChange={()=>setDirty(true)} onInvalid={event=>{if(!(event.target instanceof HTMLElement))return;let parent=event.target.parentElement;while(parent&&parent!==event.currentTarget){if(parent instanceof HTMLDetailsElement)parent.open=true;parent=parent.parentElement;}}} className="auth-form" aria-busy={pending}><h2>{props.issued?'إنشاء نسخة جديدة من القواعد':state.head?'تعديل بيانات المسودة':'حفظ مسودة جديدة'}</h2>
 <label htmlFor="draft-version">اسم النسخة<input id="draft-version" name="version" value={values.version} onChange={event=>setField('version',event.target.value)} required minLength={3} maxLength={100} readOnly={Boolean(state.head)||state.uncertain||pending||state.stale}/></label>
 <label htmlFor="draft-from">بداية السريان<input id="draft-from" name="from" type="date" value={values.from} onChange={event=>setField('from',event.target.value)} required min="1900-01-01" max="2200-12-31" readOnly={state.uncertain||pending||state.stale}/></label>
 <label htmlFor="draft-until">تاريخ التوقف (اختياري)<input id="draft-until" name="until" type="date" value={values.until} onChange={event=>setField('until',event.target.value)} min="1900-01-01" max="2200-12-31" readOnly={state.uncertain||pending||state.stale}/></label><p className="field-hint">إذا حددت تاريخ التوقف، لا تسري القواعد من هذا التاريخ.</p>
 <fieldset disabled={pending}><legend>المراجع الرسمية</legend>{source(0)}<details open={Boolean(props.sources&&props.sources.length>1)}><summary>مراجع إضافية</summary>{fields.slice(1).map((_,i)=>source(i+1))}</details></fieldset>
 <NumericRulesEditor initial={props.numericRules??null} frozen={Boolean(state.uncertain||pending||state.stale)} onEdit={()=>setDirty(true)}/>
 <label htmlFor="draft-reason">سبب الحفظ أو التعديل</label><textarea id="draft-reason" name="reason" value={values.reason} onChange={event=>setField('reason',event.target.value)} required minLength={3} maxLength={500} rows={3} readOnly={state.uncertain||pending||state.stale}/>
 <p className="field-hint">الحفظ يسجّل مسودة ومراجعها فقط. لا يعتمد القواعد ولا يجعلها صالحة لحساب مبالغ الصرف.</p>
 {state.error&&<p role="alert" className="form-message form-error">{state.error}</p>}
 {state.stale?<a className="primary-button" href={`/operator/statutory?head=${encodeURIComponent(state.head)}`} target="_blank" rel="noopener noreferrer">فتح النسخة الحالية للمقارنة في نافذة جديدة</a>:<button className={state.saved&&!dirty?"secondary-button":"primary-button"} disabled={pending}>{pending?'جارٍ الحفظ…':state.uncertain?'استعادة نتيجة الحفظ':props.issued?'حفظ نسخة جديدة':state.head?'حفظ تعديل المسودة':'حفظ المسودة'}</button>}
 {state.head&&!state.stale&&<Link className={state.saved&&!dirty&&!pending?"primary-button":"secondary-button"} href={`/operator/statutory?head=${encodeURIComponent(state.head)}`}>مراجعة المسودة المحفوظة وسجلها</Link>}
 </form>;
 if(!props.head)return <details open={editing||activeEdit} onToggle={event=>{if(activeEdit&&!event.currentTarget.open){event.currentTarget.open=true;return;}setEditing(event.currentTarget.open);}}><summary className="primary-button">مسودة جديدة</summary>{form}{acknowledgement}</details>;
 const editRequired=!props.next&&!props.issued&&!props.secondary;
 return <>{acknowledgement}{props.next&&<p><Link href={props.next} className={activeEdit||editing?'secondary-button':'primary-button'}>مراجعة الحساب مع نتائج المقارنة</Link></p>}
 <details open={editRequired||editing||activeEdit} onToggle={event=>{if((editRequired||activeEdit)&&!event.currentTarget.open){event.currentTarget.open=true;return;}setEditing(event.currentTarget.open);}}><summary className="secondary-button">{props.issued?'إنشاء نسخة جديدة':'تعديل المسودة'}</summary>
 <p className="field-hint">التعديل يحفظ نسخة جديدة تحتاج مقارنات جديدة؛ أدلة النسخ السابقة لا تتغير.</p>{form}</details></>;
}
