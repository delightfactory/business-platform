import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { acceptInvitationAction, setInvitationPasswordAction } from './actions';
import { SubmitButton } from '@/components/submit-button';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ id?: string; issuance?: string; state?: string }>;

export default async function InvitationAcceptancePage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const invitationId = params.id ?? '';
  const issuance = params.issuance ?? '';
  const validReference = /^[0-9a-f-]{36}$/i.test(invitationId) && /^\d+$/.test(issuance);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!validReference) return <Status title="رابط الدعوة غير صالح" detail={stateMessage(params.state)} link="/auth/login" linkText="العودة إلى الدخول" />;
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/auth/invitations/accept?id=${invitationId}&issuance=${issuance}`)}`);

  const { data: validation, error } = await supabase.rpc('validate_tenant_admin_invitation', {
    p_invitation_id: invitationId,
    p_issuance: Number(issuance),
  });
  if (error || (validation !== 'ready' && validation !== 'password_required')) {
    return <Status title="تعذر قبول هذه الدعوة" detail={stateMessage(validation === 'identity_mismatch' ? 'identity' : params.state ?? 'unavailable')} />;
  }
  const needsPassword = validation === 'password_required';

  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="work-card" aria-labelledby="accept-title">
        <p className="eyebrow">إعداد حساب المسؤول</p>
        <h1 id="accept-title">أكمل إعداد حسابك</h1>
        <p className="intro">الدعوة مرتبطة بالبريد <bdi>{user.email}</bdi>. أنشئ مساحة الشركة بعد إكمال بيانات الحساب.</p>
        {params.state === 'password-set' && <p className="form-message" role="status">تم حفظ كلمة المرور. يمكنك الآن إنشاء مساحة الشركة.</p>}
        {params.state && params.state !== 'password-set' && <p className="form-message" role="alert">{stateMessage(params.state)}</p>}
        {needsPassword ? (
          <form className="auth-form" action={setInvitationPasswordAction}>
            <input type="hidden" name="invitationId" value={invitationId} />
            <input type="hidden" name="issuance" value={issuance} />
            <label htmlFor="password">أنشئ كلمة مرور لحسابك</label>
            <input id="password" name="password" type="password" autoComplete="new-password" minLength={8} required />
            <p className="field-hint">ثمانية أحرف على الأقل. لا تتغير كلمات مرور أي حسابات أخرى.</p>
            <SubmitButton label="حفظ كلمة المرور" pendingLabel="جارٍ الحفظ…" />
          </form>
        ) : (
          <form className="auth-form" action={acceptInvitationAction}>
            <input type="hidden" name="invitationId" value={invitationId} />
            <input type="hidden" name="issuance" value={issuance} />
            <p>سيبقى تسجيل الدخول الحالي وكلمة المرور كما هما.</p>
            <SubmitButton label="تأكيد الدعوة وإنشاء الشركة" pendingLabel="جارٍ إنشاء الشركة…" />
          </form>
        )}
      </section>
      <footer className="footer">منصة الأعمال · دعوة مسؤول الشركة</footer>
    </main>
  );
}

function stateMessage(state?: string) {
  const labels: Record<string, string> = {
    invalid: 'تحقق من رابط الدعوة وحاول فتح الرابط الأخير الذي وصلك.',
    expired: 'انتهت صلاحية الدعوة. اطلب من مشغّل المنصة إرسال دعوة جديدة.',
    superseded: 'أُصدر رابط أحدث وأصبح هذا الرابط غير صالح. استخدم آخر رسالة وصلتك.',
    unavailable: 'الدعوة أُلغيت أو لم تعد صالحة. تواصل مع مشغّل المنصة لإصدار دعوة جديدة.',
    identity: 'هذا الرابط مرتبط ببريد آخر. افتح الدعوة من البريد المطابق.',
    unverified: 'يجب تأكيد البريد قبل إنشاء الشركة. افتح رابط الدعوة المرسل إلى بريدك.',
    'issuer-lost': 'تعذر إكمال الطلب لأن صلاحية مُصدر الدعوة لم تعد نشطة. على مشغّل مخوّل إلغاء الطلب أو إنشاء دعوة جديدة.',
    'accept-failed': 'لم تُنشأ الشركة. بيانات الدعوة محفوظة؛ حاول مرة أخرى أو اطلب من مشغّل المنصة مراجعتها.',
    password: 'تعذر حفظ كلمة المرور. اختر كلمة مرور من ثمانية أحرف على الأقل وحاول مجددًا.',
    'password-marker-failed': 'حُفظت كلمة المرور لكن لم يكتمل توثيق جاهزية الحساب. أعد المحاولة لتثبيت الحالة قبل إنشاء الشركة.',
    'link-expired': 'انتهت صلاحية رابط التفعيل. إذا كانت الدعوة ضمن الأيام السبعة، اطلب من مشغّل المنصة إصدار رابط جديد.',
    'no-session': 'انتهت جلسة الدعوة. افتح أحدث رابط وصلك في البريد.',
    setup: 'إعداد خدمة الحسابات غير مكتمل.',
  };
  return labels[state ?? ''] ?? 'تعذر التحقق من الدعوة. اطلب من مشغّل المنصة مراجعتها.';
}

function Status({ title, detail, link, linkText }: { title: string; detail: string; link?: string; linkText?: string }) {
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="auth-card"><p className="eyebrow">دعوة مسؤول الشركة</p><h1>{title}</h1><p className="intro">{detail}</p>
        {link && linkText && <Link className="primary-button" href={link}>{linkText}</Link>}
      </section>
    </main>
  );
}
