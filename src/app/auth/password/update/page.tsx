import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { updatePasswordAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
export const dynamic = 'force-dynamic';
const messages: Record<string, string> = {
  invalid: 'تأكد من تطابق كلمتي المرور وأنهما لا تقلان عن 8 أحرف.',
  failed: 'تعذر تأكيد تحديث كلمة المرور. أعد المحاولة، أو اطلب رابط استعادة جديدًا.',
};
export default async function UpdatePasswordPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const { state } = await searchParams;
  const message = state && Object.hasOwn(messages, state) ? messages[state] : undefined;
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = supabase ? await supabase.auth.getUser() : { data: { user: null } };
  if (!user) return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><section className="auth-card"><h1>الرابط غير صالح</h1><p className="intro">افتح رابط الاستعادة من بريدك أو اطلب رابطًا جديدًا.</p><a className="primary-button link-button" href="/auth/forgot-password">طلب رابط جديد</a></section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><section className="auth-card" aria-labelledby="update-title"><p className="eyebrow">استعادة الوصول</p><h1 id="update-title">اختر كلمة مرور جديدة</h1>{message && <p className="form-message" role="alert">{message}</p>}<OfflineForm action={updatePasswordAction} className="auth-form"><label htmlFor="password">كلمة المرور الجديدة</label><input id="password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr" /><label htmlFor="confirmation">تأكيد كلمة المرور</label><input id="confirmation" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr" /><OfflineSubmitButton label="حفظ كلمة المرور" pendingLabel="جارٍ الحفظ…" /></OfflineForm>{state === 'failed' && <p className="auth-links"><Link href="/auth/forgot-password">طلب رابط استعادة جديد</Link></p>}</section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
}
