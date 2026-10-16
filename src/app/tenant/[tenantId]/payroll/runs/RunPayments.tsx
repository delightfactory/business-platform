import Link from 'next/link';
import { Button, ButtonLink, Disclosure, Input, Message } from '@/components/ui';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { PaymentForm } from '../payments/PaymentForm';
import { type PaymentEmployee, paymentError } from '../payments/rules';
import { displayDate, uuid } from '../rules';
import { money } from './rules';
import styles from '../payroll.module.css';

type History = { id: string; kind: string; paid_on: string; reference: string; reason: string; amount: string; compensated: boolean };
type PaymentWorkspace = { access: { can_record: boolean; can_correct_record: boolean }; today: string; revision: number; superseded: boolean; summary: { paid: string; remaining: string; payable: string; remaining_count: number }; employees: PaymentEmployee[]; history: History[] };

export async function RunPayments({ tenant, employer, period, output, actor, query }: { tenant: string; employer: string; period: string; output: string; actor: string; query: Record<string, string | undefined> }) {
 const client = await getWorkspaceClient();
 const base = `/tenant/${tenant}/payroll/runs`, scope = { employer, period, tab: 'payments' };
 const href = (extra: Record<string, string> = {}) => `${base}?${new URLSearchParams({ ...scope, ...(query.payment_q ? { payment_q: query.payment_q } : {}), ...extra })}`;
 if (!client) return <Message tone="bad">تعذر تحميل الصرف. <Link href={href()}>أعد المحاولة</Link></Message>;
 if ((query.payment_q?.length ?? 0) > 120 || [query.payment_after, query.payment_before, query.payment_event].some(value => value && !uuid(value))) return <Message tone="bad">رابط البحث غير مكتمل. <Link href={href({ payment_q: '', payment_after: '', payment_before: '', payment_event: '' })}>عرض دفعات المسير</Link></Message>;
 const result = await client.rpc('payroll_payment_workspace', { p_tenant: tenant, p_employer: employer, p_output: output, p_query: query.payment_q ?? '', p_after: query.payment_after || null, p_history_before: query.payment_before || null, p_event: query.payment_event || null });
 if (result.error || !result.data) return <Message tone="bad">{paymentError(result.error?.code, result.error?.message)}</Message>;
 const work = result.data as PaymentWorkspace;
 const pending = work.access.can_record && !work.superseded ? await client.rpc('payroll_payment_request_get', { p_tenant: tenant, p_employer: employer, p_output: output }) : { data: null, error: null };
 if (pending.error) return <Message tone="bad">تعذر التحقق من الدفعة السابقة. أعد تحميل المسير قبل تسجيل دفعة جديدة.</Message>;
 const props = { actor, tenant, employer, output, revision: work.revision, today: work.today, employees: work.employees, remaining: work.summary.remaining, remainingCount: work.summary.remaining_count, recoveryAttempt: typeof pending.data?.attempt === 'string' ? pending.data.attempt : undefined };
 const canRecord = work.access.can_record && !work.superseded;
 return <section className={styles.runSection} aria-label="صرف المسير">
  <div className={styles.formHeading}><h2>{Number(work.summary.remaining) === 0 ? 'تم تسجيل كامل الصرف' : 'تسجيل الصرف'}</h2></div>
  <dl className={styles.figureStrip}><div><dt>المستحق</dt><dd>{money(work.summary.payable)}</dd></div><div><dt>المدفوع</dt><dd>{money(work.summary.paid)}</dd></div><div><dt>المتبقي</dt><dd>{money(work.summary.remaining)}</dd></div></dl>
  {work.superseded && <Message tone="info">هذا مسير سابق استُبدل. دفعاته محفوظة للرجوع إليها.</Message>}
  {!(canRecord && work.summary.remaining_count > 0) && <PaymentForm {...props} recoveryOnly/>}
  {canRecord && work.summary.remaining_count > 0 && <Disclosure summary="تسجيل دفعة" open><PaymentForm {...props}/></Disclosure>}
  <form method="get" className={styles.filters}>{Object.entries(scope).map(([name, value]) => <input key={name} type="hidden" name={name} value={value}/>)}<label>البحث عن موظف<Input name="payment_q" defaultValue={query.payment_q ?? ''} placeholder="مثال: أحمد محمد" maxLength={120}/></label><Button variant="ghost" type="submit">بحث</Button></form>
  <div className={styles.tableScroll}><table className={styles.recordTable}><thead><tr><th scope="col">الموظف</th><th scope="col">المستحق</th><th scope="col">المدفوع</th><th scope="col">المتبقي</th></tr></thead><tbody>{work.employees.map(employee => <tr key={employee.employment_id}><th scope="row">{employee.employee_snapshot.name}<small>{employee.employee_snapshot.code}</small></th><td>{money(employee.payable)}</td><td>{money(employee.paid)}</td><td>{money(employee.remaining)}</td></tr>)}</tbody></table></div>
  {!work.employees.length && <p>لا يوجد موظفون مطابقون. غيّر البحث أو عد إلى أول النتائج.</p>}{work.employees.length === 30 && <ButtonLink variant="ghost" href={href({ payment_after: work.employees[29].employment_id })}>موظفون آخرون</ButtonLink>}{query.payment_after && <Link href={href({ payment_after: '' })}>أول النتائج</Link>}
  <Disclosure summary="سجل الدفعات وتصحيحها">{work.history.length ? <div className={styles.historyList}>{work.history.map(entry => <article key={entry.id}><h3>{entry.kind === 'compensation' ? 'تصحيح دفعة' : entry.compensated ? 'دفعة صُححت' : 'دفعة مسجلة'} · {money(entry.amount)}</h3><p>{displayDate(entry.paid_on)} · {entry.reference}</p><p>{entry.reason}</p><Link href={href({ payment_event: entry.id, payment_after: '' })}>عرض توزيع الدفعة</Link>{canRecord && work.access.can_correct_record && entry.kind === 'payment' && !entry.compensated && <Disclosure summary="تصحيح دفعة سُجلت بالخطأ"><PaymentForm {...props} original={entry.id} originalAmount={entry.amount}/></Disclosure>}</article>)}</div> : <p>لم تُسجل دفعات بعد.</p>}{work.history.length === 20 && <Link href={href({ payment_before: work.history[19].id })}>دفعات أقدم</Link>}{query.payment_event && <Link href={href({ payment_event: '', payment_after: '' })}>جميع الدفعات</Link>}</Disclosure>
 </section>;
}
