import { PageHeader, Disclosure, RecordCard, Badge } from '@/components/ui';
import { Panel, Message, Checkbox } from '@/components/ui';
import { Button, ButtonLink, Input, Textarea } from '@/components/ui';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeOperatorGrantAction } from './actions';
import { operatorPermission } from '@/lib/operator-access';
import { OperatorActionForm } from '@/app/operator/operator-action-form';
import { operatorGrantList, type OperatorGrant } from '@/lib/operator-read';

export const dynamic = 'force-dynamic';
type Query = Promise<{ state?: string }>;
type Grant = OperatorGrant;

export default async function OperatorGrantsPage({ searchParams }: { searchParams: Query }) {
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError) return <Status title="تعذر التحقق من الحساب" detail="أعد قراءة الصفحة للتحقق من حسابك قبل تغيير أي صلاحية." />;
  if (!user) redirect('/auth/login?state=no-session');
  const status = await supabase.rpc('current_platform_operator_status');
  const canManage = await supabase.rpc('current_operator_can_manage_operators');
  if (status.error || canManage.error || !['active', 'revoked', 'not_operator'].includes(status.data) || typeof canManage.data !== 'boolean') return <Status title="تعذر التحقق من الصلاحية" detail="لم تتأكد صلاحية إدارة المشغّلين الآن. أعد قراءة الصفحة قبل أي تغيير." />;
  if (status.data !== 'active' || !operatorPermission(canManage)) return <Status denied title="إدارة المشغّلين غير متاحة" detail="تحتاج هذه الصفحة إلى صلاحية إدارة المشغّلين الحالية." />;
  const { data, error } = await supabase.rpc('platform_operator_grant_list');
  const grants = error ? null : operatorGrantList(data);
  if (!grants) return <Status title="تعذر تحميل المنح" detail="لم تتأكد قائمة المنح الحالية. أعد قراءة الصفحة قبل إجراء أي تغيير." />;
  const success = query.state === 'granted' || query.state === 'updated' || query.state === 'revoked';

  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب"><ButtonLink variant="ghost"  href="/operator">العودة للمهام</ButtonLink>
          <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form></nav></header>
      <Panel className="operator-grants-overview" aria-labelledby="operators-title">
        <p className="eyebrow">صلاحيات المنصة</p><PageHeader id="operators-title" title={<>مشغّلو المنصة</>} />
        {success && <Message tone="info"  role="status">راجع المنح الحالية أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.</Message>}
        <p className="intro">حدد من يمكنه تشغيل المنصة والمهام المسموح له بها. يُسجل سبب كل تغيير.</p>
        {query.state && !success && <Message tone="bad"  role="alert">{stateText(query.state)}</Message>}
        <Disclosure summary={<>إضافة مشغّل</>} className="operator-grant-form">

          <OperatorActionForm action={changeOperatorGrantAction} errorMessages={operatorErrors} label="تأكيد منح الصلاحية المحددة">
            <h2>منح صلاحية مشغّل</h2>
            <label htmlFor="newEmail">بريد الحساب المؤكد</label>
            <Input id="newEmail" name="email" type="email" autoComplete="email" required maxLength={254} dir="ltr" />
            <CapabilityFields prefix="new" />
            <label htmlFor="newReason">سبب المنح</label>
            <Textarea id="newReason" name="reason" required minLength={3} maxLength={500} rows={3} />
            <input type="hidden" name="action" value="grant" />
            <p className="field-hint">يجب أن يكون الحساب موجودًا، مؤكد البريد، وقادرًا على تسجيل الدخول. لا تُنشئ هذه الصفحة حسابات جديدة.</p>
          </OperatorActionForm>
        </Disclosure>
      </Panel>
      <Panel className="operator-grants-list" aria-labelledby="grants-list-title">
        <h2 id="grants-list-title">المشغّلون</h2>
        <form method="get" action="/operator/operators"><Button variant="ghost"  type="submit" aria-describedby="grants-reread-hint">إعادة قراءة المنح</Button></form>
        <p className="field-hint" id="grants-reread-hint">إعادة القراءة تجلب الحالة الحالية وتُفقد أي إدخالات لم تُرسل. لا تؤكد وحدها نتيجة تغيير سابق غير مؤكدة.</p>
        {grants.length === 0 ? <p>لا توجد منح مشغّل محفوظة.</p> : <ul className="member-list">
          {grants.map((grant) => <RecordCard className="member-card" key={grant.user_id}>
            <div><h3><bdi>{grant.email}</bdi></h3>
              <Badge as="p" className={` ${grant.is_active ? 'is-active' : 'is-inactive'}`}>{grant.is_active ? 'نشط' : 'مسحوب'}</Badge>
              {!grant.recoverable && <p className="field-hint">الحساب غير جاهز لتسجيل الدخول</p>}
              <ul className="operator-capability-list" aria-label="المهام الممنوحة">{capabilityNames(grant).length ? capabilityNames(grant).map((name) => <li key={name}>{name}</li>) : <li>لا توجد مهام حاليًا</li>}</ul>
            </div>
            <div className="operator-grant-actions">
              {grant.recoverable && <>
              <details className="role-change-confirmation"><summary className="secondary-button" aria-label={`${grant.is_active ? 'تعديل المهام' : 'إعادة منح المهام'}: ${grant.email}`}>{grant.is_active ? 'تعديل المهام' : 'إعادة منح المهام'}</summary>
                <p className="field-hint">الحساب: <bdi>{grant.email}</bdi></p>
                <OperatorActionForm key={grant.is_active ? 'update' : 'grant'} action={changeOperatorGrantAction} errorMessages={operatorErrors} className="auth-form compact-form" buttonClassName="secondary-button" label={grant.is_active ? 'تأكيد التعديل' : 'تأكيد إعادة المنح'}>
                  <input type="hidden" name="email" value={grant.email} />
                  <input type="hidden" name="action" value={grant.is_active ? 'update' : 'grant'} />
                  <CapabilityFields prefix={grant.user_id} defaults={grant} />
                  <label htmlFor={`reason-${grant.user_id}`}>{grant.is_active ? 'سبب التعديل' : 'سبب إعادة المنح'}</label>
                  <Textarea id={`reason-${grant.user_id}`} name="reason" required minLength={3} maxLength={500} rows={2} />
                </OperatorActionForm>
              </details></>}
              {grant.is_active && <details className="role-change-confirmation"><summary className="secondary-button danger-action" aria-label={`سحب الصلاحية: ${grant.email}`}>سحب الصلاحية</summary>
                <p className="field-hint">سيُوقف هذا المنح وتُسحب كل المهام المرتبطة به. يُحفظ السبب وسجل ما قبل/بعد التغيير.</p>
                <p className="field-hint">الحساب: <bdi>{grant.email}</bdi></p>
                <OperatorActionForm action={changeOperatorGrantAction} errorMessages={operatorErrors} className="auth-form compact-form" buttonClassName="secondary-button" label="تأكيد سحب الصلاحية">
                  <input type="hidden" name="email" value={grant.email} /><input type="hidden" name="action" value="revoke" />
                  <input type="hidden" name="canManageOperators" value="off" /><input type="hidden" name="canOnboardTenants" value="off" />
                  <label htmlFor={`revoke-reason-${grant.user_id}`}>سبب السحب</label>
                  <Textarea id={`revoke-reason-${grant.user_id}`} name="reason" required minLength={3} maxLength={500} rows={2} />
                </OperatorActionForm>
              </details>}
            </div>
          </RecordCard>)}
        </ul>}
      </Panel>
    </main>
  );
}

