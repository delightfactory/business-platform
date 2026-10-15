import { Field, Panel, PageHeader } from '@/components/ui';
import { Message } from '@/components/ui';
import { Input } from '@/components/ui';
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
  if (!user) return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><Panel className="auth-card"><PageHeader  title={<>الرابط غير صالح</>} /><p className="intro">افتح رابط الاستعادة من بريدك أو اطلب رابطًا جديدًا.</p><a className="primary-button link-button" href="/auth/forgot-password">طلب رابط جديد</a></Panel></main>;
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header><Panel className="auth-card" aria-labelledby="update-title"><p className="eyebrow">استعادة الوصول</p><PageHeader id="update-title" title={<>اختر كلمة مرور جديدة</>} />{message && <Message tone="info"  role="alert">{message}</Message>}<OfflineForm action={updatePasswordAction} className="auth-form"><Field id="password" label="كلمة المرور الجديدة" help="اختر كلمة مرور من 8 أحرف على الأقل، واستخدمها لهذا الحساب."><Input id="password" name="password" type="password" autoComplete="new-password" minLength={8} required dir="ltr"  /></Field><Field id="confirmation" label="تأكيد كلمة المرور" help="أعد كتابة كلمة المرور نفسها للتأكد من تطابقها."><Input id="confirmation" name="confirmation" type="password" autoComplete="new-password" minLength={8} required dir="ltr"  /></Field><OfflineSubmitButton label="حفظ كلمة المرور" pendingLabel="جارٍ الحفظ…" /></OfflineForm>{state === 'failed' && <p className="auth-links"><Link href="/auth/forgot-password">طلب رابط استعادة جديد</Link></p>}</Panel></main>;
}
