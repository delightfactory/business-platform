import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { signInAction } from '@/app/auth/actions';
import { safeAuthNext } from '../safe-next';

export const dynamic = 'force-dynamic';

const messages: Record<string, string> = {
  invalid: 'تعذر تسجيل الدخول. تحقق من البريد الإلكتروني وكلمة المرور.',
  setup: 'الدخول غير متاح مؤقتًا. أعد المحاولة لاحقًا أو تواصل مع مسؤول المنصة.',
  'no-session': 'انتهت الجلسة. سجّل الدخول للمتابعة.',
  updated: 'تم تحديث كلمة المرور. سجّل الدخول بكلمتك الجديدة.',
  'signed-out': 'تم تسجيل الخروج.',
  'operator-revoked': 'سُحبت صلاحية تشغيل المنصة من هذا الحساب وسُجّل الخروج. لم تتغير عضويات الشركات.',
};

type SearchParams = Promise<{ state?: string; next?: string }>;

export default async function LoginPage({ searchParams }: { searchParams: SearchParams }) {
  const { state, next: requestedNext } = await searchParams;
  const next = safeAuthNext(requestedNext ?? '');
  const message = state && Object.hasOwn(messages, state) ? messages[state] : undefined;

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <span className="environment-pill"><span aria-hidden="true" /> بيئة التطوير</span>
      </header>
      <section className="auth-card" aria-labelledby="login-title">
        <p className="eyebrow">الدخول إلى المنصة</p>
        <h1 id="login-title">تسجيل الدخول</h1>
        <p className="intro">استخدم البريد الإلكتروني وكلمة المرور المرتبطين بحسابك.</p>
        {message && <p className="form-message" role="status">{message}</p>}
        <OfflineForm action={signInAction} className="auth-form">
          <input type="hidden" name="next" value={next} />
          <label htmlFor="email">البريد الإلكتروني</label>
          <input id="email" name="email" type="email" autoComplete="username" required maxLength={254} dir="ltr" />
          <label htmlFor="password">كلمة المرور</label>
          <input id="password" name="password" type="password" autoComplete="current-password" required minLength={8} dir="ltr" />
          <OfflineSubmitButton label="دخول" pendingLabel="جارٍ الدخول…" />
        </OfflineForm>
        <p className="auth-links"><Link href="/auth/forgot-password">نسيت كلمة المرور؟</Link></p>
        <p className="foundation-note">إنشاء الحسابات غير متاح من هذه الصفحة.</p>
      </section>
      <footer className="footer">منصة الأعمال · أساس التطوير</footer>
    </main>
  );
}
