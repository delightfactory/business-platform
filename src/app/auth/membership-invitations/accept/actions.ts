'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

export async function setMemberInvitationPasswordAction(formData: FormData) {
  const id = field(formData, 'invitationId'); const issuance = field(formData, 'issuance'); const password = String(formData.get('password') ?? '');
  if (!isUuid(id) || !/^\d+$/.test(issuance) || password.length < 8) go(id, issuance, 'password');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(id, issuance, 'setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) go(id, issuance, 'no-session');
  const { data: ready, error: validationError } = await supabase.rpc('validate_tenant_member_invitation', { p_invitation_id: id, p_issuance: Number(issuance) });
  if (validationError || ready !== 'password_required') go(id, issuance, 'unavailable');
  const { error } = await supabase.auth.updateUser({ password });
  if (error) go(id, issuance, 'password');
  const admin = createSupabaseAdminClient();
  if (!admin) go(id, issuance, 'marker-failed');
  const { error: markerError } = await admin.rpc('record_tenant_member_password_readiness', {
    p_invitation_id: id, p_issuance: Number(issuance), p_user_id: user.id,
  });
  if (markerError) go(id, issuance, 'marker-failed');
  go(id, issuance, 'password-set');
}

export async function acceptMemberInvitationAction(formData: FormData) {
  const id = field(formData, 'invitationId'); const issuance = field(formData, 'issuance');
  if (!isUuid(id) || !/^\d+$/.test(issuance)) go(id, issuance, 'invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(id, issuance, 'setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) go(id, issuance, 'no-session');
  const { data, error } = await supabase.rpc('accept_tenant_member_invitation', { p_invitation_id: id, p_issuance: Number(issuance) });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    const message = error?.message ?? '';
    const state = message.includes('limit_full') ? 'limit-full' : message.includes('issuer_authority_lost') ? 'issuer-lost'
      : message.includes('identity_mismatch') ? 'identity' : message.includes('identity_unverified') ? 'unverified'
      : message.includes('target_unavailable') ? 'target-unavailable'
      : message.includes('password_required') ? 'password' : message.includes('stale_issuance') ? 'superseded'
      : message.includes('tenant_unavailable') ? 'tenant-unavailable' : 'unavailable';
    go(id, issuance, state);
  }
  const result = data as Record<string, unknown>;
  const tenantId = typeof result.tenant_id === 'string' ? result.tenant_id : '';
  if (!isUuid(tenantId)) go(id, issuance, 'unavailable');
  redirect(`/tenant/${tenantId}`);
}

function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function go(id: string, issuance: string, state: string): never { redirect(isUuid(id) ? `/auth/membership-invitations/accept?id=${id}&issuance=${encodeURIComponent(issuance)}&state=${state}` : '/auth/login?state=invalid'); }
