import { signInAction } from '@/app/auth/actions';
import Link from 'next/link';

export const dynamic = 'force-dynamic';
const messages: Record<string, string> = {
  invalid: 'تعذر تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور.',
  setup: 'إعداد الاتصال غير مكتمل. أضف إعدادات Supabase إلى ملف البيئة.',
  'no-session': 'انتهت الجلسة. سجّل الدخول للمتابعة.',
  updated: 'تم تحديث كلمة المرور. سجّل الدخول بكلمتك الجديدة.',
  'signed-out': 'تم تسجيل الخروج.',
};
export default async function LoginPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const { state } = await searchParams;
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link><span className="environment-pill"><span aria-hidden="true" /> بيئة التطوير</span></header><section className="auth-card" aria-labelledby="login-title"><p className="eyebrow">الدخول إلى المنصة</p><h1 id="login-title">تسجيل الدخول</h1><p className="intro">استخدم البريد الإلكتروني وكلمة المرور المرتبطين بحسابك.</p>{state && messages[state] && <p className="form-message" role="status">{messages[state]}</p>}<form action={signInAction} className="auth-form"><label htmlFor="email">البريد الإلكتروني</label><input id="email" name="email" type="email" autoComplete="username" required maxLength={254} dir="ltr" /><label htmlFor="password">كلمة المرور</label><input id="password" name="password" type="password" autoComplete="current-password" required minLength={8} dir="ltr" /><button className="primary-button" type="submit">دخول</button></form><p className="auth-links"><Link href="/auth/forgot-password">نسيت كلمة المرور؟</Link></p><p className="foundation-note">إنشاء الحسابات غير متاح من هذه الصفحة.</p></section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
}
