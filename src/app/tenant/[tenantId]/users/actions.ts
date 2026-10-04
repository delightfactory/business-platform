'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

export type InviteMemberState = { email: string; idempotencyKey: string; error: string; attempt: number };

export async function inviteMemberFormAction(previous: InviteMemberState, formData: FormData): Promise<InviteMemberState> {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employeeId');
  const email = field(formData, 'email').toLowerCase();
  const key = previous.idempotencyKey;
  const failure = (code: string): InviteMemberState => ({ email, idempotencyKey: key, error: inviteErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !isUuid(key) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return failure('invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failure('setup');
  const { data, error } = await supabase.rpc('create_tenant_member_invitation', {
    p_tenant_id: tenantId, p_target_email: email, p_idempotency_key: key,
  });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return failure(mapError(error?.message));
  const invitation = data as Record<string, unknown>;
  if (invitation.state === 'already_member') return failure('already-member');
  if (invitation.created !== true) return failure(invitation.state === 'pending_exists' ? 'pending-exists' : 'existing');
  const sent = await deliverMemberInvitation(supabase, invitation);
  redirect(isUuid(employeeId) ? `/tenant/${tenantId}/people/${employeeId}?userLink=${sent === 'sent' ? 'invite-sent' : sent === 'failed' ? 'invite-failed' : 'invite-unknown'}`
    : `/tenant/${tenantId}/users?state=created-${sent}`);
}

export async function inviteMemberAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const email = field(formData, 'email').toLowerCase();
  const key = field(formData, 'idempotencyKey');
  if (!isUuid(tenantId) || !isUuid(key) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) go(tenantId, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data, error } = await supabase.rpc('create_tenant_member_invitation', {
    p_tenant_id: tenantId, p_target_email: email, p_idempotency_key: key,
  });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) go(tenantId, mapError(error?.message));
  const invitation = data as Record<string, unknown>;
  if (invitation.state === 'already_member') go(tenantId, 'already-member');
  if (invitation.created !== true) go(tenantId, invitation.state === 'pending_exists' ? 'pending-exists' : 'existing');
  const sent = await deliverMemberInvitation(supabase, invitation);
  go(tenantId, `created-${sent}`);
}

export async function reissueMemberInvitationAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const invitationId = field(formData, 'invitationId');
  if (!isUuid(tenantId) || !isUuid(invitationId)) go(tenantId, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data, error } = await supabase.rpc('reissue_tenant_member_invitation', { p_invitation_id: invitationId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) go(tenantId, mapError(error?.message));
  const invitation = data as Record<string, unknown>;
  if (invitation.created !== true) go(tenantId, invitation.state === 'expired' ? 'expired' : 'terminal');
  go(tenantId, `reissued-${await deliverMemberInvitation(supabase, invitation)}`);
}

export async function revokeMemberInvitationAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const invitationId = field(formData, 'invitationId');
  if (!isUuid(tenantId) || !isUuid(invitationId)) go(tenantId, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { error } = await supabase.rpc('revoke_tenant_member_invitation', { p_invitation_id: invitationId });
  go(tenantId, error ? mapError(error.message) : 'revoked');
}

export async function setMemberAccessAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const userId = field(formData, 'userId');
  const state = field(formData, 'accessState');
  if (!isUuid(tenantId) || !isUuid(userId) || (state !== 'active' && state !== 'inactive')) go(tenantId, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { error } = await supabase.rpc('set_tenant_member_access', {
    p_tenant_id: tenantId, p_user_id: userId, p_access_state: state,
  });
  go(tenantId, error ? mapError(error.message) : state === 'active' ? 'reactivated' : 'deactivated');
}

export async function setTenantMemberPeopleBundlesAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const userId = field(formData, 'userId');
  const bundleKeys = formData.getAll('bundleKey').map((value) => String(value));
  if (!isUuid(tenantId) || !isUuid(userId) || bundleKeys.length > 9) go(tenantId, 'bundle-invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data, error } = await supabase.rpc('set_tenant_member_people_bundles', {
    p_tenant_id: tenantId, p_user_id: userId, p_bundle_keys: bundleKeys,
  });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) go(tenantId, mapError(error?.message));
  const state = (data as Record<string, unknown>).state;
  go(tenantId, state === 'updated' ? 'bundles-updated' : state === 'unchanged' ? 'bundles-unchanged' : 'failed');
}

