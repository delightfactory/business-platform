// Source-owner domains are guidance, not permissions or named assignees.
const names: Record<string, string> = {
  payroll: 'مسؤول الرواتب',
  payroll_config: 'مسؤول إعداد الرواتب',
  people: 'مسؤول بيانات الموظفين',
  compliance: 'مسؤول التأهيل المالي والقانوني',
  payroll_compliance: 'مسؤول التأهيل المالي والقانوني',
  employee_finance: 'مسؤول سلف الموظفين',
  employee_finance_compliance: 'مسؤول تأهيل سلف الموظفين',
  payroll_correction: 'مسؤول تصحيح الرواتب',
  payroll_time: 'مسؤول ربط الحضور بالرواتب',
  payroll_leave: 'مسؤول ربط الإجازات بالرواتب',
  payroll_sources: 'مسؤول مراجعة مصادر الرواتب',
  payroll_units: 'مسؤول مدخلات الأيام المستحقة',
  payroll_inputs: 'مسؤول مدخلات الرواتب',
  payroll_ytd: 'مسؤول الأرصدة السابقة',
  payroll_finance: 'مسؤول الالتزامات المالية للرواتب',
};

export function issueResponsibility(owner: string) {
  return Object.hasOwn(names, owner) ? names[owner] : names.payroll;
}
