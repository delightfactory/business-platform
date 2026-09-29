'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

export async function setInvitationPasswordAction(formData: FormData) {
  const invitationId = field(formData, 'invitationId');
  const issuance = field(formData, 'issuance');
  const password = String(formData.get('password') ?? '');
  if (!isUuid(invitationId) || !/^\d+$/.test(issuance) || password.length < 8) {
    redirect(`/auth/invitations/accept?id=${encodeURIComponent(invitationId)}&issuance=${encodeURIComponent(issuance)}&state=password`);
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/auth/invitations/accept?state=setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/invitations/accept?state=no-session');
  const { data: validation, error: validationError } = await supabase.rpc('validate_tenant_admin_invitation', {
    p_invitation_id: invitationId,
    p_issuance: Number(issuance),
  });
  if (validationError || validation !== 'password_required') redirect('/auth/invitations/accept?state=unavailable');
  const { error } = await supabase.auth.updateUser({ password });
  if (error) redirect(`/auth/invitations/accept?id=${encodeURIComponent(invitationId)}&issuance=${issuance}&state=password`);
  const admin = createSupabaseAdminClient();
  if (!admin) redirect(`/auth/invitations/accept?id=${encodeURIComponent(invitationId)}&issuance=${issuance}&state=password-marker-failed`);
  const { error: markerError } = await admin.rpc('record_tenant_admin_password_readiness', {
    p_invitation_id: invitationId,
    p_issuance: Number(issuance),
    p_user_id: user.id,
  });
  if (markerError) redirect(`/auth/invitations/accept?id=${encodeURIComponent(invitationId)}&issuance=${issuance}&state=password-marker-failed`);
  redirect(`/auth/invitations/accept?id=${encodeURIComponent(invitationId)}&issuance=${issuance}&state=password-set`);
}

export async function acceptInvitationAction(formData: FormData) {
  const invitationId = field(formData, 'invitationId');
  const issuance = field(formData, 'issuance');
  if (!isUuid(invitationId) || !/^\d+$/.test(issuance)) redirect('/auth/invitations/accept?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/auth/invitations/accept?state=setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/invitations/accept?state=no-session');
  const { data: result, error } = await supabase.rpc('accept_tenant_admin_invitation', {
    p_invitation_id: invitationId,
    p_issuance: Number(issuance),
  });
  if (error) {
    const state = error.message.includes('issuer_authority_lost') ? 'issuer-lost'
      : error.message.includes('identity_mismatch') ? 'identity'
      : error.message.includes('expired') ? 'expired'
      : error.message.includes('stale_issuance') ? 'superseded'
      : error.message.includes('password_required') ? 'password'
      : error.message.includes('identity_unverified') ? 'unverified'
      : 'accept-failed';
    redirect(`/auth/invitations/accept?id=${encodeURIComponent(invitationId)}&issuance=${issuance}&state=${state}`);
  }
  if (!result || typeof result !== 'object' || Array.isArray(result)) redirect('/auth/invitations/accept?state=accept-failed');
  const accepted = result as Record<string, unknown>;
  const tenantId = typeof accepted.tenant_id === 'string' ? accepted.tenant_id : '';
  if (!isUuid(tenantId)) redirect('/auth/invitations/accept?state=accept-failed');
  redirect(`/tenant/${encodeURIComponent(tenantId)}`);
}

function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
