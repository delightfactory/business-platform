'use client';

import { useRef, useState } from 'react';
import { Button, Field, Input, Message, Select } from '@/components/ui';
import { displayRetention, retentionUnits } from '@/lib/attendance-retention';
import { findSourceSites } from './actions';
import type { SourceSite, SourceSites } from './shared';
import styles from '../attendance-channels.module.css';

export function SourceSitePicker({tenantId,initial,initialSearch,selected,onSelect,onAccess,optional=false}:{
  tenantId:string;initial:SourceSites;initialSearch:string;selected?:SourceSite;
  onSelect:(site:SourceSite|undefined)=>void;onAccess:(denied:boolean)=>void;optional?:boolean;
}) {
  const [results,setResults]=useState(initial);
  const [search,setSearch]=useState(initialSearch);
  const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState('');
  const request=useRef(0);
  const items=selected&&!results.items.some(item=>item.id===selected.id)?[selected,...results.items]:results.items;
  async function lookup() {
    const sequence=++request.current;
    setBusy(true);setMessage('');
    try {
      const result=await findSourceSites(tenantId,search.trim());
      if(sequence!==request.current)return;
      if(result.data) {setResults(result.data);onAccess(false);}
      else {setMessage(result.message??'تعذر البحث. بقيت اختياراتك؛ حاول مرة أخرى.');if(result.denied)onAccess(true);}
    } catch {if(sequence===request.current)setMessage('تعذر البحث. بقيت اختياراتك؛ حاول مرة أخرى.');}
    finally {if(sequence===request.current)setBusy(false);}
  }
  return <div className="source-site-picker" aria-busy={busy}>
    <div className={styles.sourceSiteSearch}><Field id="source-site-search" label="ابحث عن الفرع"><Input id="source-site-search" value={search} maxLength={100} placeholder="مثال: المقر الرئيسي" onChange={event=>setSearch(event.target.value)} onKeyDown={event=>{if(event.key==='Enter'){event.preventDefault();void lookup();}}}/></Field><Button variant="ghost" type="button" onClick={()=>void lookup()} disabled={busy}>{busy?'جارٍ البحث…':'بحث'}</Button></div>
    <Field id="source-site" label={optional?'فرع العمل (اختياري)':'فرع العمل'}><Select id="source-site" name="site" required={!optional} value={selected?.id??''} onChange={event=>onSelect(items.find(item=>item.id===event.target.value))}><option value="">اختر الفرع</option>{items.map(item=><option key={item.id} value={item.id}>{item.display_name}</option>)}</Select></Field>
    <p className="field-hint" role="status">{busy?'جارٍ البحث؛ سيبقى الفرع المختار والمسودة كما هما.':!results.items.length?'لا يوجد فرع نشط بهذا الاسم. جرّب اسمًا آخر، أو اطلب من مسؤول الشركة إضافة الفرع.':results.has_more?'تظهر أول 20 نتيجة؛ اكتب جزءًا أدق من الاسم.':''}</p>
    {message&&<Message tone="bad" role="alert">{message}</Message>}
  </div>;
}

export function RetentionField({prefix,seconds}:{prefix:string;seconds?:number}) {
  const initial=displayRetention(seconds);
  const [unit,setUnit]=useState(initial.unit);
  const factor=retentionUnits.find(item=>item.value===unit)!.seconds;
  return <div className={styles.sourceRetention}>
    <Field id={`${prefix}-retention`} label="مدة حفظ دليل الموقع" help="مدة حفظ دليل الموقع قبل أن يصبح قابلًا للحذف، من دقيقة إلى 30 يومًا. يبقى سجل الحضور محفوظًا. اختر المدة المعتمدة في سياسة خصوصية الشركة."><Input id={`${prefix}-retention`} name="retention_amount" type="number" min={Math.ceil(60/factor)} max={2592000/factor} step={1} defaultValue={initial.amount} required placeholder="اكتب المدة المعتمدة"/></Field>
    <Field id={`${prefix}-retention-unit`} label="وحدة المدة"><Select id={`${prefix}-retention-unit`} name="retention_unit" value={unit} onChange={event=>setUnit(event.target.value)}>{retentionUnits.map(item=><option key={item.value} value={item.value}>{item.label}</option>)}</Select></Field>
  </div>;
}
