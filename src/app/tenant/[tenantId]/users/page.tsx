import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { inviteMemberAction, reissueMemberInvitationAction, revokeMemberInvitationAction, setMemberAccessAction } from './actions';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type SearchParams = Promise<{ state?: string }>;
type Row = { user_id: string; email: string; access_state: string; role_key: string | null; protected_admin: boolean };
type Invitation = { id: string; target_email: string; lifecycle_state: string; delivery_state: string; issuance: number; expires_at: string };

export default async function TenantUsersPage({ params, searchParams }: { params: Params; searchParams: SearchParams }) {
  const { tenantId } = await params;
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/users`)}`);
  const { data, error } = await supabase.rpc('tenant_member_access_list', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل المستخدمين" detail="أعد تحميل الصفحة. لم تتغير أي عضوية." />;
  const { data: snapshot, error: snapshotError } = await supabase.rpc('tenant_membership_snapshot', { p_tenant_id: tenantId });
  if (snapshotError || !snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) return <Status title="المساحة غير متاحة" detail="تعذر قراءة هذه الشركة." />;
  const result = data as Record<string, unknown>;
  const memberships = Array.isArray(result.memberships) ? result.memberships as Row[] : [];
  const invitations = Array.isArray(result.invitations) ? result.invitations as Invitation[] : [];
  const snapshotValue = snapshot as Record<string, unknown>;
  const limit = objectValue(result.seat_limit);
  const used = Number(result.seat_usage ?? 0);

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href={`/tenant/${tenantId}`}>{String(snapshotValue.tenant_name ?? 'الشركة')}</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/tenant/select">تبديل الشركة</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav>
      </header>
      <section className="work-card" aria-labelledby="members-title">
        <p className="eyebrow">إدارة الوصول</p>
        <h1 id="members-title">مستخدمو الشركة</h1>
        <p className="intro">المقاعد المستخدمة: {limit?.mode === 'unlimited' ? `${used} · بلا حد أقصى` : `${used} من ${String(limit?.value ?? 'غير متاح')}`}</p>
        {query.state && <p className="form-message" role="status">{stateMessage(query.state)}</p>}
        <form className="auth-form member-invite-form" action={inviteMemberAction}>
          <input type="hidden" name="tenantId" value={tenantId} />
          <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
          <label htmlFor="member-email">البريد الإلكتروني</label>
          <input id="member-email" name="email" type="email" autoComplete="email" required maxLength={254} />
          <p className="field-hint">سيُضاف الحساب بدور «عضو». تعيين مسؤول جديد يحتاج إجراءً منفصلًا.</p>
          <button className="primary-button" type="submit">دعوة عضو</button>
        </form>
      </section>
      <section className="work-card invitation-list" aria-labelledby="member-list-title">
        <h2 id="member-list-title">العضويات</h2>
        {memberships.length === 0 ? <p className="intro">لا يوجد مستخدمون بعد.</p> : (
          <ul>{memberships.map((row) => (
            <li className="invitation-row" key={row.user_id}>
              <div>
                <h3><bdi>{row.email}</bdi></h3>
                <p>{row.protected_admin ? 'مسؤول الشركة' : 'عضو'} · {row.access_state === 'active' ? 'نشط' : 'غير نشط'}</p>
                {row.protected_admin && <p className="field-hint">إدارة المسؤولين تتم بإجراء مستقل.</p>}
              </div>
              {!row.protected_admin && <form action={setMemberAccessAction}>
                <input type="hidden" name="tenantId" value={tenantId} />
                <input type="hidden" name="userId" value={row.user_id} />
                <input type="hidden" name="accessState" value={row.access_state === 'active' ? 'inactive' : 'active'} />
                <button className="secondary-button" type="submit">{row.access_state === 'active' ? 'تعطيل العضوية' : 'إعادة تفعيل كعضو'}</button>
              </form>}
            </li>
          ))}</ul>
        )}
      </section>
      <section className="work-card invitation-list" aria-labelledby="pending-title">
        <h2 id="pending-title">الدعوات</h2>
        {invitations.length === 0 ? <p className="intro">لا توجد دعوات.</p> : (
          <ul>{invitations.map((invitation) => (
            <li className="invitation-row" key={invitation.id}>
              <div>
                <h3><bdi>{invitation.target_email}</bdi></h3>
                <p>{invitationText(invitation.lifecycle_state)} · {deliveryText(invitation.delivery_state)}</p>
                {invitation.lifecycle_state === 'pending' && <p className="field-hint">لا تُحتسب الدعوة ضمن المقاعد حتى يقبلها المستخدم.</p>}
              </div>
              {invitation.lifecycle_state === 'pending' && <div className="invitation-actions">
                <form action={reissueMemberInvitationAction}>
                  <input type="hidden" name="tenantId" value={tenantId} />
                  <input type="hidden" name="invitationId" value={invitation.id} />
                  <button className="secondary-button" type="submit">إعادة إرسال</button>
                </form>
                <form action={revokeMemberInvitationAction}>
                  <input type="hidden" name="tenantId" value={tenantId} />
                  <input type="hidden" name="invitationId" value={invitation.id} />
                  <button className="secondary-button" type="submit">إلغاء الدعوة</button>
                </form>
              </div>}
            </li>
          ))}</ul>
        )}
      </section>
      <footer className="footer"><Link href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link></footer>
    </main>
  );
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}
function invitationText(state: string) {
  return ({ pending: 'بانتظار القبول', accepted: 'مقبولة', expired: 'منتهية', revoked: 'ملغاة' } as Record<string, string>)[state] ?? 'غير معروفة';
}
function deliveryText(state: string) {
  return ({ sending: 'جارٍ التحقق من الإرسال', sent: 'أُرسلت بالبريد', failed: 'تعذر إرسال البريد' } as Record<string, string>)[state] ?? 'حالة الإرسال غير معروفة';
}
function stateMessage(state: string) {
  const labels: Record<string, string> = {
    invalid: 'أدخل بريدًا إلكترونيًا صحيحًا.', setup: 'إعداد خدمة الحسابات غير مكتمل.',
    forbidden: 'لا تملك صلاحية إدارة أعضاء هذه الشركة.', failed: 'تعذر إتمام الإجراء. لم تتغير العضوية؛ أعد المحاولة.',
    'created-sent': 'أُرسلت الدعوة. لن يحصل المستخدم على وصول أو مقعد قبل قبولها.',
    'created-failed': 'حُفظت الدعوة لكن تعذر إرسال البريد. يمكنك إعادة الإرسال.',
    'created-unknown': 'حُفظت الدعوة وحالة الإرسال غير مؤكدة. راجعها ثم أعد الإرسال عند الحاجة.',
    'reissued-sent': 'أُرسل رابط جديد وأصبح الرابط السابق غير صالح.',
    'reissued-failed': 'تجددت الدعوة لكن تعذر إرسال البريد. يمكنك إعادة الإرسال مرة أخرى.',
    'reissued-unknown': 'تجددت الدعوة وحالة الإرسال غير مؤكدة. راجع الحالة قبل إعادة الإرسال.',
    'already-member': 'هذا المستخدم عضو بالفعل في الشركة.', 'pending-exists': 'توجد دعوة معلّقة لهذا البريد. أعد إرسالها من قائمة الدعوات.',
    existing: 'يوجد طلب سابق لهذا الإجراء.', revoked: 'أُلغيت الدعوة.', expired: 'انتهت الدعوة ويمكن إصدار واحدة جديدة.',
    terminal: 'الدعوة لم تعد معلّقة، لذلك لم يُرسل بريد جديد.', 'limit-full': 'اكتمل عدد المستخدمين المسموح به. عطّل عضوية غير مستخدمة أو اطلب من مشغّل المنصة رفع الحد.',
    reactivated: 'أُعيد تفعيل العضوية بدور «عضو».', deactivated: 'عُطّلت العضوية وحُفظ سجلها.',
    'admin-governed': 'تغيير مسؤول الشركة يحتاج إجراءً منفصلًا.', 'key-conflict': 'تعذر إعادة استخدام الطلب نفسه ببيانات مختلفة.',
    'issuer-lost': 'لا يمكن إعادة إرسال هذه الدعوة لأن مُصدرها لم يعد يملك صلاحية إدارة الأعضاء. ألغها وأنشئ دعوة جديدة من حساب مخوّل.',
    'target-unavailable': 'لا يمكن إعادة تفعيل العضوية لأن الحساب محذوف أو محظور أو لم يؤكد بريده بعد.',
  };
  return labels[state] ?? 'تعذر تنفيذ الإجراء.';
}
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p><Link className="primary-button" href="/auth/login">العودة إلى الدخول</Link></section></main>;
}
