import { PageHeader } from '@/components/ui';
import { Panel, Message } from '@/components/ui';
import { Button, ButtonLink, Input } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { acceptInvitationAction, setInvitationPasswordAction } from './actions';

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
  const passwordHint = ['password-set', 'password', 'password-marker-failed'].includes(params.state ?? '');

  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form>
      </header>
      <Panel  aria-labelledby="accept-title">
        <p className="eyebrow">إعداد حساب المسؤول</p>
        <PageHeader id="accept-title" title={<>أكمل إعداد حسابك</>} />
        <p className="intro">الدعوة مرتبطة بالبريد <bdi>{user.email}</bdi>. أنشئ مساحة الشركة بعد إكمال بيانات الحساب.</p>
        {passwordHint && <Message tone="info"  role="status">{needsPassword ? 'يحتاج هذا الحساب إلى إعداد كلمة المرور. استخدم ثمانية أحرف على الأقل ثم أكمل الخطوة أدناه.' : 'الحساب جاهز للخطوة التالية. يمكنك متابعة إنشاء مساحة الشركة.'}</Message>}
        {params.state && !passwordHint && <Message tone="info"  role="alert">{stateMessage(params.state)}</Message>}
        {needsPassword ? (
          <OfflineForm className="auth-form" action={setInvitationPasswordAction}>
            <input type="hidden" name="invitationId" value={invitationId} />
            <input type="hidden" name="issuance" value={issuance} />
            <label htmlFor="password">أنشئ كلمة مرور لحسابك</label>
            <Input id="password" name="password" type="password" autoComplete="new-password" minLength={8} required />
            <p className="field-hint">ثمانية أحرف على الأقل. لا تتغير كلمات مرور أي حسابات أخرى.</p>
            <OfflineSubmitButton label="حفظ كلمة المرور" pendingLabel="جارٍ الحفظ…" />
          </OfflineForm>
        ) : (
          <OfflineForm className="auth-form" action={acceptInvitationAction}>
            <input type="hidden" name="invitationId" value={invitationId} />
            <input type="hidden" name="issuance" value={issuance} />
            <p>سيبقى تسجيل الدخول الحالي وكلمة المرور كما هما.</p>
            <OfflineSubmitButton label="تأكيد الدعوة وإنشاء الشركة" pendingLabel="جارٍ إنشاء الشركة…" />
          </OfflineForm>
        )}
      </Panel>

    </main>
  );
}

function stateMessage(state?: string) {
  const labels: Record<string, string> = {
    invalid: 'تحقق من رابط الدعوة وحاول فتح الرابط الأخير الذي وصلك.',
    expired: 'انتهت صلاحية الدعوة. اطلب من مسؤول تشغيل المنصة إرسال دعوة جديدة.',
    superseded: 'أُصدر رابط أحدث وأصبح هذا الرابط غير صالح. استخدم آخر رسالة وصلتك.',
    unavailable: 'تعذر التحقق من الدعوة في الخطوة السابقة. راجع حالتها الحالية، أو اطلب من مسؤول تشغيل المنصة التحقق منها.',
    identity: 'هذا الرابط مرتبط ببريد آخر. افتح الدعوة من البريد المطابق.',
    unverified: 'يجب تأكيد البريد قبل إنشاء الشركة. افتح رابط الدعوة المرسل إلى بريدك.',
    'issuer-lost': 'تعذر إكمال الطلب لأن صلاحية المسؤول الذي أرسل الدعوة لم تعد نشطة. على مسؤول تشغيل المنصة صاحب الصلاحية إلغاء الطلب أو إنشاء دعوة جديدة.',
    'accept-failed': 'تعذر التأكد من إنشاء الشركة. اطلب من مسؤول تشغيل المنصة التحقق من حالة الدعوة قبل التأكيد مرة أخرى.',
    password: 'تعذر تأكيد حالة الحساب أو الدعوة الآن. اطلب من مسؤول تشغيل المنصة مراجعتها.',
    'password-marker-failed': 'تعذر تأكيد حالة الحساب أو الدعوة الآن. اطلب من مسؤول تشغيل المنصة مراجعتها.',
    'link-expired': 'انتهت صلاحية رابط التفعيل. إذا كانت الدعوة ضمن الأيام السبعة، اطلب من مسؤول تشغيل المنصة إصدار رابط جديد.',
    'no-session': 'انتهت جلسة الدعوة السابقة. تحقق من الحساب الحالي قبل المتابعة.',
    setup: 'تعذر إكمال الخطوة السابقة بسبب إعداد خدمة الحسابات. تحقق من الاتصال الحالي قبل المتابعة.',
  };
  return state && Object.hasOwn(labels, state) ? labels[state] : 'تعذر التحقق من الدعوة. اطلب من مسؤول تشغيل المنصة مراجعتها.';
}

function Status({ title, detail, link, linkText }: { title: string; detail: string; link?: string; linkText?: string }) {
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form>
      </header>
      <Panel className="auth-card"><p className="eyebrow">دعوة مسؤول الشركة</p><PageHeader  title={<>{title}</>} /><p className="intro">{detail}</p>
        {link && linkText && <ButtonLink variant="solid"  href={link}>{linkText}</ButtonLink>}
      </Panel>
    </main>
  );
}
