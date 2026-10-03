'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function changeOperatorGrantAction(formData: FormData) {
  const email = text(formData, 'email').toLowerCase();
  const action = text(formData, 'action');
  const canManage = formData.get('canManageOperators') === 'on';
  const canOnboard = formData.get('canOnboardTenants') === 'on';
  const canManageLifecycle = formData.get('canManageTenantLifecycle') === 'on';
  const canManageCommercial = formData.get('canManageCommercialAccess') === 'on';
  const canManageStatutory = formData.get('canManageStatutoryRules') === 'on';
  const reason = text(formData, 'reason');
  if (!validEmail(email) || !['grant', 'update', 'revoke'].includes(action)) return 'invalid';
  if (action !== 'revoke' && !canManage && !canOnboard && !canManageLifecycle && !canManageCommercial && !canManageStatutory) return 'capability';
  if (reason.length < 3 || reason.length > 500) return 'reason';
  const supabase = await createSupabaseServerClient();
  if (!supabase) return 'setup';
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data, error } = await supabase.rpc('change_platform_operator_authority', {
    p_target_email: email, p_action: action, p_can_manage_operators: canManage,
    p_can_onboard_tenants: canOnboard, p_can_manage_tenant_lifecycle: canManageLifecycle,
    p_can_manage_commercial_access: canManageCommercial, p_can_manage_statutory_rules: canManageStatutory, p_reason: reason,
  });
  if (error) return mapError(error.message);
  if (!data || typeof data !== 'object' || Array.isArray(data)) return 'failed';
  const result = data as Record<string, unknown>;
  if (['grant', 'update', 'revoke'].includes(String(result.state))) revalidatePath('/operator', 'layout');
  if (result.state === 'revoke' && typeof result.email === 'string'
    && result.email.toLowerCase() === user.email?.toLowerCase()) {
    const { error: signOutError } = await supabase.auth.signOut({ scope: 'local' });
    redirect(signOutError ? '/' : '/auth/login?state=operator-revoked');
  }
  if (result.state === 'update' && typeof result.email === 'string'
    && result.email.toLowerCase() === user.email?.toLowerCase() && result.can_manage_operators === false) {
    redirect(result.can_onboard_tenants === true || result.can_manage_tenant_lifecycle === true || result.can_manage_commercial_access === true || result.can_manage_statutory_rules === true
      ? '/operator?state=updated-self'
      : '/auth/login?state=operator-revoked');
  }
  const state = result.state === 'grant' ? 'granted'
    : result.state === 'update' ? 'updated'
      : result.state === 'revoke' ? 'revoked'
        : result.state === 'already-active' ? 'already-active'
          : result.state === 'already-revoked' ? 'already-revoked'
            : result.state === 'not-active' ? 'not-active'
              : result.state === 'unchanged' ? 'unchanged' : 'failed';
  if (state === 'already-active' || state === 'already-revoked' || state === 'not-active' || state === 'unchanged' || state === 'failed') return state;
  go(state);
}

function text(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function validEmail(value: string) { return value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value); }
function mapError(message: string) {
  if (message.includes('platform_operator_manage_forbidden')) return 'forbidden';
  if (message.includes('platform_operator_target_unavailable')) return 'target-unavailable';
  if (message.includes('platform_operator_last_manager') || message.includes('final active Platform Operator manager')) return 'last-manager';
  if (message.includes('platform_operator_reason_required')) return 'reason';
  if (message.includes('platform_operator_capability_required')) return 'capability';
  if (message.includes('platform_operator_action_invalid') || message.includes('platform_operator_email_invalid')) return 'invalid';
  return 'failed';
}
function go(state: string): never { redirect(`/operator/operators?state=${encodeURIComponent(state)}`); }
