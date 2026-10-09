import { Panel, PageHeader } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { verifyMemberInvitationAction } from './actions';

export const dynamic = 'force-dynamic';
type Search = Promise<{ token_hash?: string; type?: string; invitation_id?: string; issuance?: string; state?: string }>;

export default async function MemberInvitationCallbackPage({ searchParams }: { searchParams: Search }) {
  const query = await searchParams;
  const valid = /^[a-zA-Z0-9_-]{16,512}$/.test(query.token_hash ?? '')
    && (query.type === 'invite' || query.type === 'email')
    && isUuid(query.invitation_id ?? '') && /^[1-9]\d{0,8}$/.test(query.issuance ?? '');
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header>
      <Panel className="auth-card" aria-labelledby="callback-title">
        <p className="eyebrow">دعوة عضو</p>
        <PageHeader id="callback-title" title={<>تابع الانضمام للشركة</>} />
        {valid ? <>
          <p className="intro">اضغط للمتابعة والتحقق من الرابط. لن تُحتسب عضوية أو مقعد قبل قبولك.</p>
          <OfflineForm className="auth-form" action={verifyMemberInvitationAction}>
            <input type="hidden" name="tokenHash" value={query.token_hash} />
            <input type="hidden" name="type" value={query.type} />
            <input type="hidden" name="invitationId" value={query.invitation_id} />
            <input type="hidden" name="issuance" value={query.issuance} />
            <OfflineSubmitButton label="التحقق والمتابعة" pendingLabel="جارٍ التحقق…" />
          </OfflineForm>
        </> : <p className="intro" role="alert">{query.state === 'expired' ? 'انتهت صلاحية الرابط. اطلب إعادة إرسال الدعوة.' : 'رابط الدعوة غير مكتمل. افتح أحدث رسالة وصلتك.'}</p>}
      </Panel>
    </main>
  );
}
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
