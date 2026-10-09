import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { displayDate } from './rules';
import { readOvertimeCursor, readOvertimeNotice } from './overtime-notice';
import styles from './payroll.module.css';

type Props = {
  tenantId: string; employer: string;
  period: { id: string; starts_on: string; ends_on: string };
  query: Record<string, string | undefined>;
};
export async function OvertimeNotice({ tenantId, employer, period, query }: Props) {
  const path = `/tenant/${tenantId}/payroll`;
  const context = { employer, period: period.id, ...(query.q ? { q: query.q } : {}), ...(query.review_q ? { review_q: query.review_q } : {}) };
  const firstPage = `${path}?${new URLSearchParams(context)}#payroll-overtime`;
  const failure = (denied = false) => <section id="payroll-overtime" className={styles.card} aria-labelledby="payroll-overtime-title">
    <h2 id="payroll-overtime-title">الإضافي غير المصنف</h2>
    <p>{denied ? 'عرض مصدر الإضافي يحتاج إلى صلاحية حضور إضافية. راجع مسؤول الشركة؛ لا يمكن تأكيد العدد لهذا الحساب.' : 'تعذر التحقق من الإضافي غير المصنف. لا يمكن تأكيد العدد الآن.'}</p>
    {!denied && <Link className="secondary-button" href={firstPage}>إعادة تحميل التنبيه من البداية</Link>}
    <p className="field-hint">يمكنك متابعة مراجعة الرواتب؛ هذا التنبيه لا يغير نتيجة الحساب أو صلاحيات الاعتماد.</p>
  </section>;
  const after = readOvertimeCursor(query, period);
  if (after === 'invalid') return failure();
  let result;
  try {
    const client = await createSupabaseServerClient();
    if (!client) return failure();
    result = await client.rpc('payroll_unclassified_overtime', {
      p_tenant: tenantId, p_employer: employer, p_period: period.id,
      p_after_date: after?.operational_date ?? null, p_after_employee_code: after?.employee_code ?? null,
      p_after_instance: after?.work_instance_id ?? null, p_limit: 20,
    });
  } catch { return failure(); }
  if (result.error) return failure(result.error.code === '42501' && result.error.message === 'payroll_overtime_view_forbidden');
  const data = readOvertimeNotice(result.data, period);
  if (!data) return failure();
  if (data.totals.instances === 0) return <section id="payroll-overtime" className={styles.card} aria-labelledby="payroll-overtime-title">
    <h2 id="payroll-overtime-title">مراجعة مصدر الإضافي</h2>
    <p>لا يوجد إضافي غير مصنف في سجلات الحضور المعتمدة لهذه الجهة والفترة.</p>
    <p className="field-hint">لا يشمل ذلك الحضور غير المعتمد، ولا يثبت جاهزية المسير.</p>
  </section>;
  const number = (value: number) => new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE).format(value);
  const next = data.next_cursor;
  return <section id="payroll-overtime" className={`${styles.card} ${styles.overtimeNotice}`} aria-labelledby="payroll-overtime-title">
    <h2 id="payroll-overtime-title">الإضافي غير المصنف · تنبيه غير مانع</h2>
    <p>{number(data.totals.minutes)} دقيقة غير مصنفة في {number(data.totals.instances)} سجل حضور معتمد لهذه الجهة والفترة.</p>
    <p>المصدر هو الحضور المعتمد فقط، وليس جميع سجلات الحضور. الدقائق غير المصنفة لا تدخل في مدخلات الرواتب.</p>
    {data.totals.reconciliation_required > 0 && <p>تغيّر سياق {number(data.totals.reconciliation_required)} سجل؛ راجع الحقائق والتصنيف الحالي قبل الاعتماد على المصدر.</p>}
    {data.items.length > 0 && <details><summary>سجلات تحتاج تصنيفًا · عرض {number(data.items.length)} سجل</summary><ul className={styles.issues}>
      {data.items.map(item => <li key={item.work_instance_id}><p><bdi>{item.employee_code}</bdi> · {displayDate(item.operational_date)} · {number(item.unclassified_minutes)} دقيقة{item.reconciliation_required ? ' · يحتاج مراجعة السياق' : ''}</p><Link className="secondary-button" href={`/tenant/${tenantId}/attendance/${item.work_instance_id}`}>فتح سجل الحضور والتصنيف</Link></li>)}
    </ul></details>}
    {data.totals.instances > 0 && data.items.length === 0 && <p>لم تعد هناك سجلات بعد موضع التصفح الحالي. ارجع إلى بداية التنبيه لمراجعة القائمة الحالية.</p>}
    <nav className={styles.reviewNavigation} aria-label="تصفح سجلات الإضافي غير المصنف">
      {next && <Link className="secondary-button" href={`${path}?${new URLSearchParams({ ...context, overtime_date: next.operational_date, overtime_code: next.employee_code, overtime_instance: next.work_instance_id })}#payroll-overtime`}>سجلات إضافية</Link>}
      {after && <Link className="secondary-button" href={firstPage}>بداية القائمة</Link>}
    </nav>
    <p className="field-hint">بعد مراجعة السجل، ارجع إلى هذه الصفحة بزر الرجوع. قد يلزم إعادة حساب الرواتب بعد التصنيف؛ التنبيه لا يثبت جاهزية المسير.</p>
  </section>;
}
