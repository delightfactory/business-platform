'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

export async function createInvitationAction(formData: FormData) {
  const key = textField(formData, 'idempotencyKey');
  const tenantName = textField(formData, 'tenantName');
  const entityName = textField(formData, 'entityName');
  const siteName = textField(formData, 'siteName');
  const email = textField(formData, 'targetEmail').toLowerCase();
  const seatMode = limitMode(formData, 'seats');
  const siteMode = limitMode(formData, 'sites');
  const seatLimit = parseLimit(formData, 'seats', seatMode);
  const siteLimit = parseLimit(formData, 'sites', siteMode);

  if (!/^[0-9a-f-]{36}$/i.test(key) || !tenantName || !siteName || !email || seatLimit === INVALID || siteLimit === INVALID) {
    redirect('/operator/invitations/new?state=invalid');
  }

  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/operator/invitations/new?state=setup');
  const { data, error } = await supabase.rpc('create_tenant_admin_invitation', {
    p_idempotency_key: key,
    p_tenant_name: tenantName,
    p_legal_entity_name: entityName,
    p_site_name: siteName,
    p_target_email: email,
    p_seat_limit_mode: seatMode,
    p_seat_limit: seatLimit,
    p_site_limit_mode: siteMode,
    p_site_limit: siteLimit,
  });
  if (error || !isInvitation(data)) redirect('/operator/invitations/new?state=forbidden');
  if (data.created !== true) {
    const state = data.lifecycle_state === 'accepted' ? 'already-accepted'
      : data.lifecycle_state === 'revoked' ? 'already-revoked'
      : data.lifecycle_state === 'expired' ? 'expired'
      : 'existing';
    redirect(`/operator/invitations?id=${encodeURIComponent(data.id)}&state=${state}`);
  }

  const recorded = await deliverInvitation(supabase, data);
  redirect(`/operator/invitations?id=${encodeURIComponent(data.id)}&state=created-${recorded}`);
}

export async function reissueInvitationAction(formData: FormData) {
  const id = textField(formData, 'invitationId');
  if (!isUuid(id)) redirect('/operator/invitations?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/operator/invitations?state=setup');
  const { data, error } = await supabase.rpc('reissue_tenant_admin_invitation', { p_invitation_id: id });
  if (error || !isInvitation(data)) redirect('/operator/invitations?state=forbidden');
  if (data.lifecycle_state === 'expired') redirect(`/operator/invitations?id=${encodeURIComponent(id)}&state=expired`);
  const recorded = await deliverInvitation(supabase, data);
  redirect(`/operator/invitations?id=${encodeURIComponent(id)}&state=reissued-${recorded}`);
}

export async function revokeInvitationAction(formData: FormData) {
  const id = textField(formData, 'invitationId');
  if (!isUuid(id)) redirect('/operator/invitations?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/operator/invitations?state=setup');
  const { error } = await supabase.rpc('revoke_tenant_admin_invitation', { p_invitation_id: id });
  redirect(`/operator/invitations?id=${encodeURIComponent(id)}&state=${error ? 'forbidden' : 'revoked'}`);
}

async function deliverInvitation(
  supabase: NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>,
  invitation: Invitation,
): Promise<'sent' | 'failed' | 'unknown'> {
  const admin = createSupabaseAdminClient();
  const callbackUrl = invitationCallbackUrl(invitation.id, invitation.issuance);
  let succeeded = false;
  let errorCode = !admin ? 'admin_auth_not_configured' : !callbackUrl ? 'app_origin_not_configured' : 'auth_invite_failed';
  if (admin && callbackUrl) {
    const { error: inviteError } = await admin.auth.admin.inviteUserByEmail(invitation.target_email, {
      data: { invitation_id: invitation.id, issuance: invitation.issuance },
      redirectTo: callbackUrl,
    });
    if (!inviteError) {
      succeeded = true;
    } else if (isExistingAuthUserError(inviteError.code, inviteError.message)) {
      const { error: linkError } = await admin.auth.signInWithOtp({
        email: invitation.target_email,
        options: { shouldCreateUser: false, emailRedirectTo: callbackUrl },
      });
      succeeded = !linkError;
      errorCode = safeErrorCode(linkError?.code ?? linkError?.name ?? inviteError.code);
    } else {
      errorCode = safeErrorCode(inviteError.code ?? inviteError.name);
    }
  }
  const { error: recordError } = await supabase.rpc('record_tenant_admin_invitation_delivery', {
    p_invitation_id: invitation.id,
    p_issuance: invitation.issuance,
    p_succeeded: succeeded,
    p_error_code: succeeded ? null : errorCode,
  });
  if (recordError) return 'unknown';
  return succeeded ? 'sent' : 'failed';
}

type Invitation = { id: string; issuance: number; target_email: string; lifecycle_state?: string; created?: boolean };

function isInvitation(value: unknown): value is Invitation {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const item = value as Record<string, unknown>;
  return isUuid(item.id) && typeof item.issuance === 'number' && typeof item.target_email === 'string';
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function safeErrorCode(value: unknown) {
  return typeof value === 'string' && /^[a-z0-9_-]{1,80}$/i.test(value) ? value : 'auth_invite_failed';
}

function isExistingAuthUserError(code: string | undefined, message: string) {
  return ['email_exists', 'user_already_exists', 'already_registered'].includes(code ?? '')
    || /already\s+(registered|exists)/i.test(message);
}

function invitationCallbackUrl(invitationId: string, issuance: number) {
  const configuredOrigin = process.env.NEXT_PUBLIC_APP_URL;
  if (!configuredOrigin) return null;
  try {
    const origin = new URL(configuredOrigin);
    if (origin.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(origin.hostname)) return null;
    const callback = new URL('/auth/invitations/callback', origin);
    callback.searchParams.set('invitation_id', invitationId);
    callback.searchParams.set('issuance', String(issuance));
    return callback.toString();
  } catch {
    return null;
  }
}

const INVALID = Symbol('invalid limit');
function textField(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
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
