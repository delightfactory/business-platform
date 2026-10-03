import {displayDate} from '../rules';
import {TimeCoverageExplanation,type TimeCoverageSummary,type TimeCoverageDay} from './TimeCoverageExplanation';

export type SourceSummary = {
  status:string;selected_source?:string;approved_units?:number|null;coverage?:string;operational_complete?:boolean;
  day_count?:number;worked_minutes?:number|null;paid_leave_units?:number|null;unpaid_leave_units?:number|null;
  time_coverage?:TimeCoverageSummary;
};
export type SourceDay = {
  date:string;status:string;work_units:number|null;paid_leave_units:number|null;unpaid_leave_units:number|null;
};
const sources:Record<string,string>={manual:'إجمالي يدوي معتمد',legacy_manual:'أيام يدوية محفوظة سابقًا',time:'الحضور المعتمد'};
const quantities=new Intl.NumberFormat('ar-EG',{maximumFractionDigits:2});
const quantity=(value:number|null|undefined)=>value==null?'غير محدد':quantities.format(value);

export function SourceExplanation({summary,days,coverageDays}:{summary?:SourceSummary;days?:SourceDay[];coverageDays?:TimeCoverageDay[]}) {
  if(!summary||summary.status==='disabled'&&!summary.selected_source)return null;
  const complete=summary.coverage==='operational_complete'&&summary.operational_complete===true;
  return <section aria-label="مصادر الأيام"><h4>مصدر الأيام</h4>
    <p>{sources[summary.selected_source??'']??'مصادر الحضور والإجازات للمراجعة'} · {summary.status==='needs_source_review'?'يلزم مراجعة المصادر':complete?'أيام المصدر مكتملة للحساب':'مصادر محفوظة للمراجعة'}</p>
    {summary.selected_source&&<p>الأيام المستحقة من المصدر المختار: {quantity(summary.approved_units)}</p>}
    {summary.coverage==='captured_parts_only'&&<p>{summary.time_coverage?.enabled?'السجلات المعتمدة متاحة للمراجعة؛ احتساب الأيام والمبالغ المستحقة من الحضور والإجازات لم يُؤهّل بعد.':'تشرح هذه القيم وقائع الحضور المعتمدة المتاحة؛ تغطية أيام العمل المتوقعة لم تُؤهّل بعد.'}</p>}
    {complete&&<p>حُسب الأجر الأساسي من أيام العمل والإجازات المدفوعة المعتمدة، حسب الأجر الساري لكل يوم. الإجازة المدفوعة تُحسب مرة واحدة. ما زالت المراجعة المالية والقانونية مطلوبة قبل اعتماد الراتب أو صرفه.</p>}
    {summary.coverage==='approved_manual_total'&&<p>الإجمالي اليدوي يشمل الإجازة المدفوعة؛ لا تُضاف إليه أيام الحضور أو الإجازة مرة أخرى.</p>}
    <TimeCoverageExplanation summary={summary.time_coverage} days={coverageDays}/>
    {days&&days.length>0&&<details><summary>شرح الأيام المتاحة ({quantity(days.length)})</summary><ul>{days.map(day=><li key={day.date}>
      {displayDate(day.date)} · عمل {quantity(day.work_units)} · إجازة مدفوعة {quantity(day.paid_leave_units)} · إجازة غير مدفوعة {quantity(day.unpaid_leave_units)}
      {day.status==='needs_source_review'?' · يلزم مراجعة المصدر':''}
    </li>)}</ul></details>}
  </section>;
}
