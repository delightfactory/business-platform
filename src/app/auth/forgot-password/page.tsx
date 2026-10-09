import { Panel, PageHeader } from '@/components/ui';
import { Message, ButtonLink } from '@/components/ui';
import { Input } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { requestPasswordResetAction } from '@/app/auth/actions';
export const dynamic = 'force-dynamic';
export default async function ForgotPasswordPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const { state } = await searchParams;
  const sent = state === 'sent';
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><Panel className="auth-card" aria-labelledby="forgot-title"><p className="eyebrow">استعادة الوصول</p><PageHeader id="forgot-title" title={<>إعادة تعيين كلمة المرور</>} /><p className="intro">أدخل بريد الحساب. إذا كان مرتبطًا بحساب، سنرسل رابطًا لإعادة التعيين.</p>{sent ? <Message tone="info"  role="status">إذا كان البريد مرتبطًا بحساب، فسيصلك رابط إعادة التعيين قريبًا.</Message> : state === 'expired' ? <Message tone="info"  role="alert">انتهت صلاحية الرابط أو تعذر التحقق منه. اطلب رابطًا جديدًا.</Message> : <OfflineForm action={requestPasswordResetAction} className="auth-form"><label htmlFor="email">البريد الإلكتروني</label><Input id="email" name="email" type="email" autoComplete="email" required maxLength={254} dir="ltr" /><OfflineSubmitButton label="إرسال رابط الاستعادة" pendingLabel="جارٍ الإرسال…" /></OfflineForm>}{(sent || state === 'expired') && <ButtonLink variant="solid" className="link-button" href="/auth/forgot-password">{sent ? 'طلب رابط آخر' : 'طلب رابط جديد'}</ButtonLink>}<p className="auth-links"><a href="/auth/login">العودة إلى تسجيل الدخول</a></p></Panel></main>;
}
