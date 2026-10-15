export const operatorTaskLabels = {
  can_manage_operators: 'إدارة فريق التشغيل',
  can_onboard_tenants: 'إنشاء الشركات ودعواتها',
  can_manage_tenant_lifecycle: 'حالة الشركات',
  can_manage_commercial_access: 'خدمات الشركات وحدودها',
  can_manage_statutory_rules: 'القواعد القانونية للرواتب',
} as const;

export function operatorLifecycleLabel(state: string) {
  switch (state) {
    case 'active': return 'نشطة';
    case 'suspended': return 'معلّقة';
    case 'archived': return 'مؤرشفة';
    default: return 'غير متاحة';
  }
}

export const operatorServiceLabels = {
  'hr.people': 'الموارد البشرية',
  'hr.attendance': 'الحضور والسياسات',
  'hr.leave': 'الإجازات',
  'hr.payroll': 'الرواتب',
  'hr.employee_finance': 'سلف الموظفين',
} as const;
