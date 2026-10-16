// Source-owner domains are guidance, not permissions or named assignees.
const names: Record<string, string> = {
  payroll: 'مسؤول الرواتب',
  payroll_config: 'مسؤول إعداد الرواتب',
  people: 'مسؤول بيانات الموظفين',
  compliance: 'مسؤول الرواتب',
  payroll_compliance: 'مسؤول الرواتب',
  employee_finance: 'مسؤول سلف الموظفين',
  employee_finance_compliance: 'مسؤول مراجعة ضوابط سلف الموظفين',
  payroll_correction: 'مسؤول تصحيح الرواتب',
  payroll_time: 'مسؤول الحضور',
  payroll_leave: 'مسؤول الإجازات',
  payroll_sources: 'مسؤول الرواتب',
  payroll_units: 'مسؤول مراجعة أيام العمل',
  payroll_inputs: 'مسؤول الرواتب',
  payroll_ytd: 'مسؤول الأرصدة السابقة',
  payroll_finance: 'مسؤول السلف والخصومات',
};

export function issueResponsibility(owner: string) {
  return Object.hasOwn(names, owner) ? names[owner] : names.payroll;
}