export async function setProtectedAdminLeaveSelfAccessAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const userId = field(formData, 'userId');
  const enabled = field(formData, 'enabled');
  if (!isUuid(tenantId) || !isUuid(userId) || !['true', 'false'].includes(enabled)) go(tenantId, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { error } = await supabase.rpc('set_tenant_member_leave_self_access', {
    p_tenant_id: tenantId, p_user_id: userId, p_enabled: enabled === 'true',
  });
  if (error) go(tenantId, error.message.includes('tenant_members_manage_forbidden') ? 'forbidden' : 'failed');
  go(tenantId, 'leave-self-updated');
}

export async function changeTenantAdminRoleAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const userId = field(formData, 'userId');
  const action = field(formData, 'roleAction');
  if (!isUuid(tenantId) || !isUuid(userId) || (action !== 'promote' && action !== 'demote')) go(tenantId, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data: { user } } = await supabase.auth.getUser();
  const { data, error } = await supabase.rpc('change_tenant_admin_role', {
    p_tenant_id: tenantId, p_user_id: userId, p_action: action,
  });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    go(tenantId, mapError(error?.message));
  }
  const state = (data as Record<string, unknown>).state;
  const allowedStates = ['promoted', 'demoted', 'already_admin', 'already_member'];
  if (action === 'demote' && user?.id === userId && state === 'demoted') {
    redirect(`/tenant/${tenantId}?state=admin-demoted`);
  }
  go(tenantId, typeof state === 'string' && allowedStates.includes(state) ? state : 'failed');
}

async function deliverMemberInvitation(supabase: NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>,
  invitation: Record<string, unknown>): Promise<'sent' | 'failed' | 'unknown'> {
  const admin = createSupabaseAdminClient();
  const { data: { user } } = await supabase.auth.getUser();
  const originValue = process.env.NEXT_PUBLIC_APP_URL;
  const callback = isUuid(invitation.id) && typeof invitation.issuance === 'number' && originValue
    ? callbackUrl(originValue, invitation.id, invitation.issuance) : null;
  let sent = false;
  let errorCode = !admin ? 'admin_auth_not_configured' : !callback ? 'app_origin_not_configured' : 'auth_invite_failed';
  if (admin && callback && user && typeof invitation.target_email === 'string') {
    const { error } = await admin.auth.admin.inviteUserByEmail(invitation.target_email, {
      data: { membership_invitation_id: invitation.id, issuance: invitation.issuance }, redirectTo: callback,
    });
    if (!error) sent = true;
    else if (isExistingUser(error.code, error.message)) {
      const { error: otpError } = await admin.auth.signInWithOtp({
        email: invitation.target_email, options: { shouldCreateUser: false, emailRedirectTo: callback },
      });
      sent = !otpError;
      errorCode = safeCode(otpError?.code ?? otpError?.name ?? error.code);
    } else errorCode = safeCode(error.code ?? error.name);
  }
  if (!admin || !user) return 'unknown';
  const { error: recordError } = await admin.rpc('record_tenant_member_invitation_delivery', {
    p_invitation_id: invitation.id, p_issuance: invitation.issuance, p_actor_user_id: user.id, p_succeeded: sent,
    p_error_code: sent ? null : errorCode,
  });
  if (recordError) return 'unknown';
  return sent ? 'sent' : 'failed';
}

