export type LeaveImpactInput = { tenantId: string; typeId: string; start: string; end: string; halfDay: boolean; part: 'first' | 'second' | null; employeeId?: string; employmentId?: string };
export type LeaveImpact = {
  state: 'ready' | 'unavailable'; reason?: string;
  total_units?: string; tracked_units?: string;
  days?: Array<{ date: string; eligible: boolean; units: string; is_weekly_rest: boolean; holiday_name: string | null; pay_effect: string; balance_mode: string; halfday_state: string | null }>;
  balance?: { state: 'shown' | 'hidden' | 'not_tracked' | 'unavailable'; accounts?: Array<{ period_label: string; starts_on: string; ends_on: string; balance_days: string }>; available_days?: string; shortfall_days?: string; after_approval_days?: string | null };
};
export type LeaveImpactResult = { signature: string; impact: LeaveImpact };
export function leaveImpactSignature(input: LeaveImpactInput) {
  return JSON.stringify([input.tenantId,input.employeeId ?? '',input.employmentId ?? '',input.typeId,input.start,input.end,input.halfDay,input.part]);
}
