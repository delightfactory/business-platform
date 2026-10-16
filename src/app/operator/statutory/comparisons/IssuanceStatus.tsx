import { Panel } from '@/components/ui';
import {IssuanceForm} from './IssuanceForm';
export type ReleaseStatus={revision:number;evidence_stamp:string;ready:boolean;blockers:string[];missing_coverage:{year:number;scenario:string}[];total:number;official:number;issued_pack:string|null;qualification_scope:'tax_insurance';financially_qualified:false;review_policy?:'optional_company_review_v1'|'legacy_issued_review'};
const explanations:Record<string,string>={numeric_rules_missing:'أدخل إعدادات الحساب الرقمية أولًا.',qualified_scope_overlap:'توجد إعدادات فعالة تتداخل في الفترة والمعاملة أو فئة التأمين. راجع نطاق التطبيق لتجنب اختيار حسابين متعارضين.'};
export function IssuanceStatus({status,head,actor}:{status:ReleaseStatus;head:string;actor:string}){
 return <Panel id="statutory-issuance"><h2>تفعيل إعدادات حساب الرواتب</h2>
  {status.issued_pack?<p role="status">هذه النسخة فعالة للحساب. {status.review_policy==='optional_company_review_v1'?'يمكنك إضافة مقارنات اختيارية دون تعطيلها.':'سجل مقارنات الإصدار القديم محفوظ للقراءة. أنشئ نسخة جديدة لإضافة مقارنات اختيارية.'}</p>:status.ready?<IssuanceForm head={head} revision={status.revision} actor={actor} stamp={status.evidence_stamp}/>:<><p>استكمل إعداد الحساب:</p><ul>{status.blockers.map(code=><li key={code}>{explanations[code]??'راجع إعداد الحساب المختار.'}</li>)}</ul></>}
 </Panel>;
}
