import { Disclosure, HelpNote } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import {displayDate} from '../rules';
import {TimeCoverageExplanation,type TimeCoverageSummary,type TimeCoverageDay} from './TimeCoverageExplanation';

export type SourceSummary = {
  status:string;selected_source?:string;approved_units?:number|null;coverage?:string;operational_complete?:boolean;
  day_count?:number;absence_units?:number|null;worked_minutes?:number|null;paid_leave_units?:number|null;unpaid_leave_units?:number|null;
  time_coverage?:TimeCoverageSummary;
};
export type SourceDay = {
  date:string;status:string;work_units:number|null;paid_leave_units:number|null;unpaid_leave_units:number|null;
};
const sources:Record<string,string>={monthly_approved_sources:'الحضور والإجازات',manual:'إجمالي يدوي معتمد',legacy_manual:'أيام يدوية محفوظة سابقًا',time:'الحضور المعتمد'};
const quantities=new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE,{maximumFractionDigits:2});
const quantity=(value:number|null|undefined)=>value==null?'غير محدد':quantities.format(value);

export function SourceExplanation({summary,days,coverageDays}:{summary?:SourceSummary;days?:SourceDay[];coverageDays?:TimeCoverageDay[]}) {
  if(!summary||summary.status==='disabled'&&!summary.selected_source)return null;
  const monthly=summary.selected_source==='monthly_approved_sources';
  const complete=summary.coverage==='operational_complete'&&summary.operational_complete===true;
  return <section aria-label="مصادر الأيام"><h4>الأيام المحتسبة</h4>
    <p>{sources[summary.selected_source??'']??'الحضور والإجازات'} · {summary.status==='needs_source_review'?'تحتاج مراجعة':complete?'الأيام مكتملة':'البيانات المتاحة للمراجعة'}</p>
    {summary.selected_source&&!monthly&&<p>الأيام المستحقة من المصدر المختار: {quantity(summary.approved_units)}</p>}
    {monthly&&<p>الغياب غير المدفوع: {quantity(summary.absence_units??0)} · الإجازة غير المدفوعة: {quantity(summary.unpaid_leave_units??0)}</p>}
    {monthly&&summary.status==='reconciliation_ready'&&<HelpNote label="كيف حُسب الأجر الشهري؟"><p>يُوزّع الأجر الساري على تواريخ الفترة، ثم يُخصم الجزء غير المدفوع المعتمد مرة واحدة. تُحسب البنود الثابتة بالطريقة المعتمدة لكل بند.</p></HelpNote>}
    {summary.coverage==='captured_parts_only'&&<p>{summary.time_coverage?.enabled?'السجلات المعتمدة متاحة. أكمل مراجعة الأيام الناقصة قبل الاعتماد.':'تظهر الأيام المسجلة بالفعل. لم تكتمل مراجعة كل أيام الفترة بعد.'}</p>}
    {complete&&!monthly&&<><HelpNote label="كيف حُسب الأجر من الأيام؟"><p>يُحسب الأجر من أيام العمل والإجازات المدفوعة المعتمدة، بالأجر الساري لكل يوم. تُحسب الإجازة المدفوعة مرة واحدة.</p></HelpNote><p>بعد مراجعة الأيام، راجع الرواتب وأكمل اعتماد المسير.</p></>}
    {summary.coverage==='approved_manual_total'&&<p>الإجمالي اليدوي يشمل الإجازة المدفوعة؛ لا تُضاف إليه أيام الحضور أو الإجازة مرة أخرى.</p>}
    <TimeCoverageExplanation summary={summary.time_coverage} days={coverageDays}/>
    {days&&days.length>0&&<Disclosure summary={<>شرح الأيام المتاحة ({quantity(days.length)})</>}><ul>{days.map(day=><li key={day.date}>
      {displayDate(day.date)} · عمل {quantity(day.work_units)} · إجازة مدفوعة {quantity(day.paid_leave_units)} · إجازة غير مدفوعة {quantity(day.unpaid_leave_units)}
      {day.status==='needs_source_review'?' · يلزم مراجعة المصدر':''}
    </li>)}</ul></Disclosure>}
  </section>;
}
