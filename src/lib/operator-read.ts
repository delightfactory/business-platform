// Validate only data consumed by the operator presentation; SQL remains authoritative.
export function operatorRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function operatorUuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

function text(value: unknown): value is string { return typeof value === 'string' && value.trim().length > 0; }
function count(value: unknown): value is number { return Number.isSafeInteger(value) && (value as number) >= 0; }

export const operatorCapabilities = ['can_manage_operators', 'can_onboard_tenants', 'can_manage_tenant_lifecycle', 'can_manage_commercial_access', 'can_manage_statutory_rules'] as const;
export type OperatorGrant = { user_id: string; email: string; is_active: boolean; recoverable: boolean } & Record<typeof operatorCapabilities[number], boolean>;

export function operatorGrantList(value: unknown): OperatorGrant[] | null {
  if (!Array.isArray(value) || !value.every(row => operatorRecord(row) && operatorUuid(row.user_id)
    && text(row.email) && typeof row.is_active === 'boolean' && typeof row.recoverable === 'boolean'
    && operatorCapabilities.every(key => typeof row[key] === 'boolean'))) return null;
  const rows = value as OperatorGrant[];
  return new Set(rows.map(row => row.user_id.toLowerCase())).size === rows.length ? rows : null;
}

export function operatorGrantReceipt(value: unknown, action: string, email: string, capabilities: boolean[]): value is Omit<OperatorGrant, 'recoverable'> & { state: string } {
  return operatorRecord(value) && operatorUuid(value.user_id) && value.state === action
    && typeof value.email === 'string' && value.email.toLowerCase() === email
    && value.is_active === (action !== 'revoke') && operatorCapabilities.every((key, index) =>
      value[key] === (action === 'revoke' ? false : capabilities[index]));
}

export function operatorGrantNoop(value: unknown, action: string): string | null {
  if (!operatorRecord(value) || !operatorUuid(value.user_id)) return null;
  if ((action === 'grant' && value.state === 'already-active') || (action === 'update' && value.state === 'not-active')
    || (action === 'revoke' && value.state === 'already-revoked')
    || (action === 'update' && value.state === 'unchanged')) return String(value.state);
  return null;
}

export type OperatorInvitationRow = {
  id: string; target_email: string; tenant_name: string; lifecycle_state: string; delivery_state: string;
};

export function operatorInvitation(value: unknown): value is OperatorInvitationRow {
  return operatorRecord(value) && operatorUuid(value.id) && text(value.target_email)
    && text(value.tenant_name) && text(value.lifecycle_state) && text(value.delivery_state);
}

export function operatorPage<T>(value: unknown, row: (value: unknown) => value is T, identity: (value: T) => string): { rows: T[]; matching_count: number } | null {
  if (!operatorRecord(value) || !Array.isArray(value.rows) || !count(value.matching_count)
    || !value.rows.every(row) || value.matching_count < value.rows.length) return null;
  const rows = value.rows as T[];
  if (new Set(rows.map(item => identity(item).toLowerCase())).size !== rows.length) return null;
  return { rows, matching_count: value.matching_count };
}

export type OperatorTenantRow = { tenant_id: string; display_name: string; lifecycle_state: string };
export function operatorTenant(value: unknown): value is OperatorTenantRow {
  return operatorRecord(value) && operatorUuid(value.tenant_id) && text(value.display_name) && text(value.lifecycle_state);
}

export function onboardingSnapshot(value: unknown): value is Record<string, unknown> {
  if (!operatorRecord(value) || !operatorUuid(value.tenant_id) || !text(value.tenant_name)
    || !text(value.legal_entity_name) || !text(value.site_name)) return false;
  return ['seat', 'site'].every(kind => {
    const mode = value[`${kind}_limit_mode`], limit = value[`${kind}_limit`];
    return count(value[`${kind}_usage`]) && (mode === 'unlimited' ? limit === null
      : mode === 'limited' && Number.isSafeInteger(limit) && (limit as number) > 0);
  });
}

