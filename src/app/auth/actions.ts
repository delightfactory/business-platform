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
  redirect(next ?? '/operator');
}

function safeTenantNext(value: string) {
  return /^\/tenant\/[0-9a-f-]{36}$/i.test(value) ? value : null;
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
