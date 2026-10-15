import { operatorEntitlementSnapshot, operatorRecord, type OperatorEntitlement, type OperatorEntitlementSnapshot } from './operator-read';
import { operatorServiceLabels } from './operator-labels';

export type ServiceKey = keyof typeof operatorServiceLabels;
export const serviceOrder: ServiceKey[] = ['hr.people', 'hr.attendance', 'hr.leave', 'hr.payroll', 'hr.employee_finance'];
export type ServiceChange = {
  capability_key: ServiceKey; is_granted: boolean; duration: 'resume' | 'indefinite' | 'last_day' | 'exact';
  last_day?: string | null; valid_until?: string | null;
};
export type ServiceDecision = OperatorEntitlement & {
  resume_kind: 'first' | 'indefinite' | 'finite' | 'expired' | 'unknown';
  resume_until: string | null; resume_last_day: string | null; valid_until_last_day: string | null;
};
export type ServiceSnapshot = Omit<OperatorEntitlementSnapshot, 'entitlements'> & { entitlements: ServiceDecision[] };
export type ServicePlanEntry = ServiceChange & { valid_until: string | null; last_day: string | null; derived: boolean };
export type ExpectedServices = Record<string, { valid_from: string | null; is_granted: boolean | null }>;
export type ServiceResult =
  | { outcome: 'changed' | 'unchanged' | 'stale'; snapshot: ServiceSnapshot }
  | { outcome: 'plan_required'; snapshot: ServiceSnapshot; plan: ServicePlanEntry[] }
  | { outcome: 'duration_required'; snapshot: ServiceSnapshot; capability_key: ServiceKey }
  | { outcome: 'error'; message: string }
  | { outcome: 'unknown' };

const nullableDate = (value: unknown) => value === null || (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
  && Number.isFinite(Date.parse(`${value}T00:00:00Z`)) && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value);
const nullableInstant = (value: unknown) => value === null || (typeof value === 'string' && Number.isFinite(Date.parse(value)));
export function serviceSnapshot(value: unknown): value is ServiceSnapshot {
  return operatorEntitlementSnapshot(value) && value.entitlements.every(row => {
    const decision = row as unknown as Record<string, unknown>;
    return ['first', 'indefinite', 'finite', 'expired', 'unknown'].includes(String(decision.resume_kind))
      && nullableInstant(decision.resume_until) && nullableDate(decision.resume_last_day) && nullableDate(decision.valid_until_last_day)
      && (decision.resume_kind !== 'finite' || (decision.resume_until !== null && decision.resume_last_day !== null));
  });
}
export function servicePlan(value: unknown): value is ServicePlanEntry[] {
  return Array.isArray(value) && value.length > 0 && value.length <= 5
    && new Set(value.map(row => operatorRecord(row) ? row.capability_key : null)).size === value.length
    && value.every(row => operatorRecord(row) && serviceOrder.includes(row.capability_key as ServiceKey)
      && typeof row.is_granted === 'boolean' && ['resume', 'indefinite', 'last_day', 'exact'].includes(String(row.duration))
      && nullableInstant(row.valid_until) && nullableDate(row.last_day) && typeof row.derived === 'boolean'
      && (row.duration !== 'last_day' || row.last_day !== null));
}
export function expectedServices(snapshot: ServiceSnapshot): ExpectedServices {
  return Object.fromEntries(snapshot.entitlements.map(row => [row.capability_key, { valid_from: row.valid_from, is_granted: row.is_granted }]));
}
export function confirmationChanges(plan: ServicePlanEntry[]): ServiceChange[] {
  return plan.map(row => ({ capability_key: row.capability_key, is_granted: row.is_granted, duration: row.duration,
    ...(row.duration === 'exact' ? { valid_until: row.valid_until } : {}),
    ...(row.duration === 'last_day' ? { last_day: row.last_day } : {}),
  }));
}
export function serviceDayLabel(day: string) {
  return new Intl.DateTimeFormat('ar-EG', { timeZone: 'UTC', numberingSystem: 'latn', day: 'numeric', month: 'long', year: 'numeric' })
    .format(new Date(`${day}T00:00:00Z`));
}
