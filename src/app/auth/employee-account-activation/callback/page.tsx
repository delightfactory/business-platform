import { Panel, PageHeader } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { verifyEmployeeAccountActivationAction } from '../actions';

export const dynamic = 'force-dynamic';
type Search = Promise<{ token_hash?: string; type?: string; intent_id?: string; state?: string }>;

export default async function EmployeeAccountActivationCallbackPage({ searchParams }: { searchParams: Search }) {
  const query = await searchParams;
  const valid = /^[a-zA-Z0-9_-]{16,512}$/.test(query.token_hash ?? '')
    && (query.type === 'invite' || query.type === 'email' || query.type === 'magiclink') && isUuid(query.intent_id ?? '');
  const message = query.state === 'expired' ? 'انتهت صلاحية الرابط. اطلب من الموارد البشرية إعادة إرساله.'
    : query.state === 'identity' ? 'هذا الرابط لا يطابق عملية التفعيل. استخدم الرابط المرسل لهذا الحساب.'
      : query.state ? 'تعذر التحقق من الرابط. افتح أحدث رسالة وصلتك.' : 'تحقق من البريد للمتابعة وإعداد كلمة المرور.';
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link></header>
    <Panel className="auth-card" aria-labelledby="activation-callback-title">
      <p className="eyebrow">تفعيل حساب الموظف</p><PageHeader id="activation-callback-title" title={<>تأكيد البريد والمتابعة</>} />
      <p className="intro" role={query.state ? 'alert' : undefined}>{message}</p>
      {valid && <OfflineForm className="auth-form" action={verifyEmployeeAccountActivationAction}>
        <input type="hidden" name="tokenHash" value={query.token_hash} /><input type="hidden" name="type" value={query.type} />
        <input type="hidden" name="intentId" value={query.intent_id} />
        <OfflineSubmitButton label="تأكيد البريد" pendingLabel="جارٍ التحقق…" />
      </OfflineForm>}
    </Panel></main>;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
