'use server';

import { redirect } from 'next/navigation';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function createEmployeeAccountAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employeeId');
  const email = field(formData, 'email').toLowerCase();
  const requestKey = field(formData, 'requestKey');
  const path = `/tenant/${tenantId}/people/${employeeId}`;
  if (![tenantId, employeeId, requestKey].every(isUuid)) redirect(`${path}?account=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${path}?account=setup`);
  const { data, error } = await supabase.rpc('start_people_employee_account_provision', {
    p_tenant_id: tenantId, p_employee_id: employeeId, p_target_email: email, p_request_key: requestKey,
  });
  if (error || !isRecord(data) || !isUuid(data.intent_id)) redirect(`${path}?account=${mapError(error?.message)}`);
  await sendActivation(supabase, tenantId, employeeId, data.intent_id, path);
}

export async function retryEmployeeAccountActivationAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employeeId');
  const intentId = field(formData, 'intentId');
  const path = `/tenant/${tenantId}/people/${employeeId}`;
  if (![tenantId, employeeId, intentId].every(isUuid)) redirect(`${path}?account=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${path}?account=setup`);
  await sendActivation(supabase, tenantId, employeeId, intentId, path);
}

async function sendActivation(supabase: NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>,
  tenantId: string, employeeId: string, intentId: string, profilePath: string): Promise<never> {
  const { data, error } = await supabase.rpc('prepare_people_employee_account_provision', {
    p_tenant_id: tenantId, p_employee_id: employeeId, p_intent_id: intentId,
  });
  if (error || !isRecord(data)) redirect(`${profilePath}?account=${mapError(error?.message)}`);
  if (data.state === 'manual_review') redirect(`${profilePath}?account=manual-review`);
  if (data.state === 'activated') redirect(`${profilePath}?account=activated`);
  if (!['pending', 'user_created'].includes(String(data.state)) || typeof data.target_email !== 'string'
    || !isUuid(data.auth_marker) || !isUuid(data.intent_id)) redirect(`${profilePath}?account=operation-error`);

  const admin = createSupabaseAdminClient();
  if (!admin) redirect(`${profilePath}?account=setup`);
  if (data.state === 'pending') {
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: data.target_email,
      email_confirm: false,
      app_metadata: {
        people_employee_provision_intent_id: data.intent_id,
        people_employee_provision_marker: data.auth_marker,
      },
    });
    if (createError || !created.user) {
      const { data: recovered, error: recoveryError } = await supabase.rpc('prepare_people_employee_account_provision', {
        p_tenant_id: tenantId, p_employee_id: employeeId, p_intent_id: intentId,
      });
      if (recoveryError || !isRecord(recovered)) redirect(`${profilePath}?account=create-failed`);
      if (recovered.state === 'manual_review') redirect(`${profilePath}?account=manual-review`);
      if (recovered.state !== 'user_created') redirect(`${profilePath}?account=create-failed`);
      data.auth_user_id = recovered.auth_user_id;
      data.state = recovered.state;
    } else {
      const appMetadata = created.user.app_metadata ?? {};
      if (created.user.email?.toLowerCase() !== data.target_email
        || appMetadata.people_employee_provision_intent_id !== data.intent_id
        || appMetadata.people_employee_provision_marker !== data.auth_marker) {
        redirect(`${profilePath}?account=manual-review`);
      }
      const { data: captured, error: captureError } = await supabase.rpc('prepare_people_employee_account_provision', {
        p_tenant_id: tenantId, p_employee_id: employeeId, p_intent_id: intentId,
      });
      if (captureError || !isRecord(captured) || captured.state !== 'user_created' || captured.auth_user_id !== created.user.id) {
        redirect(`${profilePath}?account=manual-review`);
      }
      data.auth_user_id = created.user.id;
      data.state = 'user_created';
    }
  }

  const redirectTo = activationCallbackUrl(data.intent_id);
  if (!redirectTo || typeof data.target_email !== 'string') redirect(`${profilePath}?account=setup`);
  const { error: deliveryError } = await admin.auth.admin.inviteUserByEmail(data.target_email, { redirectTo });
  const deliveryState = deliveryError ? 'failed' : 'sent';
  const safeDeliveryError = safeCode(deliveryError?.code ?? deliveryError?.name);
  await supabase.rpc('record_people_employee_account_delivery', {
    p_tenant_id: tenantId, p_employee_id: employeeId, p_intent_id: intentId,
    p_delivery_state: deliveryState, p_error_code: deliveryError ? safeDeliveryError : null,
  });
  redirect(`${profilePath}?account=${deliveryError ? 'delivery-failed' : 'delivery-sent'}`);
}

function activationCallbackUrl(intentId: string) {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL;
  if (!appUrl || !isUuid(intentId)) return null;
  try {
    const origin = new URL(appUrl);
    if (origin.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(origin.hostname)) return null;
    const callback = new URL('/auth/employee-account-activation/callback', origin);
    callback.searchParams.set('intent_id', intentId);
    return callback.toString();
  } catch { return null; }
}

function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: unknown): value is string { return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function isRecord(value: unknown): value is Record<string, unknown> { return Boolean(value) && typeof value === 'object' && !Array.isArray(value); }
function safeCode(value: unknown) { return typeof value === 'string' && /^[a-z0-9_-]{1,80}$/i.test(value) ? value : 'activation_delivery_failed'; }
function mapError(message?: string) {
  if (message?.includes('people_employee_account_manage_forbidden')) return 'forbidden';
  if (message?.includes('people_employee_account_email_conflict')) return 'manual-review';
  if (message?.includes('people_employee_account_operation_in_progress')) return 'pending';
  if (message?.includes('people_employee_account_employee_unavailable') || message?.includes('people_employee_account_tenant_unavailable')) return 'subject-unavailable';
  if (message?.includes('people_employee_account_already_linked')) return 'already-linked';
  if (message?.includes('people_employee_account_request_key_conflict')) return 'operation-error';
  return 'operation-error';
}
