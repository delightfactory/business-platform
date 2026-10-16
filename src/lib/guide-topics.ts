// Public help recommendations, never authorization. Only successful explicit
// true access flags recommend a task. Denied and failed snapshots add nothing.
export type GuideSnapshot = { data: Record<string, unknown> | null; error?: unknown };
export type GuideSnapshots = Partial<Record<'members' | 'structure' | 'branding' | 'people' | 'attendance' | 'channels' | 'workPolicies' | 'leave' | 'calendar' | 'inputs' | 'runs' | 'navigation' | 'payments' | 'corrections' | 'employee' | 'mobile', GuideSnapshot>>;

export function tenantGuideTopics(snapshots: GuideSnapshots): string[] {
  const topics = new Set<string>();
  const has = (name: keyof GuideSnapshots, flag: string) => !snapshots[name]?.error && snapshots[name]?.data?.[flag] === true;
  const present = (name: keyof GuideSnapshots) => !snapshots[name]?.error && Boolean(snapshots[name]?.data);
  const add = (condition: boolean, ...keys: string[]) => { if (condition) keys.forEach(key => topics.add(key)); };
  add(present('members'), 'company-users');
  add(has('structure', 'can_manage_legal_entities') || has('structure', 'can_manage_sites'), 'company-structure');
  add(has('branding', 'can_manage_branding'), 'company-branding');
  add(has('people', 'can_view'), 'people-view');
  add(has('people', 'can_manage'), 'people-manage');
  add(has('people', 'can_manage_employment'), 'people-employment');
  add(has('people', 'can_manage_compensation'), 'people-compensation');
  add(has('people', 'can_import'), 'people-import');
  add(has('people', 'can_manage_org'), 'people-org');
  add(has('workPolicies', 'can_manage'), 'work-policies');
  add(has('attendance', 'can_view'), 'attendance-view');
  add(has('attendance', 'can_manage'), 'attendance-input');
  add(has('attendance', 'can_correct') || has('attendance', 'can_approve'), 'attendance-review');
  add(has('channels', 'can_view'), 'attendance-sources');
  add(has('leave', 'can_view'), 'leave-view');
  add(has('leave', 'can_manage'), 'leave-manage');
  add(has('leave', 'can_approve'), 'leave-approve');
  add(has('leave', 'can_adjust'), 'leave-balances');
  add(has('leave', 'self_access'), 'self-leave');
  add(present('employee'), 'profile');
  add(present('mobile'), 'self-attendance');
  add(has('calendar', 'can_view') || has('runs', 'can_view'), 'payroll-view');
  add(has('calendar', 'can_manage') || has('inputs', 'payroll_config.manage'), 'payroll-configure');
  add(has('runs', 'can_prepare') || has('inputs', 'payroll.prepare'), 'payroll-prepare');
  add(has('runs', 'can_approve') || has('inputs', 'payroll.approve'), 'payroll-approve');
  add(has('runs', 'can_lock'), 'payroll-close');
  add(has('payments', 'can_record'), 'payroll-payments');
  add(has('corrections', 'can_correct'), 'payroll-correct');
  add(has('navigation', 'can_view_advances'), 'advances');
  add(has('navigation', 'can_view_reports') && snapshots.navigation?.data?.report_kind === 'sheet', 'payroll-reports');
  return [...topics];
}

export function operatorGuideTopics(authority: { active: boolean; lifecycle: boolean; commercial: boolean; onboard: boolean; manage: boolean; statutory: boolean }): string[] {
  if (!authority.active) return [];
  return [
    ...(authority.lifecycle || authority.commercial ? ['operator-companies'] : []),
    ...(authority.lifecycle ? ['operator-lifecycle'] : []),
    ...(authority.commercial ? ['operator-commercial'] : []),
    ...(authority.onboard ? ['operator-invitations'] : []),
    ...(authority.manage ? ['operator-team'] : []),
    ...(authority.statutory ? ['operator-statutory'] : []),
  ];
}
