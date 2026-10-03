'use client';
import {useState} from 'react';
import {useRouter} from 'next/navigation';
import {PagedChoice,type ChoiceScope} from './PagedChoice';
import {correctionKinds,type CorrectionKind} from './rules';
export function SourcePicker({scope,href,employee,source}:{scope:ChoiceScope;href:string;employee:string;source:string}){
 const router=useRouter();const [kind,setKind]=useState(scope.kind),[person,setPerson]=useState(employee);
 const go=(id='')=>{const url=new URL(href,window.location.origin);url.searchParams.set('kind',kind);url.searchParams.set('employee',kind==='source_change'?'':person);url.searchParams.set('source',id);url.searchParams.delete('after');router.push(url.pathname+url.search);};
 return <div><label>ما الذي يحتاج إلى تصحيح؟<select value={kind} onChange={e=>setKind(e.target.value)}>{Object.entries(correctionKinds).map(([id,name])=><option key={id} value={id}>{name}</option>)}</select></label>{kind!=='source_change'&&<label>الموظف<PagedChoice scope={{...scope,kind}} choice="employees" value={person} onChange={setPerson} placeholder="الموظف"/></label>}<button type="button" onClick={()=>go()}>عرض الخيارات</button>{kind!=='new_employment'&&<label>{kind==='source_change'?'التغيير المسجل':'النسخة المؤرخة'}<PagedChoice scope={{...scope,kind,employee:kind==='source_change'?undefined:person}} choice="sources" value={kind===scope.kind?source:''} onChange={id=>go(id)} placeholder={correctionKinds[kind as CorrectionKind]}/></label>}</div>;
}
