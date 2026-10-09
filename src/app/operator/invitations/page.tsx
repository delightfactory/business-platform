import { Button, ButtonLink } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { operatorInvitation, operatorPage, operatorUuid } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { invitationReviewMessage } from '@/lib/invitation-feedback';
import { reissueInvitationAction, revokeInvitationAction } from './actions';
import { OperatorListControls, operatorListQuery } from '@/app/operator/operator-list-controls';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ id?: string | string[]; state?: string; page?: string; q?: string }>;


export default async function OperatorInvitationsPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const selectedId = operatorUuid(params.id) ? params.id : null;
  const { page, search } = operatorListQuery(params);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session&next=%2Foperator%2Finvitations');
  const { data: capable, error: capabilityError } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (capabilityError) return <Status title="تعذر التحقق من الصلاحية" detail="أعد قراءة الصفحة للتحقق من مهمة إعداد الشركات." />;
  if (!operatorPermission({ data: capable, error: capabilityError })) return <Status title="إعداد الدعوات غير متاح" detail="هذا الحساب لا يملك صلاحية إعداد الشركات." />;
  const { data, error } = await supabase.rpc('tenant_admin_invitation_page', { p_page: page, p_query: search });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل الدعوات" detail="لم نتمكن من عرض حالة الدعوات الآن. أعد تحميل الصفحة وحاول مرة أخرى." />;
  const result = operatorPage(data, operatorInvitation, row => row.id);
  if (!result) return <Status title="تعذر تحميل الدعوات" detail="بيانات القائمة غير مكتملة. أعد تحميل الصفحة؛ لم تتأكد قائمة فارغة." />;
  const rows = result.rows;
  const matchingCount = result.matching_count;
  let selected = rows.find(row => selectedId !== null && row.id.toLowerCase() === selectedId.toLowerCase());
  let selectedNotice: string | null = null;
  if (params.id !== undefined && !selectedId) selectedNotice = 'مرجع الدعوة غير صالح. راجع الدعوات الحالية أدناه.';
  if (!selected && selectedId) {
    const { data: selectedData, error: selectedError } = await supabase.rpc('tenant_admin_invitation_get', { p_invitation_id: selectedId });
    if (selectedError) selectedNotice = 'تعذر قراءة الدعوة المرتبطة بالإجراء. لا يمكن تأكيد نتيجته من القائمة الحالية؛ أعد قراءة الصفحة.';
    else if (selectedData === null) selectedNotice = 'لا تتوفر الدعوة المرتبطة بالإجراء لهذا الحساب حاليًا. هذا لا يؤكد نتيجة الإجراء.';
    else if (!operatorInvitation(selectedData) || selectedData.id.toLowerCase() !== selectedId.toLowerCase()) selectedNotice = 'بيانات الدعوة المرتبطة بالإجراء غير مكتملة. أعد قراءة الصفحة قبل إجراء آخر.';
    else selected = selectedData;
  }
  const visibleRows = selected ? [selected, ...rows.filter((row) => row.id.toLowerCase() !== selected.id.toLowerCase())] : rows;
  const reviewQuery = new URLSearchParams({ page: String(page), q: search });
  if (selectedId) reviewQuery.set('id', selectedId);
  const reviewMessage = invitationReviewMessage(params.state);

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/operator">منصة الأعمال</Link>
        <form action={signOutAction}><Button variant="ghost" className="secondary-button" type="submit">تسجيل الخروج</Button></form>
      </header>
      <header className="workspace-page-heading"><div><p className="eyebrow">إعداد الشركات</p>
        <h1 id="invite-title">دعوات مسؤولي الشركات</h1>
        <p>تابع حالة الدعوات. تُنشأ الشركة عند قبول المسؤول الأول للدعوة.</p></div>
        <ButtonLink variant="solid" className="primary-button" href="/operator/invitations/new">دعوة مسؤول جديد</ButtonLink>
      </header>
      <section className="workspace-notices" aria-labelledby="invite-title">
        {selectedNotice && <p className="form-message form-error" role="alert">{selectedNotice} <ButtonLink variant="ghost" className="secondary-button" href={`/operator/invitations?${reviewQuery}`}>{selectedId ? 'إعادة قراءة الدعوة' : 'مراجعة الدعوات الحالية'}</ButtonLink></p>}
        {reviewMessage && <p className="form-message" role="status">{reviewMessage} <a href="#history-title">راجع حالة الدعوات</a></p>}
        {params.state && !reviewMessage && <p className="form-message form-error" role="alert">{stateMessage()} <a href="#history-title">راجع حالة الدعوات</a></p>}
      </section>
      <section className="work-card invitation-list operator-invitations-history" aria-labelledby="history-title">
        <h2 id="history-title">الدعوات وحالتها</h2>
        <OperatorListControls basePath="/operator/invitations" search={search} page={page} matchingCount={matchingCount} searchLabel="البحث باسم الشركة أو البريد" inputId="invitation-search" />
        {visibleRows.length === 0 ? <p className="intro">{matchingCount ? 'لا توجد نتائج في هذه الصفحة.' : 'لا توجد دعوات مطابقة.'}</p> : (
          <ul>
            {visibleRows.map((row) => (
              <li key={row.id} id={`invitation-${row.id}`} className="invitation-row">
                <div>
                  {row.id === selected?.id && <p className="field-hint">الدعوة المحددة في الرابط</p>}
                  <h3>{row.tenant_name}</h3>
                  <p><bdi>{row.target_email}</bdi></p>
                  <p className={`entity-status ${row.lifecycle_state === 'accepted' ? 'is-active' : row.lifecycle_state === 'pending' ? 'is-pending' : 'is-inactive'}`}>{lifecycleText(row.lifecycle_state)}</p>
                  {row.lifecycle_state === 'pending' && <p>{deliveryText(row.delivery_state)}</p>}
                  {row.lifecycle_state === 'pending' && <p className="field-hint">{row.delivery_state === 'failed'
                    ? 'تعذر الإرسال المسجل لهذه الدعوة. إذا اخترت إعادة الإرسال، يُنشأ رابط جديد ويبطل الرابط السابق.'
                    : row.delivery_state === 'sent'
                      ? 'الإرسال المسجل لا يؤكد وصول البريد أو قبول الدعوة. إعادة الإرسال تنشئ رابطًا جديدًا وتبطل السابق.'
                      : 'نتيجة الإرسال غير مؤكدة. راجع الحالة وتحقق مع المستلم قبل اختيار إعادة الإرسال؛ الإصدار الجديد يبطل الرابط السابق.'}</p>}
                  {row.lifecycle_state === 'accepted' && <p className="field-hint">اكتمل إنشاء الشركة ومسؤولها.</p>}
                </div>
                {row.lifecycle_state === 'pending' && (
                  <div className="invitation-actions">
                    <OfflineForm action={reissueInvitationAction}>
                      <input type="hidden" name="invitationId" value={row.id} />
                      <OfflineSubmitButton className="secondary-button" label="إعادة إرسال دعوة جديدة" pendingLabel="جارٍ الإرسال…" />
                    </OfflineForm>
                    <OfflineForm action={revokeInvitationAction}>
                      <input type="hidden" name="invitationId" value={row.id} />
                      <OfflineSubmitButton className="secondary-button" label="إلغاء الدعوة" />
                    </OfflineForm>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

    </main>
  );
}


function lifecycleText(state: string) {
  const labels: Record<string, string> = { pending: 'بانتظار قبول المسؤول', accepted: 'مقبولة', expired: 'منتهية', revoked: 'ملغاة' };
  return Object.hasOwn(labels, state) ? labels[state] : 'حالة غير معروفة';
}

function deliveryText(state: string) {
  const labels: Record<string, string> = { sending: 'حالة الإرسال قيد التحقق', sent: 'أُرسلت بالبريد', failed: 'تعذر إرسال البريد' };
  return Object.hasOwn(labels, state) ? labels[state] : 'حالة الإرسال غير معروفة';
}

function stateMessage() {
  return 'الرابط وحده لا يؤكد نتيجة الإجراء. راجع حالة الدعوة والإرسال أدناه قبل إجراء آخر.';
}

function Status({ title, detail }: { title: string; detail: string }) {
  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><Button variant="ghost" className="secondary-button" type="submit">تسجيل الخروج</Button></form>
      </header>
      <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p></section>
    </main>
  );
}
