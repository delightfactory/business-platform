import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { FeedbackToast } from '@/components/feedback-toast';
import { createInvitationAction, reissueInvitationAction, revokeInvitationAction } from './actions';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ id?: string; state?: string }>;
type InvitationRow = {
  id: string;
  target_email: string;
  tenant_name: string;
  lifecycle_state: string;
  delivery_state: string;
  issuance: number;
  expires_at: string;
  created_by_operator_id: string;
  tenant_id: string | null;
};

export default async function OperatorInvitationsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data: capable } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (!capable) return <Status title="إعداد الدعوات غير متاح" detail="هذا الحساب لا يملك صلاحية إعداد الشركات." />;
  const { data } = await supabase.rpc('tenant_admin_invitation_list');
  const rows = Array.isArray(data) ? (data as InvitationRow[]) : [];
  const success = params.state === 'created-sent' || params.state === 'reissued-sent' || params.state === 'revoked';

  return (
    <main className="app-shell">
      {success && <FeedbackToast key={crypto.randomUUID()} message={stateMessage(params.state ?? '')} />}
      <header className="topbar">
        <Link className="brand" href="/operator">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="work-card operator-invitations-overview" aria-labelledby="invite-title">
        <p className="eyebrow">إعداد الشركات</p>
        <h1 id="invite-title">دعوات مسؤولي الشركات</h1>
        <p className="intro">أنشئ شركة بدعوة مسؤولها الأول، وتابع حالة الدعوات هنا. لن تُنشأ الشركة قبل قبول الدعوة.</p>
        {params.state && !success && <p className="form-message form-error" role="alert">{stateMessage(params.state)} <a href="#history-title">راجع حالة الدعوات</a></p>}
        <details className="operator-grant-form operator-invite-disclosure" open={params.state === 'invalid'}>
          <summary className="primary-button">دعوة مسؤول لشركة جديدة</summary>
          <p className="field-hint">أدخل بيانات الشركة وحدود الاشتراك، ثم أرسل الدعوة للمسؤول الأول.</p>
          <form className="auth-form onboarding-form" action={createInvitationAction}>
            <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
            <label htmlFor="tenantName">اسم الشركة</label>
            <input id="tenantName" name="tenantName" required maxLength={160} />
            <label htmlFor="entityName">اسم الجهة القانونية (اختياري)</label>
            <input id="entityName" name="entityName" maxLength={160} placeholder="يُستخدم اسم الشركة إذا تُرك فارغًا" />
            <label htmlFor="siteName">اسم الفرع أو الموقع الرئيسي</label>
            <input id="siteName" name="siteName" defaultValue="المقر الرئيسي" required maxLength={160} />
            <label htmlFor="targetEmail">بريد المسؤول الأول</label>
            <input id="targetEmail" name="targetEmail" type="email" autoComplete="email" required maxLength={254} />
            <LimitFields kind="seats" label="عدد المستخدمين" />
            <LimitFields kind="sites" label="عدد الفروع والمواقع" />
            <button className="primary-button" type="submit">إرسال الدعوة</button>
          </form>
        </details>
        <Link className="back-link" href="/operator/onboarding">إعداد شركة لمسؤول لديه حساب بالفعل</Link>
      </section>
      <section className="work-card invitation-list operator-invitations-history" aria-labelledby="history-title">
        <h2 id="history-title">الدعوات وحالتها</h2>
        {rows.length === 0 ? <p className="intro">لا توجد دعوات بعد.</p> : (
          <ul>
            {rows.map((row) => (
              <li key={row.id} className="invitation-row">
                <div>
                  <h3>{row.tenant_name}</h3>
                  <p><bdi>{row.target_email}</bdi></p>
                  <p className={`entity-status ${row.lifecycle_state === 'accepted' ? 'is-active' : row.lifecycle_state === 'pending' ? 'is-pending' : 'is-inactive'}`}>{lifecycleText(row.lifecycle_state)}</p>
                  {row.lifecycle_state === 'pending' && <p>{deliveryText(row.delivery_state)}</p>}
                  {row.lifecycle_state === 'pending' && row.delivery_state !== 'sent' && <p className="field-hint">يمكنك إعادة الإرسال. كل إصدار جديد يبطل الرابط السابق.</p>}
                  {row.lifecycle_state === 'accepted' && <p className="field-hint">اكتمل إنشاء الشركة ومسؤولها.</p>}
                </div>
                {row.lifecycle_state === 'pending' && (
                  <div className="invitation-actions">
                    <form action={reissueInvitationAction}>
                      <input type="hidden" name="invitationId" value={row.id} />
                      <button className="secondary-button" type="submit">إعادة إرسال دعوة جديدة</button>
                    </form>
                    <form action={revokeInvitationAction}>
                      <input type="hidden" name="invitationId" value={row.id} />
                      <button className="secondary-button" type="submit">إلغاء الدعوة</button>
                    </form>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>
      <footer className="footer">منصة الأعمال · دعوات الشركات</footer>
    </main>
  );
}

function LimitFields({ kind, label }: { kind: 'seats' | 'sites'; label: string }) {
  return (
    <fieldset className="limit-fields">
      <legend>{label}</legend>
      <label htmlFor={`${kind}Mode`}>نوع الحد</label>
      <select id={`${kind}Mode`} name={`${kind}Mode`} defaultValue="limited">
        <option value="limited">عدد محدد</option>
        <option value="unlimited">غير محدود</option>
      </select>
      <label htmlFor={`${kind}Limit`}>العدد عند اختيار حد محدد</label>
      <input id={`${kind}Limit`} name={`${kind}Limit`} type="number" min="1" step="1" defaultValue="10" />
    </fieldset>
  );
}

function lifecycleText(state: string) {
  const labels: Record<string, string> = { pending: 'بانتظار قبول المسؤول', accepted: 'مقبولة', expired: 'منتهية', revoked: 'ملغاة' };
  return labels[state] ?? 'حالة غير معروفة';
}

function deliveryText(state: string) {
  const labels: Record<string, string> = { sending: 'حالة الإرسال قيد التحقق', sent: 'أُرسلت بالبريد', failed: 'تعذر إرسال البريد' };
  return labels[state] ?? 'حالة الإرسال غير معروفة';
}

function stateMessage(state: string) {
  const labels: Record<string, string> = {
    'created-sent': 'أُرسلت الدعوة إلى البريد. لا تُعد الشركة جاهزة قبل قبولها وإكمال إعداد المسؤول.',
    'created-failed': 'سُجل طلب الدعوة لكن تعذر إرسال البريد. راجع الحالة أدناه ثم أعد إصدار الدعوة.',
    'created-unknown': 'سُجل طلب الدعوة لكن حالة إرسال البريد غير مؤكدة. راجع الحالة أدناه وأعد إصدار الدعوة عند الحاجة.',
    'reissued-sent': 'أُرسل إصدار جديد وأصبح الرابط السابق غير صالح لإعداد الشركة.',
    'reissued-failed': 'تحدّث إصدار الدعوة وأصبح الرابط السابق غير صالح، لكن تعذر إرسال البريد الجديد.',
    'reissued-unknown': 'تحدّث إصدار الدعوة وأصبح الرابط السابق غير صالح، لكن حالة إرسال البريد الجديد غير مؤكدة.',
    revoked: 'أُلغيت الدعوة. لن ينشئ رابطها صلاحية للشركة.',
    existing: 'هذه الدعوة مسجلة من قبل. راجع حالتها أدناه.',
    'already-accepted': 'قُبلت الدعوة بالفعل وأُنشئت الشركة.',
    'already-revoked': 'هذه الدعوة ملغاة بالفعل.',
    expired: 'انتهت صلاحية الدعوة. يمكنك إنشاء دعوة جديدة.',
    invalid: 'تحقق من البريد والبيانات، ويجب أن يكون كل حد رقمًا موجبًا أو غير محدود.',
    setup: 'إعداد Supabase أو مفتاح إرسال الدعوات غير مكتمل.',
    forbidden: 'تعذر تنفيذ الإجراء. تحقق من صلاحية مشغّل المنصة وحالة الدعوة.',
  };
  return labels[state] ?? 'تعذر إتمام الإجراء.';
}

function Status({ title, detail }: { title: string; detail: string }) {
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p></section>
    </main>
  );
}
