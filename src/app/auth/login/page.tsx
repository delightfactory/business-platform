import { Panel, PageHeader } from '@/components/ui';
import { Message } from '@/components/ui';
import { Input } from '@/components/ui';
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

      </header>
      <Panel className="auth-card" aria-labelledby="login-title">
        <p className="eyebrow">الدخول إلى المنصة</p>
        <PageHeader id="login-title" title={<>تسجيل الدخول</>} />
        <p className="intro">استخدم البريد الإلكتروني وكلمة المرور المرتبطين بحسابك.</p>
        {message && <Message tone="info"  role="status">{message}</Message>}
        <OfflineForm action={signInAction} className="auth-form">
          <input type="hidden" name="next" value={next} />
          <label htmlFor="email">البريد الإلكتروني</label>
          <Input id="email" name="email" type="email" autoComplete="username" required maxLength={254} dir="ltr" />
          <label htmlFor="password">كلمة المرور</label>
          <Input id="password" name="password" type="password" autoComplete="current-password" required minLength={8} dir="ltr" />
          <OfflineSubmitButton label="دخول" pendingLabel="جارٍ الدخول…" />
        </OfflineForm>
        <p className="auth-links"><Link href="/auth/forgot-password">نسيت كلمة المرور؟</Link></p>
        <p className="foundation-note">إنشاء الحسابات غير متاح من هذه الصفحة.</p>
      </Panel>

    </main>
  );
}
