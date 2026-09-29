'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function onboardTenantAction(formData: FormData) {
  const idempotencyKey = textField(formData, 'idempotencyKey');
  if (!/^[0-9a-f-]{36}$/i.test(idempotencyKey)) redirect('/operator?state=failed');

  const tenantName = textField(formData, 'tenantName');
  const entityName = textField(formData, 'entityName');
  const siteName = textField(formData, 'siteName');
  const adminEmail = textField(formData, 'adminEmail').toLowerCase();
  const seatMode = limitMode(formData, 'seats');
  const siteMode = limitMode(formData, 'sites');
  const seatLimit = parseLimit(formData, 'seats', seatMode);
  const siteLimit = parseLimit(formData, 'sites', siteMode);

  if (!tenantName || !siteName || !adminEmail || seatLimit === INVALID || siteLimit === INVALID) {
    redirectWithState(idempotencyKey, 'limit');
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) redirectWithState(idempotencyKey, 'setup');
  const { data, error } = await supabase.rpc('onboard_tenant', {
    p_idempotency_key: idempotencyKey,
    p_tenant_name: tenantName,
    p_legal_entity_name: entityName,
    p_site_name: siteName,
    p_admin_email: adminEmail,
    p_seat_limit_mode: seatMode,
    p_seat_limit: seatLimit,
    p_site_limit_mode: siteMode,
    p_site_limit: siteLimit,
  });

  if (error) {
    const state = error.message.includes('platform_operator_onboarding_forbidden') ? 'forbidden'
      : error.message.includes('onboarding_admin_') ? 'admin'
      : error.message.includes('onboarding_invalid_limit') ? 'limit'
      : error.message.includes('onboarding_idempotency_conflict') ? 'conflict'
      : 'failed';
    redirectWithState(idempotencyKey, state);
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) redirectWithState(idempotencyKey, 'failed');
  redirect(`/operator?key=${encodeURIComponent(idempotencyKey)}`);
}

function redirectWithState(key: string, state: string): never {
  redirect(`/operator?key=${encodeURIComponent(key)}&state=${encodeURIComponent(state)}`);
}

const INVALID = Symbol('invalid limit');

function textField(formData: FormData, name: string) {
  return String(formData.get(name) ?? '').trim();
}

function limitMode(formData: FormData, kind: 'seats' | 'sites'): 'limited' | 'unlimited' {
  return formData.get(`${kind}Mode`) === 'unlimited' ? 'unlimited' : 'limited';
}

function parseLimit(formData: FormData, kind: 'seats' | 'sites', mode: 'limited' | 'unlimited'): number | null | typeof INVALID {
  if (mode === 'unlimited') return null;
  const value = textField(formData, `${kind}Limit`);
  if (!/^\d+$/.test(value)) return INVALID;
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : INVALID;
}
