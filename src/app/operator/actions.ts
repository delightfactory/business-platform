'use server';

import { createSupabaseServerClient } from '@/lib/supabase/server';
import { onboardingSnapshot, operatorUuid } from '@/lib/operator-read';
import { matchingOnboardingSnapshot, onboardingIntent, onboardingRpcError, type OnboardingOutcome } from './onboarding/intent';

export async function onboardTenantAction(expectedActor: string, formData: FormData): Promise<OnboardingOutcome> {
  const intent = onboardingIntent(formData);
  if (!intent || !operatorUuid(expectedActor)) return { state: 'invalid', mutationDispatched: false };
  let mutationDispatched = false;
  try {
    const supabase = await createSupabaseServerClient();
    if (!supabase) return { state: 'unavailable', mutationDispatched };
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error) return { state: 'unavailable', mutationDispatched };
    if (!user || user.id.toLowerCase() !== expectedActor.toLowerCase()) return { state: 'actor-changed', mutationDispatched };
    // expectedActor is a guard only. SQL authorizes exclusively with auth.uid().
    mutationDispatched = true;
    const result = await supabase.rpc('onboard_tenant', {
      p_idempotency_key: intent.key, p_tenant_name: intent.tenantName, p_legal_entity_name: intent.entityName,
      p_site_name: intent.siteName, p_admin_email: intent.adminEmail,
      p_seat_limit_mode: intent.seatMode, p_seat_limit: intent.seatLimit,
      p_site_limit_mode: intent.siteMode, p_site_limit: intent.siteLimit,
    });
    if (result.error) return { state: onboardingRpcError(result.error), mutationDispatched };
    if (!matchingOnboardingSnapshot(result.data, intent)) return { state: 'unknown', mutationDispatched };
    return { state: 'saved', snapshot: result.data, mutationDispatched };
  } catch {
    return { state: mutationDispatched ? 'unknown' : 'unavailable', mutationDispatched };
  }
}

export async function readOnboardingAttemptAction(expectedActor: string, formData: FormData): Promise<OnboardingOutcome> {
  const intent = onboardingIntent(formData);
  if (!intent || !operatorUuid(expectedActor)) return { state: 'invalid', mutationDispatched: false };
  try {
    const supabase = await createSupabaseServerClient();
    if (!supabase) return { state: 'unavailable', mutationDispatched: false };
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error) return { state: 'unavailable', mutationDispatched: false };
    if (!user || user.id.toLowerCase() !== expectedActor.toLowerCase()) return { state: 'actor-changed', mutationDispatched: false };
    const result = await supabase.rpc('tenant_onboarding_result', { p_idempotency_key: intent.key });
    if (result.error) return { state: 'unavailable', mutationDispatched: false };
    // Null also covers grant loss. Only SQL-authorized identical replay follows it.
    if (result.data === null) return { state: 'absent', mutationDispatched: false };
    if (!onboardingSnapshot(result.data) || typeof result.data.admin_email !== 'string' || !result.data.admin_email.trim()) return { state: 'unavailable', mutationDispatched: false };
    if (!matchingOnboardingSnapshot(result.data, intent)) return { state: 'conflict', mutationDispatched: false };
    return { state: 'saved', snapshot: result.data, mutationDispatched: false };
  } catch {
    return { state: 'unavailable', mutationDispatched: false };
  }
}