function CapabilityFields({ prefix, defaults }: { prefix: string; defaults?: Pick<Grant, 'can_manage_operators' | 'can_onboard_tenants' | 'can_manage_tenant_lifecycle' | 'can_manage_commercial_access' | 'can_manage_statutory_rules'> }) {
  return <fieldset className="limit-fields"><legend>المهام الممنوحة</legend>
    <label className="check-option"><Checkbox  name="canManageOperators" defaultChecked={defaults?.can_manage_operators ?? false} /> إدارة المشغّلين</label>
    <label className="check-option"><Checkbox  name="canOnboardTenants" defaultChecked={defaults?.can_onboard_tenants ?? false} /> إعداد الشركات</label>
    <label className="check-option"><Checkbox  name="canManageTenantLifecycle" defaultChecked={defaults?.can_manage_tenant_lifecycle ?? false} /> تعليق الشركات واستعادتها وأرشفتها</label>
    <label className="check-option"><Checkbox  name="canManageCommercialAccess" defaultChecked={defaults?.can_manage_commercial_access ?? false} /> إدارة حدود الاستخدام</label>
    <label className="check-option"><Checkbox  name="canManageStatutoryRules" defaultChecked={defaults?.can_manage_statutory_rules ?? false} /> إدارة القواعد القانونية للرواتب</label>
    <p className="field-hint">تُمنح مهمة القواعد القانونية لمسؤول الامتثال صراحةً. لا يمنحها إعداد الشركات أو إدارة الرواتب، ولا يعني منحها اعتماد أي حزمة قانونية.</p>
    <span className="field-hint" id={`${prefix}-capability-hint`}>اختر مهمة واحدة على الأقل. سحب الصلاحيات يتم بإجراء مستقل.</span>
  </fieldset>;
}

