'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function verifyMemberInvitationAction(formData: FormData) {
  const tokenHash = String(formData.get('tokenHash') ?? '');
  const type = String(formData.get('type') ?? '');
  const invitationId = String(formData.get('invitationId') ?? '');
  const issuance = String(formData.get('issuance') ?? '');
  if (!/^[a-zA-Z0-9_-]{16,512}$/.test(tokenHash) || (type !== 'invite' && type !== 'email') || !isUuid(invitationId) || !/^[1-9]\d{0,8}$/.test(issuance)) {
    redirect('/auth/membership-invitations/callback?state=invalid');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/auth/membership-invitations/callback?state=setup');
  const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type });
  if (error) redirect(`/auth/membership-invitations/callback?invitation_id=${invitationId}&issuance=${issuance}&state=expired`);
  redirect(`/auth/membership-invitations/accept?id=${invitationId}&issuance=${issuance}`);
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
