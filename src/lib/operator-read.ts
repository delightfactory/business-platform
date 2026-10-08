// Validate only data consumed by the operator presentation; SQL remains authoritative.
export function operatorRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function operatorUuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

function text(value: unknown): value is string { return typeof value === 'string' && value.trim().length > 0; }
function count(value: unknown): value is number { return Number.isSafeInteger(value) && (value as number) >= 0; }

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
