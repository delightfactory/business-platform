import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeOperatorGrantAction } from './actions';

export const dynamic = 'force-dynamic';
type Query = Promise<{ state?: string }>;
type Grant = {
  user_id: string; email: string; is_active: boolean; can_manage_operators: boolean;
  can_onboard_tenants: boolean; can_manage_tenant_lifecycle: boolean; can_manage_commercial_access: boolean; recoverable: boolean; updated_at: string;
};

export default async function OperatorGrantsPage({ searchParams }: { searchParams: Query }) {
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data: status } = await supabase.rpc('current_platform_operator_status');
  const { data: canManage } = await supabase.rpc('current_operator_can_manage_operators');
  if (status !== 'active' || !canManage) return <Status title="إدارة المشغّلين غير متاحة" detail="تحتاج هذه الصفحة إلى صلاحية إدارة المشغّلين الحالية." />;
  const { data, error } = await supabase.rpc('platform_operator_grant_list');
  if (error || !Array.isArray(data)) return <Status title="تعذر تحميل المنح" detail="أعد المحاولة لاحقًا. لم يتغير أي منح." />;
  const grants = data as Grant[];

  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator">العودة للمهام</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
      <section className="work-card" aria-labelledby="operators-title">
        <p className="eyebrow">صلاحيات المنصة</p><h1 id="operators-title">مشغّلو المنصة</h1>
        <p className="intro">تُدار هنا مهام المشغّلين وإعداد الشركات وإدارة حالة الشركات وحدود الاستخدام. السبب مطلوب لكل تغيير.</p>
        {query.state && <p className="form-message" role="status">{stateText(query.state)}</p>}
        <details className="operator-grant-form">
          <summary className="secondary-button">إضافة مهمة لمستخدم موجود</summary>
          <form action={changeOperatorGrantAction} className="auth-form">
            <h2>منح صلاحية مشغّل</h2>
            <label htmlFor="newEmail">بريد الحساب المؤكد</label>
            <input id="newEmail" name="email" type="email" autoComplete="email" required maxLength={254} dir="ltr" />
            <CapabilityFields prefix="new" />
            <label htmlFor="newReason">سبب المنح</label>
            <textarea id="newReason" name="reason" required minLength={3} maxLength={500} rows={3} />
            <input type="hidden" name="action" value="grant" />
            <p className="field-hint">يجب أن يكون الحساب موجودًا، مؤكد البريد، وقادرًا على تسجيل الدخول. لا تُنشئ هذه الصفحة حسابات جديدة.</p>
            <button className="primary-button" type="submit">تأكيد منح الصلاحية المحددة</button>
          </form>
        </details>
        <h2>المنح الحالية والسابقـة</h2>
        {grants.length === 0 ? <p>لا توجد منح مشغّل محفوظة.</p> : <ul className="member-list">
          {grants.map((grant) => <li className="member-card" key={grant.user_id}>
            <div><h3><bdi>{grant.email}</bdi></h3>
              <p>{grant.is_active ? 'منح نشط' : 'مسحوب'} · {grant.recoverable ? 'الحساب قابل للدخول' : 'الحساب غير جاهز للدخول'}</p>
              <p>{capabilityNames(grant)}</p>
            </div>
            <div className="operator-grant-actions">
              {grant.recoverable && <>
              <details className="role-change-confirmation"><summary className="secondary-button">{grant.is_active ? 'تعديل المهام' : 'إعادة منح المهام'}</summary>
                <form action={changeOperatorGrantAction} className="auth-form compact-form">
                  <input type="hidden" name="email" value={grant.email} />
                  <input type="hidden" name="action" value={grant.is_active ? 'update' : 'grant'} />
                  <CapabilityFields prefix={grant.user_id} defaults={grant} />
                  <label htmlFor={`reason-${grant.user_id}`}>{grant.is_active ? 'سبب التعديل' : 'سبب إعادة المنح'}</label>
                  <textarea id={`reason-${grant.user_id}`} name="reason" required minLength={3} maxLength={500} rows={2} />
                  <button className="secondary-button" type="submit">{grant.is_active ? 'تأكيد التعديل' : 'تأكيد إعادة المنح'}</button>
                </form>
              </details></>}
              {grant.is_active && <details className="role-change-confirmation"><summary className="secondary-button">سحب صلاحية المشغّل</summary>
                <p className="field-hint">سيُوقف هذا المنح وتُسحب كل المهام المرتبطة به. يُحفظ السبب وسجل ما قبل/بعد التغيير.</p>
                <form action={changeOperatorGrantAction} className="auth-form compact-form">
                  <input type="hidden" name="email" value={grant.email} /><input type="hidden" name="action" value="revoke" />
                  <input type="hidden" name="canManageOperators" value="off" /><input type="hidden" name="canOnboardTenants" value="off" />
                  <label htmlFor={`revoke-reason-${grant.user_id}`}>سبب السحب</label>
                  <textarea id={`revoke-reason-${grant.user_id}`} name="reason" required minLength={3} maxLength={500} rows={2} />
                  <button className="secondary-button" type="submit">تأكيد سحب الصلاحية</button>
                </form>
              </details>}
            </div>
          </li>)}
        </ul>}
      </section><footer className="footer">منصة الأعمال · إدارة المشغّلين</footer>
    </main>
  );
}

