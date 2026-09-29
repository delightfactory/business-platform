import Link from 'next/link';
import { requestPasswordResetAction } from '@/app/auth/actions';
export const dynamic = 'force-dynamic';
export default async function ForgotPasswordPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const { state } = await searchParams;
  const sent = state === 'sent';
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><section className="auth-card" aria-labelledby="forgot-title"><p className="eyebrow">استعادة الوصول</p><h1 id="forgot-title">إعادة تعيين كلمة المرور</h1><p className="intro">أدخل بريد الحساب. إذا كان مرتبطًا بحساب، سنرسل رابطًا لإعادة التعيين.</p>{sent ? <p className="form-message" role="status">إذا كان البريد مرتبطًا بحساب، فسيصلك رابط إعادة التعيين قريبًا.</p> : state === 'expired' ? <p className="form-message" role="alert">انتهت صلاحية الرابط أو تعذر التحقق منه. اطلب رابطًا جديدًا.</p> : <form action={requestPasswordResetAction} className="auth-form"><label htmlFor="email">البريد الإلكتروني</label><input id="email" name="email" type="email" autoComplete="email" required maxLength={254} dir="ltr" /><button className="primary-button" type="submit">إرسال رابط الاستعادة</button></form>}<p className="auth-links"><a href="/auth/login">العودة إلى تسجيل الدخول</a></p></section><footer className="footer">منصة الأعمال · أساس التطوير</footer></main>;
}
