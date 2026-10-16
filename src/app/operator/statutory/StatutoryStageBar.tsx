import Link from 'next/link';
import type { ReleaseStatus } from './comparisons/IssuanceStatus';
export function StatutoryStageBar({head,status,unavailable=false}:{head?:string;status:ReleaseStatus|null;unavailable?:boolean}){
 const current=!head||!status||status.blockers.includes('numeric_rules_missing')?0:1;
 const stages=[{label:'الإعداد',href:head?`/operator/statutory?head=${head}`:'/operator/statutory'},{label:'التفعيل للحساب',href:head?`/operator/statutory?head=${head}#statutory-issuance`:null}];
 return <section className="statutory-stages" aria-label="إعداد الحساب وتفعيله"><ol>{stages.map((stage,index)=><li key={stage.label} aria-current={!unavailable&&index===current?'step':undefined}><span aria-hidden="true">{index+1}</span>{stage.href?<Link href={stage.href}>{stage.label}</Link>:<span>{stage.label}</span>}{index===1&&status?.issued_pack&&<small>فعالة</small>}</li>)}</ol>{unavailable&&<p>تعذر قراءة حالة التفعيل؛ أعد المحاولة.</p>}{head&&<Link className="inline-action" href={`/operator/statutory/comparisons?head=${head}`}>مقارنات الحساب (اختيارية)</Link>}</section>;
}
