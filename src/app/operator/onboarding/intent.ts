import { onboardingSnapshot, operatorRecord, operatorUuid } from '@/lib/operator-read';

export type OnboardingIntent = {
  key: string; tenantName: string; entityName: string; siteName: string; adminEmail: string;
  seatMode: 'limited' | 'unlimited'; seatLimit: number | null;
  siteMode: 'limited' | 'unlimited'; siteLimit: number | null;
};

export type OnboardingOutcome = {
  state: 'saved' | 'invalid' | 'admin' | 'unknown' | 'unavailable' | 'actor-changed' | 'forbidden' | 'conflict' | 'absent';
  mutationDispatched: boolean;
  snapshot?: Record<string, unknown>;
};

function text(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

function limit(form: FormData, kind: 'seats' | 'sites') {
  const mode = text(form, `${kind}Mode`);
  if (mode === 'unlimited') return { mode, value: null } as const;
  const raw = text(form, `${kind}Limit`), value = Number(raw);
  return mode === 'limited' && /^\d+$/.test(raw) && Number.isSafeInteger(value) && value > 0 && value <= 2147483647
    ? { mode, value } as const : null;
}

export function onboardingIntent(form: FormData): OnboardingIntent | null {
  const key = text(form, 'idempotencyKey'), tenantName = text(form, 'tenantName');
  const entityName = text(form, 'entityName'), siteName = text(form, 'siteName'), adminEmail = text(form, 'adminEmail').toLowerCase();
  const seats = limit(form, 'seats'), sites = limit(form, 'sites');
  if (!operatorUuid(key) || !tenantName || !siteName || !adminEmail || !seats || !sites
    || [tenantName, entityName, siteName].some(value => [...value].length > 160) || [...adminEmail].length > 254) return null;
  return { key, tenantName, entityName, siteName, adminEmail, seatMode: seats.mode, seatLimit: seats.value, siteMode: sites.mode, siteLimit: sites.value };
}

export function matchingOnboardingSnapshot(value: unknown, intent: OnboardingIntent): value is Record<string, unknown> {
  return onboardingSnapshot(value) && typeof value.admin_email === 'string'
    && value.tenant_name === intent.tenantName && value.legal_entity_name === (intent.entityName || intent.tenantName)
    && value.site_name === intent.siteName && value.admin_email.toLowerCase() === intent.adminEmail
    && value.seat_limit_mode === intent.seatMode && value.seat_limit === intent.seatLimit
    && value.site_limit_mode === intent.siteMode && value.site_limit === intent.siteLimit;
}

export function onboardingRpcError(error: unknown): OnboardingOutcome['state'] {
  if (!operatorRecord(error)) return 'unknown';
  if (error.code === '42501' && error.message === 'platform_operator_onboarding_forbidden') return 'forbidden';
  if (error.code === 'P0001' && error.message === 'onboarding_idempotency_conflict') return 'conflict';
  if (error.code === '22023') {
    if (error.message === 'onboarding_required_fields_invalid' || error.message === 'onboarding_invalid_limit') return 'invalid';
    if (error.message === 'onboarding_admin_not_found_or_disabled' || error.message === 'onboarding_admin_email_unverified') return 'admin';
  }
  return 'unknown';
}
