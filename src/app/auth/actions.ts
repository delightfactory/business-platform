'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function signInAction(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const next = safeTenantNext(String(formData.get('next') ?? ''));
  const returnTo = next ? `&next=${encodeURIComponent(next)}` : '';
  if (!email || !password) redirect(`/auth/login?state=invalid${returnTo}`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`/auth/login?state=setup${returnTo}`);
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) redirect(`/auth/login?state=invalid${returnTo}`);
  if (next) redirect(next);
  const { data: memberships } = await supabase.rpc('current_tenant_spaces');
  if (Array.isArray(memberships) && memberships.length === 1) {
    const tenantId = (memberships[0] as Record<string, unknown>).tenant_id;
    if (typeof tenantId === 'string' && /^[0-9a-f-]{36}$/i.test(tenantId)) redirect(`/tenant/${tenantId}`);
  }
  if (Array.isArray(memberships) && memberships.length > 1) redirect('/tenant/select');
  redirect('/operator');
}

function safeTenantNext(value: string) {
  const tenantPath = /^\/tenant\/[0-9a-f-]{36}(?:\/users)?$/i;
  const invitationPath = /^\/auth\/(?:membership-)?invitations\/accept\?id=[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}&issuance=\d+$/i;
  return tenantPath.test(value) || invitationPath.test(value) ? value : null;
}

export async function requestPasswordResetAction(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim();
  const supabase = await createSupabaseServerClient();
  const appUrl = process.env.NEXT_PUBLIC_APP_URL;
  if (supabase && appUrl && email) {
    try {
      const origin = new URL(appUrl);
      if (origin.protocol === 'https:' || ['localhost', '127.0.0.1'].includes(origin.hostname)) {
        await supabase.auth.resetPasswordForEmail(email, {
          redirectTo: new URL('/auth/callback', origin).toString(),
        });
      }
    } catch { /* Keep the response uniform to avoid disclosing account existence. */ }
  }
  redirect('/auth/forgot-password?state=sent');
}

export async function updatePasswordAction(formData: FormData) {
  const password = String(formData.get('password') ?? '');
  const confirmation = String(formData.get('confirmation') ?? '');
  if (password.length < 8 || password !== confirmation) redirect('/auth/password/update?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect('/auth/login?state=setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/forgot-password?state=expired');
  const { error } = await supabase.auth.updateUser({ password });
  if (error) redirect('/auth/password/update?state=failed');
  await supabase.auth.signOut({ scope: 'local' });
  redirect('/auth/login?state=updated');
}

export async function signOutAction() {
  const supabase = await createSupabaseServerClient();
  if (supabase) await supabase.auth.signOut({ scope: 'local' });
  redirect('/auth/login?state=signed-out');
}
