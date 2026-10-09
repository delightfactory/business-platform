'use client';
import { Button, Select } from '@/components/ui';
import styles from '../payroll.module.css';
import {useState} from 'react';
import {useRouter} from 'next/navigation';
import {PagedChoice,type ChoiceScope} from './PagedChoice';
import {correctionKinds,type CorrectionKind} from './rules';
export function SourcePicker({scope,href,employee,source}:{scope:ChoiceScope;href:string;employee:string;source:string}){
 const router=useRouter();const [kind,setKind]=useState(scope.kind),[person,setPerson]=useState(employee);
 const go=(id='')=>{const url=new URL(href,window.location.origin);url.searchParams.set('kind',kind);url.searchParams.set('employee',kind==='source_change'?'':person);url.searchParams.set('source',id);url.searchParams.delete('after');router.push(url.pathname+url.search);};
 return <div className={styles.fields}><label>ما الذي يحتاج إلى تصحيح؟<Select value={kind} onChange={e=>setKind(e.target.value)}>{Object.entries(correctionKinds).map(([id,name])=><option key={id} value={id}>{name}</option>)}</Select></label>{kind!=='source_change'&&<label>الموظف<PagedChoice scope={{...scope,kind}} choice="employees" value={person} onChange={setPerson} placeholder="الموظف"/></label>}<Button variant="solid" type="button" onClick={()=>go()}>عرض الخيارات</Button>{kind!=='new_employment'&&<label>{kind==='source_change'?'التغيير المسجل':'النسخة المؤرخة'}<PagedChoice scope={{...scope,kind,employee:kind==='source_change'?undefined:person}} choice="sources" value={kind===scope.kind?source:''} onChange={id=>go(id)} placeholder={correctionKinds[kind as CorrectionKind]}/></label>}</div>;
}
