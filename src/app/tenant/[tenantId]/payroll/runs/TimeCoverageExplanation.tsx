import { Disclosure } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import {displayDate} from '../rules';

export type TimeCoverageSummary = {
  enabled:boolean;status:string;expected_days:number;approved_days:number;
  missing_days:number;pending_days:number;future_days:number;other_review_days:number;
};
export type TimeCoverageDay = {date:string;state:string;expected:boolean|null;elapsed:boolean|null};

const formatter=new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE);
const count=(value:number)=>Number.isInteger(value)&&value>=0?formatter.format(value):'غير محدد';
const dayStates:Record<string,string>={
  scheduled_nonworkday:'غير مطلوب للعمل بحسب سياسة الدوام',
  approved_fact_current:'سجل معتمد ومتوافق مع بيانات اليوم',
  expected_instance_missing:'يوم عمل مطلوب لم يُجهّز سجله؛ المسؤول: الحضور',
  instance_open_or_pending:'سجل لم يُعتمد بعد؛ المسؤول: معتمد الحضور',
  approved_fact_not_current:'اعتماد سابق يحتاج مراجعة أحدث بيانات اليوم',
  classification_reconciliation_required:'يلزم توافق الحضور والإجازات؛ المسؤول: مراجعة الحضور',
  schedule_context_missing_or_ambiguous:'بيانات عمل أو سياسة دوام غير محسومة؛ المسؤول: شؤون العاملين',
  schedule_context_mismatch:'بيانات العمل لا تتوافق مع جهة العمل؛ المسؤول: شؤون العاملين',
  policy_context_mismatch:'سجل اليوم لا يتوافق مع سياسة الدوام السارية؛ المسؤول: الحضور وشؤون العاملين',
  schedule_context_missing:'سياسة الدوام تحتاج مراجعة؛ المسؤول: مدير الدوام',
  schedule_window_ambiguous:'توقيت الدوام يحتاج مراجعة؛ المسؤول: مدير الدوام',
  off_schedule_materialized:'يوجد سجل ليوم غير مطلوب وفق السياسة؛ المسؤول: مراجعة الحضور',
  instance_ambiguous:'سجلات اليوم تحتاج مراجعة؛ المسؤول: مدير الحضور',
  not_yet_elapsed:'لم ينتهِ وقت تسجيل حضور اليوم عند إعداد هذا الحساب المبدئي',
};

export function TimeCoverageExplanation({summary,days}:{summary?:TimeCoverageSummary;days?:TimeCoverageDay[]}) {
  if(!summary||!summary.enabled)return null;
  const complete=summary.status==='observationally_complete';
  return <section aria-label="اكتمال سجلات الحضور"><h5>اكتمال سجلات الحضور</h5>
    <p>{complete?'سجلات الحضور المطلوبة مكتملة في هذه المراجعة.':'بعض أيام الحضور تحتاج استكمالًا أو مراجعة.'}</p>
    <p>الأيام المطلوبة بحسب الدوام: {count(summary.expected_days)} · سجلات معتمدة ومتوافقة: {count(summary.approved_days)}</p>
    {!complete&&<ul>
      {summary.missing_days>0&&<li>أيام ينقصها سجل حضور: {count(summary.missing_days)}</li>}
      {summary.pending_days>0&&<li>أيام تنتظر اعتماد الحضور أو مراجعة الإجازة: {count(summary.pending_days)}</li>}
      {summary.future_days>0&&<li>أيام لم ينتهِ وقت تسجيلها عند الحساب: {count(summary.future_days)}</li>}
      {summary.other_review_days>0&&<li>أيام تحتاج مراجعة بيانات العمل أو الدوام: {count(summary.other_review_days)}</li>}
    </ul>}
    <p>اليوم الناقص أو المعلّق لا يُعتبر غيابًا أو صفر استحقاق. اكتمال السجلات وحده لا يتيح الاعتماد المالي.</p>
    {!complete&&<p>راجع الأيام الناقصة مع المسؤول الموضّح في التفاصيل، ثم أعد حساب مراجعة الراتب.</p>}
    {days&&days.length>0&&<Disclosure summary={<>أيام الفترة وحالة سجلاتها ({count(days.length)})</>}><ul>{days.map(day=><li key={day.date}>
      {displayDate(day.date)} · {dayStates[day.state]??'يلزم مراجعة حالة اليوم مع مسؤول الحضور'}
    </li>)}</ul></Disclosure>}
  </section>;
}