function CapabilityFields({ prefix, defaults }: { prefix: string; defaults?: Pick<Grant, 'can_manage_operators' | 'can_onboard_tenants' | 'can_manage_tenant_lifecycle' | 'can_manage_commercial_access'> }) {
  return <fieldset className="limit-fields"><legend>المهام الممنوحة</legend>
    <label className="check-option"><input type="checkbox" name="canManageOperators" defaultChecked={defaults?.can_manage_operators ?? false} /> إدارة المشغّلين</label>
    <label className="check-option"><input type="checkbox" name="canOnboardTenants" defaultChecked={defaults?.can_onboard_tenants ?? false} /> إعداد الشركات</label>
    <label className="check-option"><input type="checkbox" name="canManageTenantLifecycle" defaultChecked={defaults?.can_manage_tenant_lifecycle ?? false} /> تعليق الشركات واستعادتها وأرشفتها</label>
    <label className="check-option"><input type="checkbox" name="canManageCommercialAccess" defaultChecked={defaults?.can_manage_commercial_access ?? false} /> إدارة حدود الاستخدام</label>
    <span className="field-hint" id={`${prefix}-capability-hint`}>اختر مهمة واحدة على الأقل. سحب الصلاحيات يتم بإجراء مستقل.</span>
  </fieldset>;
}

function capabilityNames(grant: Grant) {
  return [grant.can_manage_operators && 'إدارة المشغّلين', grant.can_onboard_tenants && 'إعداد الشركات',
    grant.can_manage_tenant_lifecycle && 'إدارة حالة الشركات', grant.can_manage_commercial_access && 'إدارة حدود الاستخدام'].filter(Boolean).join(' · ') || 'لا توجد مهمة';
}

function stateText(state: string) {
  const messages: Record<string, string> = {
    granted: 'مُنحت المهام المحددة وسُجل السبب.', updated: 'حُدّثت المهام وسُجلت حالة ما قبل التغيير وبعده.',
    revoked: 'سُحبت صلاحية المشغّل وسُجل السبب.', 'already-active': 'للحساب منح نشط بالفعل؛ استخدم تعديل المهام.',
    'already-revoked': 'المنح مسحوب بالفعل.', 'not-active': 'لا يوجد منح نشط لتعديله.', unchanged: 'لم يتغير المنح.',
    invalid: 'تحقق من البريد والإجراء المحدد.', capability: 'اختر مهمة واحدة على الأقل؛ استخدم إجراء السحب المنفصل لإزالة الصلاحية.',
    reason: 'أدخل سببًا من 3 إلى 500 حرف.', setup: 'إعداد Supabase غير مكتمل.', forbidden: 'لا تسمح صلاحيتك الحالية بإدارة المشغّلين.',
    'target-unavailable': 'الحساب غير موجود أو لم يؤكد بريده أو لا يستطيع تسجيل الدخول بعد.',
    'last-manager': 'لا يمكن سحب مهمة إدارة المشغّلين من آخر مدير مؤهل.', failed: 'تعذر حفظ التغيير. لم تُعتمد أي حالة بلا سجل تدقيق.',
  };
  return messages[state] ?? 'تعذر إتمام الإجراء.';
}
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header>
    <section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">صلاحيات المنصة</p>
      <h1 id="status-title">{title}</h1><p className="intro">{detail}</p></section><footer className="footer">منصة الأعمال</footer></main>;
}
