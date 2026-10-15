import { PEOPLE_ROLE_BUNDLES } from './bundles';
import { PageHeader, Badge, Disclosure, HelpNote } from '@/components/ui';
import { Message, Panel, Sheet } from '@/components/ui';
import { Button, ButtonLink, Input } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
import { FeedbackToast } from '@/components/feedback-toast';
import { invitationReviewMessage } from '@/lib/invitation-feedback';
import { reissueMemberInvitationAction, revokeMemberInvitationAction, setMemberAccessAction, setProtectedAdminLeaveSelfAccessAction, changeTenantAdminRoleAction } from './actions';
import { MemberAccessSheet } from './MemberAccessSheet';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type SearchParams = Promise<{ state?: string; view?: string; page?: string; q?: string; member?: string; invitation?: string }>;
type RoleAssignment = { role_key: string; role_version: number };
type Row = { user_id: string; email: string; access_state: string; role_key: string | null; roles: RoleAssignment[]; protected_admin: boolean };
type Invitation = { id: string; target_email: string; lifecycle_state: string; delivery_state: string; issuance: number; expires_at: string };



export default async function TenantUsersPage({ params, searchParams }: { params: Params; searchParams: SearchParams }) {
  const { tenantId } = await params;
  const query = await searchParams;
  const showInvitations = query.view === 'invitations' || Boolean(query.state?.startsWith('created-') || query.state?.startsWith('reissued-') ||
    ['pending-exists', 'revoked', 'revoke-unchanged', 'revoke-unknown', 'expired', 'terminal', 'issuer-lost'].includes(query.state ?? ''));
  const view = showInvitations ? 'invitations' : 'members';
  const page = /^[1-9]\d{0,5}$/.test(query.page ?? '') ? Math.min(Number(query.page), 100000) : 1;
  const search = (query.q ?? '').trim().slice(0, 120);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="تعذر الاتصال بخدمة الحسابات" detail="حاول مرة أخرى لاحقًا. إذا استمرت المشكلة، تواصل مع دعم المنصة." />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/users`)}`);
  const { data, error } = await supabase.rpc('tenant_member_access_page', {
    p_tenant_id: tenantId, p_view: view, p_page: page, p_query: search,
  });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status tenantId={tenantId} title="تعذر تحميل المستخدمين" detail="تعذر قراءة الحالة الحالية. أعد تحميل الصفحة قبل تنفيذ أي إجراء جديد." />;
  const [{ data: snapshot, error: snapshotError }, { data: peopleSetupAccess, error: peopleSetupError }, { data: canManageRoles }] = await Promise.all([
    readWorkspaceRpc(supabase, 'tenant_membership_snapshot', tenantId, 'p_tenant_id'),
    readWorkspaceRpc(supabase, 'people_access_snapshot', tenantId, 'p_tenant_id'),
    supabase.rpc('tenant_admin_role_governance_available', { p_tenant_id: tenantId }),
  ]);
  if (snapshotError || !snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) return <Status tenantId={tenantId} title="المساحة غير متاحة" detail="تعذر قراءة هذه الشركة." />;
  const canOpenPeopleSetup = !peopleSetupError && Boolean(peopleSetupAccess);
  const result = data as Record<string, unknown>;
  const memberships = view === 'members' && Array.isArray(result.rows) ? result.rows as Row[] : [];
  const invitations = view === 'invitations' && Array.isArray(result.rows) ? result.rows as Invitation[] : [];
  const memberCount = Number(result.member_count ?? 0);
  const invitationCount = Number(result.invitation_count ?? 0);
  const matchingCount = Number(result.matching_count ?? 0);
  const pageCount = Math.max(1, Math.ceil(matchingCount / 25));
  const limit = objectValue(result.seat_limit);
  const used = Number(result.seat_usage ?? 0);

  const savedMember = memberships.find(row => row.user_id === query.member);
  const success = savedMember && ['bundles-updated', 'bundles-unchanged'].includes(query.state ?? '')
    ? `الصلاحيات المحفوظة الآن: ${assignedBundleLabels(savedMember.roles).length}.`
    : successMessage(query.state);
  const reviewMessage = invitationReviewMessage(query.state);
  const deliveryIssue = query.state && ['created-failed', 'created-unknown', 'reissued-failed', 'reissued-unknown'].includes(query.state)
    ? stateMessage(query.state) : null;
  return (
    <main className="app-shell">
      {success && <FeedbackToast key={crypto.randomUUID()} message={success} />}
      <header className="workspace-page-heading"><div><p className="eyebrow">إدارة الشركة</p>
        <PageHeader id="members-title" title={<>المستخدمون والدعوات</>} />
        <p>تابع وصول فريقك، وأرسل دعوات جديدة عند الحاجة.</p></div>
        <ButtonLink variant="solid"  href={`/tenant/${tenantId}/users/invite`}>دعوة عضو</ButtonLink>
      </header>
      <div className="workspace-page-summary"><strong>المستخدمون النشطون: {limit?.mode === 'unlimited' ? `${used} · بلا حد أقصى` : `${used} من ${String(limit?.value ?? 'غير متاح')}`}</strong>
        <span>الدعوات المعلّقة لا تُحتسب قبل قبولها.</span></div>
      <section className="workspace-notices" aria-labelledby="members-title">
        {deliveryIssue && <Message tone="info" className="capacity-message" role="alert">{deliveryIssue} <a href="#pending-title">عرض الدعوات وإعادة الإرسال</a></Message>}
        {reviewMessage && <Message tone="info"  role="status">{reviewMessage} <a href="#pending-title">راجع حالة الدعوات</a></Message>}
        {query.state && !success && !deliveryIssue && !reviewMessage && <Message tone="bad"  role="alert">{stateMessage(query.state)}</Message>}
      </section>
      <details className="workspace-records-panel admin-setup-details"><summary id="attendance-access-setup">كيف أتيح تسجيل الحضور للموظف؟</summary><div><p>اربط ملف الموظف بحساب عضو نشط، ثم اختر «الحضور الشخصي من الهاتف» في صلاحيات ذلك العضو. بعد حفظ الصلاحيات، يفتح الموظف «حضوري» من حسابه.</p><p className="field-hint">يلزم أيضًا عمل سارٍ وموقع وسياسة حضور مهيأة وخدمة حضور مفعّلة. الربط وحده لا يمنح التسجيل. سحب الصلاحية أو فك الربط يوقف التسجيل للحساب.</p>{canOpenPeopleSetup?<ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>فتح ملفات الموظفين لإكمال الربط</ButtonLink>:<p>تواصل مع مدير الموارد البشرية لإكمال ربط الموظف؛ صلاحية إدارة الأعضاء لا تمنح الاطلاع على ملفات الموظفين.</p>}</div></details>
      <nav className="workspace-view-tabs" aria-label="عرض المستخدمين والدعوات">
        <Link href={usersUrl(tenantId, 'members', 1, search)} aria-current={!showInvitations ? 'page' : undefined}>الأعضاء <span>{memberCount}</span></Link>
        <Link href={usersUrl(tenantId, 'invitations', 1, search)} aria-current={showInvitations ? 'page' : undefined}>الدعوات <span>{invitationCount}</span></Link>
      </nav>
      <form action={`/tenant/${tenantId}/users`} method="get" role="search" className="workspace-form-panel">
        <input type="hidden" name="view" value={view} />
        <label htmlFor="member-search">البحث بالبريد الإلكتروني</label>
        <Input id="member-search" type="search" name="q" defaultValue={search} maxLength={120} placeholder="ابحث عن بريد مستخدم أو دعوة" />
        <Button variant="ghost"  type="submit">بحث</Button>
      </form>
      <p className="field-hint">{search ? `نتائج البحث: ${matchingCount}` : `الإجمالي: ${matchingCount}`} · {page > pageCount ? 'هذه الصفحة لم تعد متاحة' : `صفحة ${page} من ${pageCount}`}</p>
      {!showInvitations && <Panel className="invitation-list tenant-users-list" aria-labelledby="member-list-title">
        <h2 id="member-list-title">العضويات</h2>
        {memberships.length === 0 ? <p className="intro">{search ? 'لا توجد عضويات تطابق البحث.' : 'لا يوجد مستخدمون في هذه الصفحة.'}</p> : (
          <ul>{memberships.map((row) => (
            <li className="invitation-row" key={row.user_id}>
              <div>
                <h3><bdi>{row.email}</bdi></h3>
                <p>{row.protected_admin ? 'مسؤول الشركة' : 'عضو'}</p>
                <Badge as="p" className={` ${row.access_state === 'active' ? 'is-active' : 'is-inactive'}`}>{row.access_state === 'active' ? 'نشط' : 'غير نشط'}</Badge>
                <p>صلاحيات العمل: <strong>{assignedBundleLabels(row.roles).length}</strong></p>
                {row.access_state !== 'active' && assignedBundleLabels(row.roles).length > 0 && <Disclosure summary="عرض الصلاحيات المحفوظة">
                  <ul>{assignedBundleLabels(row.roles).map(label => <li key={label}>{label}</li>)}</ul>
                </Disclosure>}
                {PEOPLE_ROLE_BUNDLES.some(bundle => bundle.financial && hasBundle(row.roles, bundle.key)) && <Badge tone="warn">سلطة مالية</Badge>}
                {row.protected_admin && <HelpNote label="عن صلاحيات مسؤول الشركة"><p>صلاحيات الموظفين والرواتب تُختار من «تعديل صلاحيات المستخدم». إضافتها أو إزالتها لا تغيّر دور مسؤول الشركة.</p></HelpNote>}
              </div>
              <div className="invitation-actions">
                {row.access_state === 'active' && <MemberAccessSheet key={`${row.user_id}:${row.roles.map(role => role.role_key).sort().join(',')}`} tenantId={tenantId} userId={row.user_id} email={row.email}
                  initialKeys={PEOPLE_ROLE_BUNDLES.filter(bundle => hasBundle(row.roles, bundle.key)).map(bundle => bundle.key)} />}
                {((canManageRoles && row.access_state === 'active') || !row.protected_admin) && <Sheet title="إجراءات العضو" description={row.email} trigger={<Button variant="ghost">إجراءات العضو</Button>}>
                {canManageRoles && row.protected_admin && row.access_state === 'active' && <OfflineForm action={setProtectedAdminLeaveSelfAccessAction}>
                  <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="userId" value={row.user_id} />
                  <input type="hidden" name="enabled" value={hasBundle(row.roles, 'employee.leave.self.v1') ? 'false' : 'true'} />
                  <OfflineSubmitButton variant="ghost" label={hasBundle(row.roles, 'employee.leave.self.v1') ? 'إزالة الخدمة الذاتية للإجازات' : 'تفعيل إجازات الموظف'} pendingLabel="جارٍ الحفظ…" />
                  <p className="field-hint">للملف الشخصي والإجازات فقط؛ لا يغيّر دور المسؤول.</p>
                </OfflineForm>}
                {canManageRoles && row.access_state === 'active' && <Disclosure summary={<>{row.protected_admin ? 'خفض إلى عضو' : 'ترقية إلى مسؤول'}</>} className="role-change-confirmation">

                  <Message tone="warn">{row.protected_admin
                    ? row.user_id === user.id ? 'سيُخفض دورك إلى عضو وتفقد صلاحيات إدارة الشركة.' : 'سيُخفض هذا المستخدم إلى عضو وتُسحب منه صلاحيات إدارة الشركة.'
                    : 'سيكتسب هذا المستخدم صلاحيات إدارة الشركة. يحتاج الحساب إلى تأكيد البريد وإعداد دخول صالح.'}{row.protected_admin && ' لا يمكن خفض آخر مسؤول يستوفي شروط إدارة الشركة.'} لن يتغير عدد المستخدمين المحتسبين.</Message>
                  <OfflineForm action={changeTenantAdminRoleAction}>
                    <input type="hidden" name="tenantId" value={tenantId} />
                    <input type="hidden" name="userId" value={row.user_id} />

                    <input type="hidden" name="roleAction" value={row.protected_admin ? 'demote' : 'promote'} />
                    <OfflineSubmitButton variant="ghost"  label={row.protected_admin ? 'تأكيد الخفض إلى عضو' : 'تأكيد الترقية إلى مسؤول'} />
                  </OfflineForm>
                </Disclosure>}
                {!row.protected_admin && <OfflineForm action={setMemberAccessAction}>
                  <input type="hidden" name="tenantId" value={tenantId} />
                  <input type="hidden" name="userId" value={row.user_id} />

                  <input type="hidden" name="accessState" value={row.access_state === 'active' ? 'inactive' : 'active'} />
                  <OfflineSubmitButton variant="ghost"  label={row.access_state === 'active' ? 'تعطيل العضوية' : 'إعادة تفعيل كعضو'} />
                </OfflineForm>}
                </Sheet>}
              </div>
            </li>
          ))}</ul>
        )}
      </Panel>}
      {showInvitations && <Panel className="invitation-list tenant-users-list" aria-labelledby="pending-title">
        <h2 id="pending-title">الدعوات</h2>
        {invitations.length === 0 ? <p className="intro">{search ? 'لا توجد دعوات تطابق البحث.' : 'لا توجد دعوات في هذه الصفحة.'}</p> : (
          <ul>{invitations.map((invitation) => (
            <li className={`invitation-row ${query.invitation === invitation.id ? 'is-recent-invitation' : ''}`} key={invitation.id}>
              <div>
                <h3><bdi>{invitation.target_email}</bdi></h3>
                <Badge as="p" className={` ${invitation.lifecycle_state === 'accepted' ? 'is-active' : invitation.lifecycle_state === 'pending' ? 'is-pending' : 'is-inactive'}`}>{invitationText(invitation.lifecycle_state)}</Badge>
                <p>{deliveryText(invitation.delivery_state)}</p>
                {invitation.lifecycle_state === 'pending' && invitation.delivery_state !== 'sent' &&
                  <Message tone="info" className="capacity-message" role="status">{invitation.delivery_state === 'failed'
                    ? 'تعذر إرسال البريد. استخدم «إعادة إرسال» بعد التحقق من العنوان.'
                    : 'لم يتأكد إرسال البريد بعد. راجع الحالة قبل إعادة الإرسال.'}</Message>}
                {invitation.lifecycle_state === 'pending' && <p className="field-hint">لا تُحتسب الدعوة ضمن عدد المستخدمين المحتسبين حتى يقبلها المستخدم.</p>}
              </div>
              {invitation.lifecycle_state === 'pending' && <div className="invitation-actions">
                <OfflineForm action={reissueMemberInvitationAction}>
                  <input type="hidden" name="tenantId" value={tenantId} />
                  <input type="hidden" name="invitationId" value={invitation.id} />
                  <input type="hidden" name="invitationEmail" value={invitation.target_email} />
                  <OfflineSubmitButton variant="ghost"  label="إعادة إرسال" pendingLabel="جارٍ الإرسال…" />
                </OfflineForm>
                <OfflineForm action={revokeMemberInvitationAction}>
                  <input type="hidden" name="tenantId" value={tenantId} />
                  <input type="hidden" name="invitationId" value={invitation.id} />
                  <input type="hidden" name="invitationEmail" value={invitation.target_email} />
                  <OfflineSubmitButton variant="ghost"  label="إلغاء الدعوة" />
                </OfflineForm>
              </div>}
            </li>
          ))}</ul>
        )}
      </Panel>}
      <nav aria-label="صفحات المستخدمين والدعوات" className="workspace-view-tabs">
        {page > 1 && page <= pageCount && <Link href={usersUrl(tenantId, view, page - 1, search)}>الصفحة السابقة</Link>}
        {page < pageCount && <Link href={usersUrl(tenantId, view, page + 1, search)}>الصفحة التالية</Link>}
        {page > pageCount && <Link href={usersUrl(tenantId, view, pageCount, search)}>عرض آخر صفحة</Link>}
      </nav>

    </main>
  );
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function usersUrl(tenantId: string, view: 'members' | 'invitations', page: number, search: string) {
  const params = new URLSearchParams();
  if (view === 'invitations') params.set('view', view);
  if (page > 1) params.set('page', String(page));
  if (search) params.set('q', search);
  const suffix = params.toString();
  return `/tenant/${tenantId}/users${suffix ? `?${suffix}` : ''}`;
}
function hasBundle(roles: RoleAssignment[] | undefined, key: string) { return roles?.some((role) => role.role_key === key) ?? false; }
function assignedBundleLabels(roles: RoleAssignment[] | undefined) {
  return PEOPLE_ROLE_BUNDLES.filter((bundle) => hasBundle(roles, bundle.key)).map((bundle) => bundle.label);
}
function invitationText(state: string) {
  const labels: Record<string, string> = { pending: 'بانتظار القبول', accepted: 'مقبولة', expired: 'منتهية', revoked: 'ملغاة' };
  return Object.hasOwn(labels, state) ? labels[state] : 'غير معروفة';
}
function deliveryText(state: string) {
  const labels: Record<string, string> = { sending: 'جارٍ التحقق من الإرسال', sent: 'أُرسلت بالبريد', failed: 'تعذر إرسال البريد' };
  return Object.hasOwn(labels, state) ? labels[state] : 'حالة الإرسال غير معروفة';
}
function stateMessage(state: string) {
  const labels: Record<string, string> = {
    invalid: 'أدخل بريدًا إلكترونيًا صحيحًا.', setup: 'تعذر الاتصال بخدمة الحسابات. حاول لاحقًا أو تواصل مع دعم المنصة.',
    forbidden: 'لا تملك صلاحية إدارة أعضاء هذه الشركة.', failed: 'تعذر تأكيد نتيجة الإجراء. راجع الحالة الحالية قبل أي محاولة جديدة.',
    'created-sent': 'أُرسلت الدعوة. لن يحصل المستخدم على وصول أو مقعد قبل قبولها.',
    'created-failed': 'حُفظت الدعوة لكن تعذر إرسال البريد. يمكنك إعادة الإرسال.',
    'created-unknown': 'حُفظت الدعوة وحالة الإرسال غير مؤكدة. راجعها ثم أعد الإرسال عند الحاجة.',
    'reissued-sent': 'أُرسل رابط جديد وأصبح الرابط السابق غير صالح.',
    'reissued-failed': 'تجددت الدعوة لكن تعذر إرسال البريد. يمكنك إعادة الإرسال مرة أخرى.',
    'reissued-unknown': 'تجددت الدعوة وحالة الإرسال غير مؤكدة. راجع الحالة قبل إعادة الإرسال.',
    'already-member': 'هذا المستخدم عضو بالفعل في الشركة.', 'pending-exists': 'توجد دعوة معلّقة لهذا البريد. أعد إرسالها من قائمة الدعوات.',
    existing: 'يوجد طلب سابق لهذا الإجراء.', revoked: 'أُلغيت الدعوة.', expired: 'انتهت الدعوة ويمكن إصدار واحدة جديدة.',
    'revoke-unchanged': 'لم يحدث إلغاء في هذه المحاولة. قد لا تكون الدعوة متاحة أو قابلة للإلغاء. راجع حالتها الحالية.',
    'revoke-unknown': 'تعذر تأكيد نتيجة الإلغاء. راجع الحالة الحالية قبل تنفيذ إجراء آخر.',
    terminal: 'الدعوة لم تعد معلّقة، لذلك لم يُرسل بريد جديد.', 'limit-full': 'اكتمل عدد المستخدمين المسموح به. عطّل عضوية غير مستخدمة أو اطلب من مسؤول تشغيل المنصة رفع الحد.',
    reactivated: 'راجع حالة العضو وصلاحياته أدناه؛ الرابط وحده لا يؤكد إعادة التفعيل.', deactivated: 'راجع حالة العضوية أدناه؛ الرابط وحده لا يؤكد تعطيلها.',
    'admin-governed': 'تغيير مسؤول الشركة يحتاج إجراءً منفصلًا.', 'key-conflict': 'تعذر إعادة استخدام الطلب نفسه ببيانات مختلفة.',
    'issuer-lost': 'لا يمكن إعادة إرسال هذه الدعوة لأن المسؤول الذي أرسلها لم يعد يملك صلاحية إدارة الأعضاء. ألغها وأنشئ دعوة جديدة من حساب لديه الصلاحية.',
    'target-unavailable': 'لا يمكن تنفيذ هذا التغيير لأن الحساب محذوف أو محظور أو لم يؤكد بريده أو لم يكتمل إعداد كلمة مروره.',
    promoted: 'راجع دور العضو أدناه؛ الرابط وحده لا يؤكد ترقيته إلى مسؤول.',
    demoted: 'راجع الدور الحالي أدناه؛ الرابط وحده لا يؤكد خفض المسؤول.',
    already_admin: 'هذا المستخدم مسؤول بالفعل؛ لم يتغير الدور.',
    already_member: 'هذا المستخدم عضو بالفعل؛ لم يتغير الدور.',
    'role-forbidden': 'تحتاج إدارة أدوار المسؤولين إلى صلاحية إدارة الشركة وإدارة الأعضاء.',
    'last-admin': 'لا يمكن خفض آخر مسؤول يستوفي شروط إدارة الشركة. رقِّ مسؤولًا بديلًا أولًا.',
    'role-setup': 'قالب الدور الأساسي غير متاح؛ لم يتغير أي تعيين.',
    'tenant-unavailable': 'الشركة غير نشطة؛ لم يتغير أي تعيين.',
    'bundles-unchanged': 'راجع الصلاحيات الحالية أدناه؛ الرابط وحده لا يثبت نتيجة محاولة الحفظ.',
    'bundle-invalid': 'تعذر التحقق من الصلاحيات المختارة. حدّث الصفحة وأعد المحاولة.',
    'bundles-stale': 'تغيّرت صلاحيات هذا العضو منذ فتحت المحرر. راجع الحالية ثم أعد الاختيار.',
    'bundle-admin-protected': 'حساب مسؤول الشركة محمي ويُدار من إجراء إدارة المسؤولين.',
    'bundle-target-unavailable': 'يمكن تعديل الصلاحيات لعضو نشط بحساب صالح فقط. تحقق من حالة العضوية والحساب.',
  };
  return Object.hasOwn(labels, state) ? labels[state] : 'تعذر تنفيذ الإجراء.';
}
function successMessage(state?: string) {
  const messages: Record<string, string> = {
    reactivated: 'راجع حالة العضو وصلاحياته أدناه؛ الرابط وحده لا يؤكد إعادة التفعيل.', deactivated: 'راجع حالة العضوية أدناه؛ الرابط وحده لا يؤكد تعطيلها.',
    promoted: 'راجع دور العضو أدناه؛ الرابط وحده لا يؤكد ترقيته إلى مسؤول.',
    demoted: 'راجع الدور الحالي أدناه؛ الرابط وحده لا يؤكد خفض المسؤول.',
    'bundles-updated': 'راجع الصلاحيات الحالية أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.',
    'bundles-unchanged': 'راجع الصلاحيات الحالية أدناه؛ الرابط وحده لا يثبت نتيجة محاولة الحفظ.',
    'leave-self-updated': 'راجع تفعيل إجازات الموظف ودور المسؤول أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.',
  };
  return state && Object.hasOwn(messages, state) ? messages[state] : null;
}
function Status({ tenantId, title, detail }: { tenantId: string; title: string; detail: string }) {
  return <main className="app-shell"><Panel className="auth-card"><PageHeader  title={<>{title}</>} /><p className="intro">{detail}</p><ButtonLink variant="solid" href={`/tenant/${tenantId}`}>العودة إلى اليوم</ButtonLink></Panel></main>;
}
