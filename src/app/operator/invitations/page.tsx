import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { FeedbackToast } from '@/components/feedback-toast';
import { SubmitButton } from '@/components/submit-button';
import { reissueInvitationAction, revokeInvitationAction } from './actions';
import { OperatorListControls, operatorListQuery } from '@/app/operator/operator-list-controls';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ id?: string; state?: string; page?: string; q?: string }>;
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
  const { page, search } = operatorListQuery(params);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session&next=%2Foperator%2Finvitations');
  const { data: capable } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (!capable) return <Status title="إعداد الدعوات غير متاح" detail="هذا الحساب لا يملك صلاحية إعداد الشركات." />;
  const { data, error } = await supabase.rpc('tenant_admin_invitation_page', { p_page: page, p_query: search });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل الدعوات" detail="لم نتمكن من عرض حالة الدعوات الآن. أعد تحميل الصفحة وحاول مرة أخرى." />;
  const result = data as Record<string, unknown>;
  const rows = Array.isArray(result.rows) ? result.rows as InvitationRow[] : [];
  const matchingCount = Number(result.matching_count ?? 0);
  let selected = rows.find((row) => row.id === params.id);
  if (!selected && params.id && isUuid(params.id)) {
    const { data: selectedData, error: selectedError } = await supabase.rpc('tenant_admin_invitation_get', { p_invitation_id: params.id });
    if (!selectedError && selectedData && typeof selectedData === 'object' && !Array.isArray(selectedData)) selected = selectedData as InvitationRow;
  }
  const visibleRows = selected ? [selected, ...rows.filter((row) => row.id !== selected.id)] : rows;
  const success = params.state === 'created-sent' || params.state === 'reissued-sent' || params.state === 'revoked';

  return (
    <main className="app-shell">
      {success && <FeedbackToast key={crypto.randomUUID()} message={stateMessage(params.state ?? '')} />}
      <header className="topbar">
        <Link className="brand" href="/operator">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <header className="workspace-page-heading"><div><p className="eyebrow">إعداد الشركات</p>
        <h1 id="invite-title">دعوات مسؤولي الشركات</h1>
        <p>تابع حالة الدعوات. تُنشأ الشركة عند قبول المسؤول الأول للدعوة.</p></div>
        <Link className="primary-button" href="/operator/invitations/new">دعوة مسؤول جديد</Link>
      </header>
      <section className="workspace-notices" aria-labelledby="invite-title">
        {params.state && !success && <p className="form-message form-error" role="alert">{stateMessage(params.state)} <a href="#history-title">راجع حالة الدعوات</a></p>}
      </section>
      <section className="work-card invitation-list operator-invitations-history" aria-labelledby="history-title">
        <h2 id="history-title">الدعوات وحالتها</h2>
        <OperatorListControls basePath="/operator/invitations" search={search} page={page} matchingCount={matchingCount} searchLabel="البحث باسم الشركة أو البريد" inputId="invitation-search" />
        {visibleRows.length === 0 ? <p className="intro">{matchingCount ? 'لا توجد نتائج في هذه الصفحة.' : 'لا توجد دعوات مطابقة.'}</p> : (
          <ul>
            {visibleRows.map((row) => (
              <li key={row.id} id={`invitation-${row.id}`} className="invitation-row">
                <div>
                  {row.id === selected?.id && <p className="field-hint">الدعوة المرتبطة بآخر إجراء</p>}
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
                      <SubmitButton className="secondary-button" label="إعادة إرسال دعوة جديدة" pendingLabel="جارٍ الإرسال…" />
                    </form>
                    <form action={revokeInvitationAction}>
                      <input type="hidden" name="invitationId" value={row.id} />
                      <SubmitButton className="secondary-button" label="إلغاء الدعوة" />
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
    'revoke-unchanged': 'لم يحدث إلغاء في هذه المحاولة. قد لا تكون الدعوة متاحة أو قابلة للإلغاء. راجع حالتها الحالية.',
    'revoke-unknown': 'تعذر تأكيد نتيجة الإلغاء. راجع الحالة الحالية قبل تنفيذ إجراء آخر.',
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

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }

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
