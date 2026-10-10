import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
type Partition = Record<string, number>;
export type StageFacts = {
  employee_count: number; source: Partition; coverage: Partition; time_coverage: Partition;
  time_enabled: Partition; leave_enabled: Partition;
  issues: { blocking_true: number; blocking_false: number; blocking_unknown: number } | null;
  gross_complete: boolean | null; financially_qualified: boolean | null;
};
export type StageWork = {
  run: { status: string } | null; final_output_id: string | null; stale_reasons: string[];
  stage_facts?: unknown; approval?: { ready?: unknown } | null;
};
const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const count = (value: unknown): value is number => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
const optionalBoolean = (value: unknown): value is boolean | null => value === true || value === false || value === null;
function partition(value: unknown, keys: string[], total: number): Partition | null {
  if (!object(value)) return null;
  const result: Partition = {};
  for (const key of keys) { if (!count(value[key])) return null; result[key] = value[key]; }
  return Object.values(result).reduce((sum, value) => sum + value, 0) === total ? result : null;
}
export function readStageFacts(value: unknown): StageFacts | null {
  if (!object(value) || value.contract_version !== 1 || !count(value.employee_count) || !optionalBoolean(value.gross_complete) || !optionalBoolean(value.financially_qualified)) return null;
  const source = partition(value.source, ['reconciliation_ready', 'needs_source_review', 'disabled', 'unknown'], value.employee_count);
  const coverage = partition(value.coverage, ['operational_complete', 'approved_manual_total', 'captured_parts_only', 'approved_leave_sources', 'unknown'], value.employee_count);
  const time_coverage = partition(value.time_coverage, ['observationally_complete', 'needs_source_review', 'disabled', 'unavailable', 'unknown'], value.employee_count);
  const time_enabled = partition(value.time_enabled, ['true', 'false', 'unknown'], value.employee_count);
  const leave_enabled = partition(value.leave_enabled, ['true', 'false', 'unknown'], value.employee_count);
  if (!source || !coverage || !time_coverage || !time_enabled || !leave_enabled) return null;
  let issues: StageFacts['issues'] = null;
  if (value.issues !== null) {
    if (!object(value.issues) || !count(value.issues.blocking_true) || !count(value.issues.blocking_false) || !count(value.issues.blocking_unknown)) return null;
    issues = { blocking_true: value.issues.blocking_true, blocking_false: value.issues.blocking_false, blocking_unknown: value.issues.blocking_unknown };
  }
  return { employee_count: value.employee_count, source, coverage, time_coverage, time_enabled, leave_enabled, issues, gross_complete: value.gross_complete, financially_qualified: value.financially_qualified };
}
export function payrollStageDescriptions(work: StageWork | null): string[] {
  if (!work) return ['حدد الفترة أو راجع إعداد الدورة', 'لم تُحدد فترة للمراجعة', 'لم تُحدد فترة للمراجعة', 'لم يُعرض حساب', 'لم يُعرض اعتماد', 'لم يُعرض مسير نهائي'];
  const descriptions = ['فترة محفوظة', 'تظهر حالة المصدر بعد الحساب', 'تظهر الموانع بعد الحساب', 'لم يُجرَ حساب مبدئي لهذه الفترة', 'لم يُعتمد حساب مبدئي لهذه الفترة', 'لم يُثبّت مسير نهائي بعد'];
  if (!work.run || work.run.status === 'cancelled') return descriptions;
  if (work.run.status === 'superseded') return ['فترة محفوظة', 'مصادر تاريخية', 'حساب تاريخي', 'حساب مستبدل', 'مسير مستبدل محفوظ', 'راجع المسير البديل'];
  if (work.run.status === 'locked') return ['فترة محفوظة', 'مصادر المسير المحفوظ', 'موانع الحساب في سجله التاريخي', 'حساب نهائي محفوظ', 'مسير مثبت', work.final_output_id ? 'حالة الصرف المسجل معروضة أدناه حسب الصلاحية' : 'المسير النهائي غير متاح؛ راجع المسير'];
  if (!['draft', 'review', 'approved'].includes(work.run.status)) return ['فترة محفوظة', 'حالة المصدر غير معروفة', 'حالة الموانع غير معروفة', 'حالة الحساب تحتاج مراجعة', 'حالة الاعتماد غير معروفة', 'لم يُؤكد مسير نهائي'];
  if (work.stale_reasons.length > 0) return ['فترة محفوظة', 'أعد الحساب لتحديث حالة المصدر', 'أعد الحساب لتحديث الموانع', 'تغيّرت المصادر؛ يلزم إعادة الحساب', work.run.status === 'approved' ? 'الاعتماد السابق يحتاج مراجعة' : 'راجع الحساب قبل الاعتماد', 'لم يُثبّت مسير نهائي بعد'];
  const facts = readStageFacts(work.stage_facts);
  descriptions[1] = 'تعذر تحديد تغطية المصدر من البيانات المتاحة';
  descriptions[2] = 'تعذر تحديد موانع الحساب المحفوظ';
  descriptions[3] = 'حساب محفوظ للمراجعة؛ لم تتأكد سلامة الحساب المالي';
  if (facts) {
    const n = (value: number) => new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE).format(value);
    const manual = facts.coverage.approved_manual_total > 0 ? ` · مدخل يدوي معتمد: ${n(facts.coverage.approved_manual_total)}` : '';
    if (facts.employee_count === 0) descriptions[1] = 'لا توجد علاقات توظيف في نطاق الحساب المحفوظ';
    else if (facts.time_enabled.false === facts.employee_count && facts.leave_enabled.false === facts.employee_count) descriptions[1] = `الحضور والإجازات غير مفعلين${manual}`;
    else if (facts.source.needs_source_review > 0 || facts.time_coverage.needs_source_review > 0) descriptions[1] = `مصادر تحتاج مراجعة${manual}`;
    else if (facts.source.unknown > 0 || facts.coverage.unknown > 0 || facts.time_coverage.unknown > 0 || facts.time_coverage.unavailable > 0 || facts.time_enabled.unknown > 0 || facts.leave_enabled.unknown > 0) descriptions[1] = `حالة بعض المصادر غير معروفة${manual}`;
    else {
      const observed = [`تغطية تشغيلية موثقة: ${n(facts.coverage.operational_complete)} من ${n(facts.employee_count)}`];
      if (facts.coverage.captured_parts_only > 0) observed.push(`أجزاء حضور فقط: ${n(facts.coverage.captured_parts_only)}`);
      if (facts.coverage.approved_leave_sources > 0) observed.push(`مصادر إجازة معتمدة: ${n(facts.coverage.approved_leave_sources)}`);
      descriptions[1] = observed.join(' · ') + manual;
    }
    if (facts.issues) descriptions[2] = facts.issues.blocking_true > 0 ? `${n(facts.issues.blocking_true)} مانع في الحساب المحفوظ` : facts.issues.blocking_unknown > 0 ? 'توجد مراجعات لم يُحدد أثرها المانع' : facts.issues.blocking_false > 0 ? `تنبيهات فقط: ${n(facts.issues.blocking_false)}` : 'لا موانع في الحساب المحفوظ';
    if (facts.financially_qualified === true) descriptions[3] = work.run.status === 'approved' ? 'حساب محفوظ يستوفي الشروط المالية؛ حالة الاعتماد والحفظ النهائي منفصلة' : 'حساب محفوظ يستوفي الشروط المالية؛ المراجعة والاعتماد مطلوبان';
    else if (facts.financially_qualified === false) descriptions[3] = 'حساب محفوظ؛ شروط الحساب المالي غير مكتملة';
  }
  const ready = work.approval?.ready;
  descriptions[4] = work.run.status === 'approved'
    ? ready === true ? 'حساب مبدئي معتمد؛ الحفظ النهائي يتطلب التأكيد والصلاحية' : ready === false ? 'تغيّرت جاهزية الحساب المبدئي المعتمد؛ راجع المسير' : 'حساب مبدئي معتمد؛ جاهزية الحفظ النهائي غير معروفة'
    : ready === true ? 'فحص الخادم يسمح بالاعتماد حسب الصلاحية' : ready === false ? 'متطلبات الاعتماد غير مكتملة؛ راجع المسير' : 'حالة جاهزية الاعتماد غير معروفة؛ راجع المسير';
  return descriptions;
}
