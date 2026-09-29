import Link from 'next/link';
import { signOutAction } from '@/app/auth/actions';
import { verifyInvitationLinkAction } from './actions';
import { SubmitButton } from '@/components/submit-button';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{
  token_hash?: string;
  type?: string;
  invitation_id?: string;
  issuance?: string;
  state?: string;
}>;

export default async function InvitationCallbackPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const valid = /^[a-zA-Z0-9_-]{16,512}$/.test(params.token_hash ?? '')
    && (params.type === 'invite' || params.type === 'email')
    && isUuid(params.invitation_id ?? '')
    && /^[1-9]\d{0,8}$/.test(params.issuance ?? '');

  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="auth-card" aria-labelledby="callback-title">
        <p className="eyebrow">دعوة مسؤول الشركة</p>
        <h1 id="callback-title">تابع قبول الدعوة</h1>
        {valid ? (
          <>
            <p className="intro">اضغط للمتابعة والتحقق من الرابط. لن تُنشأ الشركة قبل تأكيدك في الخطوة التالية.</p>
            <form className="auth-form" action={verifyInvitationLinkAction}>
              <input type="hidden" name="tokenHash" value={params.token_hash} />
              <input type="hidden" name="type" value={params.type} />
              <input type="hidden" name="invitationId" value={params.invitation_id} />
              <input type="hidden" name="issuance" value={params.issuance} />
              <SubmitButton label="التحقق والمتابعة" pendingLabel="جارٍ التحقق…" />
            </form>
          </>
        ) : (
          <p className="intro" role="alert">{stateMessage(params.state)}</p>
        )}
      </section>
      <footer className="footer">منصة الأعمال · متابعة آمنة للدعوة</footer>
    </main>
  );
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function stateMessage(state?: string) {
  const labels: Record<string, string> = {
    invalid: 'رابط الدعوة غير مكتمل. افتح أحدث رسالة وصلتك.',
    'link-expired': 'تعذر استخدام رابط التفعيل. إذا كانت الدعوة ضمن الأيام السبعة، اطلب من مشغّل المنصة إصدار رابط جديد.',
    setup: 'إعداد خدمة الحسابات غير مكتمل. أعد المحاولة لاحقًا.',
  };
  return labels[state ?? ''] ?? 'تعذر التحقق من رابط الدعوة.';
}
