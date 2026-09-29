import Link from 'next/link';
import { updatePasswordAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { SubmitButton } from '@/components/submit-button';
export const dynamic = 'force-dynamic';
export default async function UpdatePasswordPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const { state } = await searchParams;
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = supabase ? await supabase.auth.getUser() : { data: { user: null } };
  if (!user) return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><section className="auth-card"><h1>الرابط غير صالح</h1><p className="intro">افتح رابط الاستعادة من بريدك أو اطلب رابطًا جديدًا.</p><a className="primary-button link-button" href="/auth/forgot-password">طلب رابط جديد</a></section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><section className="auth-card" aria-labelledby="update-title"><p className="eyebrow">استعادة الوصول</p><h1 id="update-title">اختر كلمة مرور جديدة</h1>{state && <p className="form-message" role="alert">تعذر تحديث كلمة المرور. تأكد من تطابق الحقلين وأنها لا تقل عن 8 أحرف.</p>}<form action={updatePasswordAction} className="auth-form"><label htmlFor="password">كلمة المرور الجديدة</label><input id="password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr" /><label htmlFor="confirmation">تأكيد كلمة المرور</label><input id="confirmation" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr" /><SubmitButton label="حفظ كلمة المرور" pendingLabel="جارٍ الحفظ…" /></form></section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
}