function capabilityNames(grant: Grant) {
  return [grant.can_manage_operators && 'إدارة المشغّلين', grant.can_onboard_tenants && 'إعداد الشركات',
    grant.can_manage_tenant_lifecycle && 'إدارة حالة الشركات', grant.can_manage_commercial_access && 'إدارة حدود الاستخدام', grant.can_manage_statutory_rules && 'إدارة القواعد القانونية للرواتب'].filter((name): name is string => Boolean(name));
}

function stateText(state: string) {
  return operatorErrors[state] ?? 'تعذر إتمام الإجراء.';
}
const operatorErrors: Record<string, string> = {
    granted: 'مُنحت المهام المحددة وسُجل السبب.', updated: 'حُدّثت المهام وسُجلت حالة ما قبل التغيير وبعده.',
    revoked: 'سُحبت صلاحية المشغّل وسُجل السبب.', 'already-active': 'للحساب منح نشط بالفعل؛ استخدم تعديل المهام.',
    'already-revoked': 'المنح مسحوب بالفعل.', 'not-active': 'لا يوجد منح نشط لتعديله.', unchanged: 'لم يتغير المنح.',
    invalid: 'تحقق من البريد والإجراء المحدد.', capability: 'اختر مهمة واحدة على الأقل؛ استخدم إجراء السحب المنفصل لإزالة الصلاحية.',
    reason: 'أدخل سببًا من 3 إلى 500 حرف.', setup: 'إعداد Supabase غير مكتمل.', forbidden: 'لا تسمح صلاحيتك الحالية بإدارة المشغّلين.',
    'target-unavailable': 'الحساب غير موجود أو لم يؤكد بريده أو لا يستطيع تسجيل الدخول بعد.',
    'last-manager': 'لا يمكن سحب مهمة إدارة المشغّلين من آخر مدير مؤهل.',
    unavailable: 'تعذر التحقق من الحساب قبل الإرسال. احتفظ بالبيانات وراجع حسابك وصلاحيتك.',
    failed: 'نتيجة التغيير غير مؤكدة. راجع المنح الحالية قبل إجراء تغيير آخر؛ لا تُعد الإرسال اعتمادًا على هذه الرسالة وحدها.',
};
function Status({ title, detail, denied = false }: { title: string; detail: string; denied?: boolean }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header>
    <Panel className="auth-card" aria-labelledby="status-title"><p className="eyebrow">صلاحيات المنصة</p>
      <PageHeader id="status-title" title={<>{title}</>} /><p className="intro">{detail}</p>
      <form method="get" action="/operator/operators"><Button variant="ghost" className={denied ? 'secondary-button' : 'primary-button'} type="submit">إعادة قراءة الصفحة</Button></form>
      <ButtonLink variant="ghost" className={denied ? 'primary-button' : 'secondary-button'} href="/operator">العودة لمهام المنصة</ButtonLink></Panel></main>;
}
