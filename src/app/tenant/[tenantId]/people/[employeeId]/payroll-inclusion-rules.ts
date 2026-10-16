export type PayrollInclusion = { included: boolean; stamp: string; locked: boolean; can_manage: boolean };
export type InclusionState = { snapshot: PayrollInclusion; error: string; saved: boolean; uncertain: boolean; stale: boolean };

export function payrollInclusion(value: unknown): PayrollInclusion | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const snapshot = value as Record<string, unknown>;
  if (typeof snapshot.included !== 'boolean' || typeof snapshot.can_manage !== 'boolean' || typeof snapshot.locked !== 'boolean'
    || typeof snapshot.stamp !== 'string' || !/^[a-f0-9]{32}$/.test(snapshot.stamp)) return null;
  return snapshot as PayrollInclusion;
}