function callbackUrl(appUrl: string, invitationId: string, issuance: number) {
  try {
    const origin = new URL(appUrl);
    if (origin.protocol !== 'https:' && !['localhost', '127.0.0.1'].includes(origin.hostname)) return null;
    const callback = new URL('/auth/membership-invitations/callback', origin);
    callback.searchParams.set('invitation_id', invitationId);
    callback.searchParams.set('issuance', String(issuance));
    return callback.toString();
  } catch { return null; }
}

function isExistingUser(code: string | undefined, message: string) {
  return ['email_exists', 'user_already_exists', 'already_registered'].includes(code ?? '')
    || /already\s+(registered|exists)/i.test(message);
}
function safeCode(value: unknown) { return typeof value === 'string' && /^[a-z0-9_-]{1,80}$/i.test(value) ? value : 'auth_invite_failed'; }
function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: unknown): value is string { return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function mapError(message?: string) {
  if (message?.includes('tenant_member_limit_full')) return 'limit-full';
  if (message?.includes('tenant_member_admin_requires_governed_change')) return 'admin-governed';
  if (message?.includes('tenant_member_invite_issuer_authority_lost')) return 'issuer-lost';
  if (message?.includes('tenant_member_target_unavailable')) return 'target-unavailable';
  if (message?.includes('tenant_member_invite_idempotency_conflict')) return 'key-conflict';
  if (message?.includes('tenant_admin_role_forbidden')) return 'role-forbidden';
  if (message?.includes('tenant_admin_last_recoverable')) return 'last-admin';
  if (message?.includes('tenant_admin_role_target_unavailable')) return 'target-unavailable';
  if (message?.includes('tenant_admin_role_tenant_unavailable')) return 'tenant-unavailable';
  if (message?.includes('tenant_admin_role_template_unavailable') || message?.includes('tenant_member_role_template_unavailable')) return 'role-setup';
  if (message?.includes('tenant_people_role_bundle_admin_protected')) return 'bundle-admin-protected';
  if (message?.includes('tenant_people_role_bundle_target_unavailable')) return 'bundle-target-unavailable';
  if (message?.includes('tenant_people_role_bundle_unknown') || message?.includes('tenant_people_role_bundle_input_invalid')) return 'bundle-invalid';
  if (message?.includes('tenant_people_role_bundle_catalog_unavailable')) return 'role-setup';
  if (message?.includes('tenant_people_role_bundle_tenant_unavailable')) return 'tenant-unavailable';
  if (message?.includes('tenant_members_manage_forbidden')) return 'forbidden';
  return 'failed';
}
function inviteErrorText(code: string) {
  const messages: Record<string, string> = {
    invalid: 'راجع البريد الإلكتروني وأعد المحاولة.',
    setup: 'خدمة الدعوات غير متاحة الآن. أعد المحاولة لاحقًا.',
    'already-member': 'هذا الشخص عضو بالفعل في الشركة.',
    'pending-exists': 'توجد دعوة معلقة لهذا البريد. راجع الدعوات لإعادة إرسالها.',
    existing: 'توجد دعوة سابقة لهذا البريد. راجع قائمة الدعوات.',
    'limit-full': 'اكتمل حد المستخدمين النشطين. راجع الاشتراك أو عطّل حسابًا غير مستخدم.',
    'issuer-lost': 'لم تعد لديك صلاحية إرسال الدعوات. حدّث الصفحة أو راجع مدير الشركة.',
    'target-unavailable': 'لا يمكن دعوة هذا البريد حاليًا.',
    'key-conflict': 'تعذر إكمال المحاولة السابقة. حدّث الصفحة وأعد المحاولة.',
    forbidden: 'ليس لديك صلاحية إرسال الدعوات.',
  };
  return messages[code] ?? 'تعذر إرسال الدعوة. أعد المحاولة.';
}
function go(tenantId: string, state: string): never {
  redirect(isUuid(tenantId) ? `/tenant/${tenantId}/users?state=${encodeURIComponent(state)}` : '/auth/login?state=invalid');
}
