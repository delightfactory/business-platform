import { Disclosure } from '@/components/ui';
import { Panel } from '@/components/ui';
import {scenarios} from './labels';
import {IssuanceForm} from './IssuanceForm';
export type ReleaseStatus={revision:number;evidence_stamp:string;ready:boolean;blockers:string[];missing_coverage:{year:number;scenario:string}[];total:number;official:number;issued_pack:string|null;qualification_scope:'tax_insurance';financially_qualified:false};
const explanations:Record<string,string>={numeric_rules_missing:'لم تُدخل القواعد الرقمية لهذه النسخة.',review_end_missing:'حدد نهاية الفترة التي تغطيها المراجعة؛ النتائج المتاحة لا تؤهل سنوات مستقبلية مفتوحة.',official_result_unresolved:'توجد نتيجة رسمية غير مطابقة أو مرجع خارج المصادر الرسمية للضريبة والتأمين. صحح الحالة بنفس اسمها وسيناريوها وسنتها مع الاحتفاظ بتاريخها.',official_coverage_missing:'لم تكتمل النتائج الرسمية الممثلة لكل سنة تغطيها القواعد.',qualified_scope_overlap:'توجد قواعد مؤهلة متداخلة: تعريف مكرر للفئة والمعاملة نفسيهما، أو اختلاف في قواعد المعاملة الضريبية أو فئة التأمين. راجع النطاق والفترة؛ السجل الصادر لا يُعدل هنا.'};
export function IssuanceStatus({status,head,actor}:{status:ReleaseStatus;head:string;actor:string}){
 return <Panel ><h2>مراجعة صلاحية قواعد الضريبة والتأمينات</h2>
  {status.issued_pack?<p role="status">صدرت هذه النسخة مع أدلتها الثابتة للضريبة والتأمين فقط. لا يمكن إضافة مقارنات إليها؛ المراجعة الجديدة تبدأ من نسخة جديدة.</p>:<><p>المقارنات المحفوظة: {status.total} · المسجلة كمصدر رسمي: {status.official}. الحالات الاصطناعية لا تُحتسب لإثبات صحة الحساب، واسم السيناريو لا يغني عن مراجعة مصدره وانطباقه.</p>
  {status.ready?<IssuanceForm head={head} revision={status.revision} actor={actor} stamp={status.evidence_stamp}/>:<><p>الإصدار غير متاح حتى معالجة النواقص التالية بواسطة مراجع القواعد:</p><ul>{status.blockers.map(code=><li key={code}>{explanations[code]??'تحتاج أدلة الإصدار إلى مراجعة.'}</li>)}</ul>{status.missing_coverage.length>0&&<Disclosure summary={<>حالات المقارنة الرسمية المطلوبة</>}><ul>{status.missing_coverage.map(item=><li key={item.year+item.scenario}>{item.year} · {scenarios[item.scenario]??'حالة مقارنة تحتاج مراجعة مرجعها'}</li>)}</ul></Disclosure>}</>}</>}
  <p className="field-hint">استكمال شروط حساب المسير المالي يتطلب أيضًا قواعد العمل وحدود الخصم وربط المصادر. إصدار الضريبة والتأمين لا يفتح الاعتماد أو التثبيت المالي وحده.</p>
 </Panel>;
}
