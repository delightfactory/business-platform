import { RecordCard, Badge, Disclosure } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import { record, safeSourceUrl, type ComparisonRow } from '../dto';
import { outputs, scenarios } from './labels';

const labourScenarios: Record<string, string> = {
  ordinary_limit: 'مقارنة الحد العام', alimony_limit: 'مقارنة حد النفقة', priority: 'مقارنة ترتيب الاستقطاعات',
  loan_basis: 'مقارنة أساس السلفة', zero_capacity: 'مقارنة انعدام المبلغ المتاح', cent_boundary: 'مقارنة حدود القرش',
};
const labourOutputs: Record<string, string> = {
  wage_basis: 'أساس المقارنة', ceiling: 'الحد المحسوب', capacity_amount: 'المبلغ المخصص', unapplied_amount: 'المبلغ غير المخصص',
};
const displayValue = (value: unknown): value is string | number => typeof value === 'string' ||
  (typeof value === 'number' && Number.isFinite(value));
const values = (data: unknown, keys: string[]): data is Record<string, string | number> =>
  record(data) && keys.every(key => displayValue(data[key]));
const text = (value: unknown): value is string => typeof value === 'string';

export function ComparisonHistoryRow({ row, currentRevision }: { row: ComparisonRow; currentRevision: number }) {
  const c = row.case_data, r = row.result;
  const common = record(c) && record(r) && text(c.name) && text(c.scenario) && text(c.reference) &&
    text(c.source_url) && (c.origin === 'official' || c.origin === 'synthetic') && typeof r.matched === 'boolean';
  if (!common) return <RecordCard className="member-card"><h3>حالة مقارنة محفوظة</h3><p role="alert">تعذر عرض بيانات هذه الحالة. أعد قراءة السجل؛ لم تُحذف الحالة.</p></RecordCard>;
  const labour = c.domain === 'labour_deductions';
  const tax = (c.domain === undefined || c.domain === 'tax_insurance') && record(c.tax) &&
    ['net', 'duration', 'prior_due', 'from', 'until'].every(key => text(c.tax && record(c.tax) ? c.tax[key] : undefined)) &&
    Array.isArray(c.insurance) && c.insurance.every(m => record(m) && ['month', 'wage', 'reference'].every(key => text(m[key]))) &&
    record(r.tax) && displayValue(r.tax.annual_base);
  const labels = labour ? labourOutputs : outputs;
  const readable = (labour || tax) && values(r.actual, Object.keys(labels)) && values(r.expected, Object.keys(labels));
  return <RecordCard className="member-card"><h3>{String(c.name)}</h3>
    <Badge as="p" className=" is-inactive">{r.matched ? 'الأرقام متطابقة' : 'يوجد اختلاف'} · {row.revision === currentRevision ? 'نسخة القواعد الحالية' : 'نسخة سابقة من القواعد'}</Badge>
    <p>{(labour ? labourScenarios : scenarios)[String(c.scenario)] ?? 'حالة مقارنة محفوظة'} · {c.origin === 'synthetic' ? 'حالة اصطناعية للاختبار فقط' : 'أرقام مسجلة من المصدر الرسمي'} · المقارنة وحدها لا تؤهل القواعد</p>
    <p>حُفظت في {new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo', dateStyle: 'medium' }).format(new Date(row.created_at))}</p>
    {safeSourceUrl(String(c.source_url)) ? <a href={String(c.source_url)} target="_blank" rel="noopener noreferrer">مرجع النتيجة: {String(c.reference)}</a> : <p>مرجع النتيجة: {String(c.reference)}؛ رابط المرجع غير متاح.</p>}
    {readable ? <Disclosure summary={<>الأرقام والمدخلات</>}>
      {Object.entries(labels).map(([key, label]) => <p key={key}>{label}: المتوقع {String(record(r.expected) ? r.expected[key] : '')} ج.م. · المحسوب {String(record(r.actual) ? r.actual[key] : '')} ج.م.</p>)}
      {tax && record(c.tax) && record(r.tax) && <><p>صافي الدخل التراكمي قبل الإعفاء: {String(c.tax.net)} ج.م. · المدة: {String(c.tax.duration)} يومًا · الضريبة السابقة: {String(c.tax.prior_due)} ج.م.</p>
        <p>فترة الدخل: {String(c.tax.from)} إلى {String(c.tax.until)} · أساس الضريبة السنوي بعد التقريب: {String(r.tax.annual_base)} ج.م.</p>
        <ul>{Array.isArray(c.insurance) && c.insurance.map((month, index) => record(month) && <li key={index}>شهر {String(month.month).slice(0, 7)} · أجر اشتراك {String(month.wage)} ج.م. · مرجعه: {String(month.reference)}</li>)}</ul></>}
      {labour && <LabourDetails context={c.context} actual={r.actual} expected={r.expected} year={c.year} />}
    </Disclosure> : <p role="alert">تعذر عرض أرقام هذه الحالة. أعد قراءة السجل؛ لا تُعتبر البيانات غير المتاحة أرقامًا صفرية.</p>}
  </RecordCard>;
}

function LabourDetails({ context, actual, expected, year }: { context: unknown; actual: unknown; expected: unknown; year: unknown }) {
  const contextLabels: Record<string, string> = { gross: 'الإجمالي', tax: 'الضريبة', employee_insurance: 'تأمين الموظف', employer_loan: 'سلفة جهة العمل' };
  if (!values(context, Object.keys(contextLabels)) || !record(actual) || !record(expected)) return <p role="alert">تعذر عرض مدخلات مقارنة الاستقطاعات.</p>;
  const claims = actual.claims;
  const expectedClaims = expected.claims;
  const claimsReadable = Array.isArray(claims) && claims.every(claim => record(claim) && text(claim.id) && text(claim.reference) && values(claim, ['amount', 'capacity_amount', 'unapplied_amount']));
  const expectedReadable = expectedClaims === undefined || (Array.isArray(expectedClaims) && expectedClaims.every(claim => record(claim) && text(claim.id) && values(claim, ['capacity_amount', 'unapplied_amount'])));
  return <><p>سنة المقارنة: {text(year) ? year : 'تعذر عرض السنة'}</p>
    {Object.entries(contextLabels).map(([key, label]) => <p key={key}>{label}: {context[key]} ج.م.</p>)}
    {claimsReadable && expectedReadable ? <ul>{claims.map((claim, index) => {
      const e = Array.isArray(expectedClaims) ? expectedClaims.find(item => record(item) && item.id === claim.id) : undefined;
      return <li key={index}>البند {index + 1} · المرجع: {claim.reference} · المبلغ: {claim.amount} ج.م. · المخصص: {claim.capacity_amount} ج.م. · غير المخصص: {claim.unapplied_amount} ج.م.
        {record(e) && <> · المبلغ المتوقع تطبيقه: {String(e.capacity_amount)} ج.م. · المبلغ المتوقع عدم تطبيقه: {String(e.unapplied_amount)} ج.م.</>}</li>;
    })}</ul> : <p role="alert">تعذر عرض تفاصيل بنود هذه الحالة.</p>}
    <p className="field-hint">هذه أرقام مقارنة محفوظة فقط؛ ليست اعتمادًا للصرف أو إثباتًا لتسجيل المبالغ في مسير نهائي.</p>
  </>;
}
