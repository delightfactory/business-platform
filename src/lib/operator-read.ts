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
