'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function changeTenantLifecycleAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId');
  const expectedState = text(formData, 'expectedState');
  const targetState = text(formData, 'targetState');
  const reason = text(formData, 'reason');
  if (!isUuid(tenantId) || !isState(expectedState) || !isState(targetState)) return 'invalid';
  if (reason.length < 3 || reason.length > 500) return 'reason';
  const supabase = await createSupabaseServerClient();
  if (!supabase) return 'setup';
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data: result, error } = await supabase.rpc('change_tenant_lifecycle', {
    p_tenant_id: tenantId,
    p_expected_state: expectedState,
    p_target_state: targetState,
    p_reason: reason,
  });
  if (error) return mapError(error.message);
  if (!result || typeof result !== 'object' || Array.isArray(result)) return 'failed';
  redirect(`/operator/tenants/${tenantId}?state=updated&to=${targetState}`);
}

function text(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function isState(value: string) { return value === 'active' || value === 'suspended' || value === 'archived'; }
function mapError(message: string) {
  if (message.includes('tenant_lifecycle_forbidden')) return 'forbidden';
  if (message.includes('tenant_lifecycle_tenant_not_found')) return 'not-found';
  if (message.includes('tenant_lifecycle_state_changed')) return 'stale';
  if (message.includes('tenant_lifecycle_transition_invalid')) return 'transition';
  if (message.includes('tenant_lifecycle_reason_required')) return 'reason';
  if (message.includes('tenant_lifecycle_input_invalid')) return 'invalid';
  return 'failed';
}
