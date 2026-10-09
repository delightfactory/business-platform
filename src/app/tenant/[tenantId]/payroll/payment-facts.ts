import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import { uuid } from './rules';

type Period = { id: string; starts_on: string; ends_on: string };
export type PaymentFacts = {
  output_id: string; period: Period; revision: number; employee_count: number; remaining_count: number;
  status: 'unpaid' | 'partially_paid' | 'paid'; ever_paid: boolean;
  payable_sign: 'positive' | 'zero' | 'negative'; superseded: boolean;
};
const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const count = (value: unknown): value is number => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
export function readPaymentFacts(value: unknown, output: string, period: Period): PaymentFacts | null {
  if (!object(value) || value.contract_version !== 1 || value.output_id !== output || !uuid(output) || !object(value.period)
    || value.period.id !== period.id || value.period.starts_on !== period.starts_on || value.period.ends_on !== period.ends_on
    || !count(value.revision) || !count(value.employee_count) || !count(value.remaining_count) || value.remaining_count > value.employee_count
    || typeof value.ever_paid !== 'boolean' || typeof value.superseded !== 'boolean') return null;
  const status = value.status, sign = value.payable_sign;
  if (status !== 'unpaid' && status !== 'partially_paid' && status !== 'paid') return null;
  if (sign !== 'positive' && sign !== 'zero' && sign !== 'negative') return null;
  if (status === 'paid' && value.remaining_count !== 0 || status === 'partially_paid' && value.remaining_count === 0) return null;
  return {
    output_id: output, period, revision: value.revision, employee_count: value.employee_count, remaining_count: value.remaining_count,
    status, ever_paid: value.ever_paid, payable_sign: sign, superseded: value.superseded,
  };
}
export function recordedPaymentDescription(facts: PaymentFacts): string {
  if (facts.employee_count === 0) return 'لا توجد علاقات توظيف في هذا المسير النهائي.';
  if (facts.payable_sign === 'negative') return 'قيمة الالتزام تحتاج مراجعة في سجل الدفعات؛ لا يمكن تأكيد اكتمال الصرف.';
  if (facts.payable_sign === 'zero') return 'لا يوجد مبلغ مستحق للصرف في هذا المسير النهائي.';
  if (facts.status === 'paid') return 'سُجل سداد كامل للمستحقات في هذا المسير النهائي.';
  if (facts.status === 'partially_paid') return `سُجل سداد جزئي؛ علاقات توظيف بها متبقٍ: \u2068${new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE).format(facts.remaining_count)}\u2069.`;
  return facts.ever_paid ? 'لا يوجد سداد قائم بعد تصحيح القيود السابقة؛ راجع سجل الدفعات.' : 'لم يُسجّل سداد للمستحقات في هذا المسير النهائي بعد.';
}
