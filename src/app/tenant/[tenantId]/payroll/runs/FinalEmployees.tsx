import Link from 'next/link';
import { ButtonLink, Message } from '@/components/ui';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { money } from './rules';
import styles from '../payroll.module.css';

type FinalEmployee = { employment_id: string; employee: { name: string; code: string }; net: string; explanation: { gross?: string; deductions?: string; statutory_deductions?: string; base?: string } };
export async function FinalEmployees({ tenant, employer, period, output, query }: { tenant: string; employer: string; period: string; output: string; query: Record<string, string | undefined> }) {
 const client = await getWorkspaceClient();
 if (!client) return <Message tone="bad">تعذر تحميل موظفي المسير.</Message>;
 const result = await client.rpc('payroll_final_output', { p_tenant: tenant, p_employer: employer, p_output: output, p_after: query.after || null, p_limit: 30, p_export: false });
 if (result.error || !result.data) return <Message tone="bad">تعذر عرض القيم النهائية لهذا الحساب. أعد المحاولة أو راجع مدير الشركة.</Message>;
 const employees = (result.data.employees ?? []) as FinalEmployee[];
 const base = `/tenant/${tenant}/payroll/runs?${new URLSearchParams({ employer, period, tab: 'employees' })}`;
 return <section className={styles.runSection}><div className={styles.formHeading}><h2>رواتب الموظفين المعتمدة</h2><ButtonLink variant="ghost" href={`/tenant/${tenant}/payroll/output?${new URLSearchParams({ employer, period, output })}`}>التفاصيل وكشوف الرواتب</ButtonLink></div><div className={styles.tableScroll}><table className={styles.recordTable}><thead><tr><th scope="col">الموظف</th><th scope="col">الاستحقاقات</th><th scope="col">خصومات الشركة</th><th scope="col">الضريبة والتأمينات</th><th scope="col">الصافي</th></tr></thead><tbody>{employees.map(employee => <tr key={employee.employment_id}><th scope="row">{employee.employee.name}<small>{employee.employee.code}</small></th><td>{money(employee.explanation.gross)}</td><td>{money(employee.explanation.deductions)}</td><td>{money(employee.explanation.statutory_deductions)}</td><td>{money(employee.net)}</td></tr>)}</tbody></table></div>{employees.length === 30 && <Link href={`${base}&after=${employees[29].employment_id}`}>موظفون آخرون</Link>}{query.after && <Link href={base}>أول الموظفين</Link>}</section>;
}
