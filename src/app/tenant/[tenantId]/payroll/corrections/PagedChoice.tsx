'use client';
import {useCallback,useEffect,useRef,useState} from 'react';
import {correctionChoices} from './actions';
import {uuid} from '../rules';
import {kindNames,type InputKind} from '../inputs/rules';
export type Choice={id:string;name:string;version?:number;cursor?:string;[key:string]:unknown};
export type ChoiceScope={tenant:string;employer:string;output:string;kind:string;employee?:string};
export function PagedChoice({scope,choice,name,value,onChange,initial=[],required=false,placeholder='اختر',version,onItem}:{scope:ChoiceScope;choice:string;name?:string;value:string;onChange:(value:string)=>void;initial?:Choice[];required?:boolean;placeholder?:string;version?:number;onItem?:(item:Choice)=>void}){
 const [items,setItems]=useState(initial),[selected,setSelected]=useState<Choice|null>(initial.find(x=>x.id===value)??null),[query,setQuery]=useState(''),[next,setNext]=useState<string|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState('');const generation=useRef(0);
 const {tenant,employer,output,kind,employee}=scope;
 const update=useCallback((result:Awaited<ReturnType<typeof correctionChoices>>)=>{setBusy(false);if(result.error){setError(result.error);return;}const page=result.data as {items:Choice[];selected:Choice|null;next:string|null};setItems(page.items.map(x=>x.kind?{...x,name:(kindNames[x.kind as InputKind]??'مدخل راتب')+' · '+x.name.replace(/^[^·]+· /,'')}:x));setSelected(page.selected);setNext(page.next);setError('');},[]);
 const load=useCallback(async(after:string|null,q:string)=>{const current=++generation.current;const result=await correctionChoices({tenant,employer,output,kind},choice,q,after,uuid(value)?value:null,version??null,employee??null).catch(()=>({error:'تعذر تحميل الخيارات. أعد البحث بنفس السياق.'}));if(current===generation.current)update(result);},[tenant,employer,output,kind,employee,choice,value,version,update]);
 useEffect(()=>{const current=++generation.current;void correctionChoices({tenant,employer,output,kind},choice,'',null,uuid(value)?value:null,version??null,employee??null).catch(()=>({error:'تعذر تحميل الخيارات. أعد البحث بنفس السياق.'})).then(result=>{if(current===generation.current)update(result);});},[tenant,employer,output,kind,employee,choice,value,version,update]);
 const special=initial.filter(x=>x.id.startsWith('new:'));
 const pageItems=[...special,...items.filter(x=>!special.some(s=>s.id===x.id))];
 const options=selected&&!items.some(x=>x.id===selected.id&&x.version===selected.version)?[selected,...pageItems]:pageItems;
 const optionValue=(x:Choice)=>x.version==null?x.id:x.id+':'+x.version;
 const current=version==null||!value?value:value+':'+version;
 return <span><span><input aria-label={'بحث '+placeholder} value={query} maxLength={120} onChange={e=>setQuery(e.target.value)} disabled={busy}/><button type="button" className="secondary-button" disabled={busy} onClick={()=>{setBusy(true);void load(null,query);}}>بحث</button></span><select value={current} required={required} disabled={busy} onChange={e=>{const item=options.find(x=>optionValue(x)===e.target.value);onChange(item?.id??'');if(item)onItem?.(item);}}><option value="">{placeholder}</option>{value&&!options.some(x=>optionValue(x)===current)&&<option value={current}>القيمة المحددة في السجل</option>}{options.map(x=><option key={optionValue(x)} value={optionValue(x)}>{x.name}</option>)}</select>{name&&<input type="hidden" name={name} value={value}/>}<span>{next&&<button type="button" className="secondary-button" disabled={busy} onClick={()=>{setBusy(true);void load(next,query);}}>خيارات إضافية</button>}{query&&<button type="button" className="secondary-button" disabled={busy} onClick={()=>{setQuery('');setBusy(true);void load(null,'');}}>كل الخيارات</button>}</span>{error&&<span role="alert">{error}</span>}</span>;
}
