import { WorkspaceTabs } from '@/components/ui';
import { cairoToday, isCivilDate } from '@/lib/attendance-calendar';

export function AttendanceWorkspaceTabs({ tenantId, current, date, payrollEmployer, payrollPeriod }: {
  tenantId: string; current: 'day' | 'calendar' | 'review'; date?: string; payrollEmployer?: string; payrollPeriod?: string;
}) {
  const day = isCivilDate(date) ? date : cairoToday();
  const base = `/tenant/${tenantId}/attendance`;
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const context = uuid.test(payrollEmployer ?? '') && uuid.test(payrollPeriod ?? '')
    ? `&${new URLSearchParams({ payroll_employer: payrollEmployer!, payroll_period: payrollPeriod! })}` : '';
  return <WorkspaceTabs label="عرض الحضور" items={[
    { href: `${base}?date=${day}${context}`, label: 'سجل اليوم', current: current === 'day' },
    { href: `${base}/calendar?month=${day.slice(0, 7)}&date=${day}${context}`, label: 'الشهر', current: current === 'calendar' },
    { href: `${base}/review?date=${day}${context}`, label: 'يحتاج مراجعة', current: current === 'review' },
  ]} />;
}
