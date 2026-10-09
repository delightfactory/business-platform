import { ButtonLink, Panel } from '@/components/ui';
import type { ReactNode } from 'react';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { readPaymentFacts, recordedPaymentDescription } from './payment-facts';
import styles from './payroll.module.css';

type Props = {
  tenantId: string; employer: string; output: string;
  period: { id: string; starts_on: string; ends_on: string };
  query: Record<string, string | undefined>;
};
export async function RecordedPaymentNotice({ tenantId, employer, output, period, query }: Props) {
  const context = { employer, period: period.id, ...(query.q ? { q: query.q } : {}), ...(query.review_q ? { review_q: query.review_q } : {}) };
  const retry = `/tenant/${tenantId}/payroll?${new URLSearchParams(context)}#payroll-recorded-payment`;
  const panel = (content: ReactNode) => <Panel id="payroll-recorded-payment" className={styles.card} aria-labelledby="payroll-recorded-payment-title">
    <h2 id="payroll-recorded-payment-title">حالة الصرف المسجل</h2>{content}
    <p className="field-hint">هذه قيود دفعات خارجية مسجلة في المنصة؛ لا تثبت تنفيذ تحويل بنكي أو إتاحة مفردات المرتب.</p>
  </Panel>;
  const failure = (denied = false) => panel(<>
    <p>{denied ? 'هذا الحساب ليس لديه صلاحية لعرض الدفعات لهذا المسير. راجع مسؤول الشركة؛ حالة الصرف غير مؤكدة هنا.' : 'تعذر التحقق من الدفعات المسجلة؛ حالة الصرف غير مؤكدة هنا.'}</p>
    {!denied && <ButtonLink variant="ghost"  prefetch={false} href={retry}>إعادة التحقق من حالة الصرف</ButtonLink>}
  </>);
  let result;
  try {
    const client = await createSupabaseServerClient();
    if (!client) return failure();
    result = await client.rpc('payroll_payment_facts', { p_tenant: tenantId, p_employer: employer, p_output: output });
  } catch { return failure(); }
  if (result.error) return failure(result.error.code === '42501' && result.error.message === 'payroll_forbidden');
  const facts = readPaymentFacts(result.data, output, period);
  if (!facts) return failure();
  return panel(<>{facts.superseded && <p>استُبدل هذا المسير، وبقي محفوظًا في السجل. حالة الصرف أدناه تخص دفعاته فقط.</p>}<p>{recordedPaymentDescription(facts)}</p></>);
}