type CompanyState = 'active' | 'suspended' | 'archived';
function companyState(value: unknown): value is CompanyState {
  return value === 'active' || value === 'suspended' || value === 'archived';
}
function timestamp(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0 && Number.isFinite(Date.parse(value));
}
function nullableTimestamp(value: unknown): value is string | null { return value === null || timestamp(value); }
function snapshotStatus(value: unknown): boolean {
  return value === 'effective' || value === 'missing' || value === 'conflict' || value === 'future_conflict';
}

export type OperatorLifecycleSnapshot = { tenant_id: string; tenant_name: string; lifecycle_state: CompanyState };
export function operatorLifecycleSnapshot(value: unknown): value is OperatorLifecycleSnapshot {
  return operatorRecord(value) && operatorUuid(value.tenant_id) && text(value.tenant_name) && companyState(value.lifecycle_state);
}

export type OperatorLimit = {
  capability_key: 'tenant.users' | 'tenant.sites'; limit_key: 'max_users' | 'max_sites';
  status: string; mode: 'limited' | 'unlimited' | null; value: number | null; valid_from: string | null; usage: number;
};
export type OperatorCommercialSnapshot = { tenant_id: string; display_name: string; lifecycle_state: CompanyState; limits: OperatorLimit[] };
export function operatorCommercialSnapshot(value: unknown): value is OperatorCommercialSnapshot {
  if (!operatorRecord(value) || !operatorUuid(value.tenant_id) || !text(value.display_name) || !companyState(value.lifecycle_state)
    || !Array.isArray(value.limits) || value.limits.length !== 2) return false;
  const keys = new Set<string>();
  return value.limits.every(row => {
    if (!operatorRecord(row) || !((row.capability_key === 'tenant.users' && row.limit_key === 'max_users')
      || (row.capability_key === 'tenant.sites' && row.limit_key === 'max_sites')) || keys.has(row.capability_key)
      || !snapshotStatus(row.status) || !count(row.usage) || !nullableTimestamp(row.valid_from)
      || !(row.mode === null || row.mode === 'limited' || row.mode === 'unlimited')
      || !(row.value === null || (count(row.value) && row.value > 0))) return false;
    keys.add(row.capability_key);
    return row.status !== 'effective' || (row.valid_from !== null
      && (row.mode === 'unlimited' ? row.value === null : row.mode === 'limited' && row.value !== null));
  });
}

export type OperatorEntitlement = {
  capability_key: 'hr.people' | 'hr.payroll' | 'hr.attendance' | 'hr.leave' | 'hr.employee_finance';
  status: string; is_granted: boolean | null; valid_from: string | null; valid_until: string | null;
  evaluator_enabled: boolean; last_decision_valid_until: string | null;
};
export type OperatorEntitlementSnapshot = { tenant_id: string; display_name: string; lifecycle_state: CompanyState; entitlements: OperatorEntitlement[] };
export function operatorEntitlementSnapshot(value: unknown): value is OperatorEntitlementSnapshot {
  const expected = ['hr.people', 'hr.payroll', 'hr.attendance', 'hr.leave', 'hr.employee_finance'];
  if (!operatorRecord(value) || !operatorUuid(value.tenant_id) || !text(value.display_name) || !companyState(value.lifecycle_state)
    || !Array.isArray(value.entitlements) || value.entitlements.length !== expected.length) return false;
  const keys = new Set<string>();
  return value.entitlements.every(row => {
    if (!operatorRecord(row) || typeof row.capability_key !== 'string' || !expected.includes(row.capability_key)
      || keys.has(row.capability_key) || !snapshotStatus(row.status)
      || !(row.is_granted === null || typeof row.is_granted === 'boolean') || typeof row.evaluator_enabled !== 'boolean'
      || !nullableTimestamp(row.valid_from) || !nullableTimestamp(row.valid_until) || !nullableTimestamp(row.last_decision_valid_until)) return false;
    keys.add(row.capability_key);
    return row.status !== 'effective' || (typeof row.is_granted === 'boolean' && row.valid_from !== null);
  });
}
