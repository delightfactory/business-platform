'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function changeCommercialLimitAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId');
  const capabilityKey = text(formData, 'capabilityKey');
  const limitKey = text(formData, 'limitKey');
  const mode = text(formData, 'mode');
  const rawValue = text(formData, 'value');
  const reason = text(formData, 'reason');
  const value = mode === 'unlimited' ? null : Number(rawValue);
  if (!isUuid(tenantId) || !isLimit(capabilityKey, limitKey) || !['limited', 'unlimited'].includes(mode)
    || (mode === 'limited' && (!Number.isSafeInteger(value) || Number(value) < 1))) go(tenantId, 'invalid');
  if (reason.length < 3 || reason.length > 500) go(tenantId, 'reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { error } = await supabase.rpc('change_tenant_capability_limit', {
    p_tenant_id: tenantId,
    p_capability_key: capabilityKey,
    p_limit_key: limitKey,
    p_limit_mode: mode,
    p_limit_value: value,
    p_reason: reason,
  });
  if (error) go(tenantId, mapError(error.message));
  redirect(`/operator/commercial/${tenantId}?state=updated`);
}

function text(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function isLimit(capability: string, key: string) {
  return (capability === 'tenant.users' && key === 'max_users') || (capability === 'tenant.sites' && key === 'max_sites');
}
function mapError(message: string) {
  if (message.includes('commercial_access_forbidden')) return 'forbidden';
  if (message.includes('commercial_tenant_unavailable')) return 'not-found';
  if (message.includes('commercial_limit_future_conflict')) return 'future-conflict';
  if (message.includes('commercial_limit_conflict')) return 'conflict';
  if (message.includes('commercial_limit_reason_required')) return 'reason';
  if (message.includes('commercial_limit_value_invalid')) return 'invalid';
  return 'failed';
}
function go(tenantId: string, state: string): never {
  if (!isUuid(tenantId)) redirect('/operator/commercial?state=invalid');
  redirect(`/operator/commercial/${tenantId}?state=${encodeURIComponent(state)}`);
}
