'use server';

import { redirect } from 'next/navigation';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function verifyEmployeeAccountActivationAction(formData: FormData) {
  const tokenHash = field(formData, 'tokenHash');
  const type = field(formData, 'type');
  const intentId = field(formData, 'intentId');
  const callback = `/auth/employee-account-activation/callback?intent_id=${encodeURIComponent(intentId)}`;
  if (!isUuid(intentId) || !/^[a-zA-Z0-9_-]{16,512}$/.test(tokenHash) || !['email','invite','magiclink'].includes(type)) redirect(`${callback}&state=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${callback}&state=setup`);
  const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: type as 'email' | 'invite' | 'magiclink' });
  if (error) redirect(`${callback}&state=expired`);
  const { error: identityError } = await supabase.rpc('people_employee_account_activation_snapshot', { p_intent_id: intentId });
  if (identityError) redirect(`${callback}&state=identity`);
  redirect(`/auth/employee-account-activation?intent_id=${encodeURIComponent(intentId)}`);
}

export async function setEmployeeAccountPasswordAction(formData: FormData) {
  const intentId = field(formData, 'intentId');
  const password = String(formData.get('password') ?? '');
  const confirmation = String(formData.get('confirmation') ?? '');
  const page = `/auth/employee-account-activation?intent_id=${encodeURIComponent(intentId)}`;
  if (!isUuid(intentId)) redirect('/auth/employee-account-activation?state=invalid');
  if (password.length < 8 || password !== confirmation) redirect(`${page}&state=password`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${page}&state=setup`);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`${page}&state=identity`);
  const { data: intent, error: intentError } = await supabase.rpc('people_employee_account_activation_snapshot', { p_intent_id: intentId });
  if (intentError || !isRecord(intent) || intent.intent_id !== intentId
    || !['user_created', 'activated'].includes(String(intent.state))) {
    redirect(`${page}&state=identity`);
  }
  const wasActivated = intent.state === 'activated';
  if (wasActivated && intent.password_ready === true) redirect(`${page}&state=activated`);
  const { error: passwordError } = await supabase.auth.updateUser({ password });
  if (passwordError) redirect(`${page}&state=password`);
  const { data: { user: updatedUser } } = await supabase.auth.getUser();
  if (!updatedUser || updatedUser.id !== user.id) redirect(`${page}&state=identity`);
  const admin = createSupabaseAdminClient();
  if (!admin) redirect(`${page}&state=readiness`);
  const { error: readinessError } = await admin.rpc('record_people_employee_account_password_readiness', {
    p_intent_id: intentId,
    p_user_id: updatedUser.id,
  });
  if (readinessError) redirect(`${page}&state=readiness`);
  if (wasActivated) redirect(`${page}&state=password-ready`);
  await activateRecipientAccount(supabase, intentId, page);
}

export async function retryEmployeeAccountActivationAction(formData: FormData) {
  const intentId = field(formData, 'intentId');
  const page = `/auth/employee-account-activation?intent_id=${encodeURIComponent(intentId)}`;
  if (!isUuid(intentId)) redirect('/auth/employee-account-activation?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${page}&state=setup`);
  await activateRecipientAccount(supabase, intentId, page);
}

async function activateRecipientAccount(supabase: NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>,
  intentId: string, page: string): Promise<never> {
  const { data, error } = await supabase.rpc('activate_people_employee_account', { p_intent_id: intentId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    const code = activationError(error?.message);
    await supabase.rpc('defer_people_employee_account_activation', { p_intent_id: intentId, p_error_code: code });
    redirect(`${page}&state=${code === 'tenant_member_limit_full' ? 'limit-full' : code === 'employee_unavailable' ? 'employee-unavailable' : 'retry'}`);
  }
  await removeProvisioningMarker(supabase, data as Record<string, unknown>);
  redirect(`${page}&state=activated`);
}

async function removeProvisioningMarker(supabase: NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>, result: Record<string, unknown>) {
  if (result.state !== 'activated') return;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user?.id) return;
  const admin = createSupabaseAdminClient();
  if (!admin) return;
  const appMetadata = { ...(user.app_metadata ?? {}) };
  appMetadata.people_employee_provision_intent_id = null;
  appMetadata.people_employee_provision_marker = null;
  await admin.auth.admin.updateUserById(user.id, { app_metadata: appMetadata });
}

function activationError(message?: string) {
  if (message?.includes('tenant_member_limit_full')) return 'tenant_member_limit_full';
  if (message?.includes('people_employee_account_employee_unavailable')) return 'employee_unavailable';
  if (message?.includes('people_employee_account_tenant_unavailable')) return 'tenant_unavailable';
  if (message?.includes('people_employee_account_link_conflict')) return 'employee_already_linked';
  if (message?.includes('people_employee_account_membership_conflict')) return 'membership_conflict';
  if (message?.includes('tenant_member_limit_unavailable')) return 'tenant_member_limit_unavailable';
  return 'activation_pending';
}
function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}
