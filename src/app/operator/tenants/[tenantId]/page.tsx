import Link from 'next/link';
import { operatorLifecycleSnapshot } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeTenantLifecycleAction } from '../actions';
import { CompanyTaskLinks } from '@/app/operator/company-task-links';
import { operatorPermission, sameCompanyScope } from '@/lib/operator-access';
import { OperatorActionForm } from '@/app/operator/operator-action-form';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string; to?: string }>;

export default async function OperatorTenantLifecyclePage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) return <Status title="الشركة غير متاحة" detail="لم نعثر على شركة بهذه البيانات." />;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [operatorStatus, lifecycle, commercial] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle'),
    supabase.rpc('current_operator_can_manage_commercial_access').then(result => result, (error: unknown) => ({ data: null, error })),
  ]);
  if (operatorStatus.error || operatorStatus.data !== 'active' || !operatorPermission(lifecycle)) {
    return <Status title="إدارة حالة الشركات غير متاحة" detail="تحتاج هذه الصفحة إلى صلاحية إدارة حالة الشركات الحالية." />;
  }
  const { data, error } = await supabase.rpc('platform_tenant_lifecycle_get', { p_tenant_id: tenantId });
  const tenant = !error && operatorLifecycleSnapshot(data) ? data : undefined;
  if (error) return <Status title="تعذر قراءة حالة الشركة" detail="لم تتأكد الحالة الحالية. ارجع لقائمة الشركات وأعد قراءة الشركة المطلوبة." />;
  if (!tenant || !sameCompanyScope(tenant.tenant_id, tenantId)) return <Status title="بيانات الشركة غير مكتملة" detail="لا يمكن عرض إجراءات بناءً على بيانات غير متحققة. راجع قائمة الشركات." />;

  const transitions = transitionsFor(tenant.lifecycle_state);
  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب">
          <Link className="secondary-button" href="/operator/tenants">قائمة الشركات</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
        </nav>
      </header>
      <section className="work-card operator-lifecycle-detail" aria-labelledby="tenant-title">
        <p className="eyebrow">إدارة حالة الشركة</p>
        <h1 id="tenant-title"><bdi>{tenant.tenant_name}</bdi></h1>
        <p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : tenant.lifecycle_state === 'suspended' ? 'is-pending' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p>
        <CompanyTaskLinks tenantId={tenantId} current="lifecycle" lifecycle={true} commercial={operatorPermission(commercial)} />
        {((query.state === 'updated' && (!query.to || query.to === tenant.lifecycle_state)) || query.state === 'active' || query.state === 'suspended' || query.state === 'archived') && <p className="form-message" role="status">راجع حالة الشركة الحالية والإجراءات المتاحة أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.</p>}
        <p className="intro">اختر الإجراء المناسب. سيتطلب تأكيده سببًا ويُسجل التغيير للمراجعة.</p>
        {query.state === 'stale' && <p className="form-message capacity-message" role="alert">تغيّرت حالة الشركة منذ فتح الصفحة. راجع الحالة الحالية قبل اختيار إجراء جديد.</p>}
        {query.state && !['stale', 'updated', 'active', 'suspended', 'archived'].includes(query.state)
          && <p className="form-message form-error" role="alert">{messageFor(query.state)}</p>}
        {query.state === 'updated' && query.to && query.to !== tenant.lifecycle_state
          && <p className="form-message capacity-message" role="status">الحالة الحالية لا تطابق الحالة المطلوبة في الرابط. راجعها قبل اختيار إجراء جديد.</p>}
        <h2>الإجراءات المتاحة</h2>
        <div className="lifecycle-choice-list">
          {transitions.map((transition) => (
            <article className="lifecycle-choice" key={transition.target}>
              <div><h3>{transition.label}</h3><p>{transition.description}</p></div>
              <details className="role-change-confirmation">
              <summary className={`secondary-button ${transition.target === 'archived' ? 'danger-action' : ''}`}>متابعة {transition.label}</summary>
              <p className="field-hint">سيُطبق هذا الإجراء على <bdi>{tenant.tenant_name}</bdi>.</p>
              <OperatorActionForm action={changeTenantLifecycleAction} errorMessages={lifecycleErrors} className="auth-form compact-form" buttonClassName={transition.target === 'archived' ? 'danger-button' : 'primary-button'} label={`تأكيد ${transition.label} وتسجيل السبب`}>
                <input type="hidden" name="tenantId" value={tenant.tenant_id} />
                <input type="hidden" name="expectedState" value={tenant.lifecycle_state} />
                <input type="hidden" name="targetState" value={transition.target} />
                <label htmlFor={`reason-${transition.target}`}>سبب الإجراء</label>
                <textarea id={`reason-${transition.target}`} name="reason" required minLength={3} maxLength={500} rows={3} />
              </OperatorActionForm>
              </details>
            </article>
          ))}
        </div>
      </section>
      <footer className="footer">منصة الأعمال · إدارة حالة الشركات</footer>
    </main>
  );
}

function transitionsFor(state: string) {
  if (state === 'active') return [
    { target: 'suspended', label: 'تعليق الشركة', description: 'يوقف ذلك وصول المستخدمين إلى بيانات الشركة حتى استعادة التشغيل.' },
    { target: 'archived', label: 'أرشفة الشركة', description: 'تمنع الأرشفة وصول المستخدمين. الاستعادة تعيد الشركة إلى حالة معلّقة أولًا.' },
  ];
  if (state === 'suspended') return [
    { target: 'active', label: 'استعادة التشغيل', description: 'يعيد ذلك وصول المستخدمين إلى الشركة.' },
    { target: 'archived', label: 'أرشفة الشركة', description: 'تمنع الأرشفة وصول المستخدمين. الاستعادة تعيد الشركة إلى حالة معلّقة أولًا.' },
  ];
  if (state === 'archived') return [
    { target: 'suspended', label: 'استعادة إلى حالة معلّقة', description: 'ستبقى بيانات العمل محجوبة. يلزم إجراء منفصل لاستعادة التشغيل.' },
  ];
  return [];
}

function stateLabel(state: string) {
  if (state === 'active') return 'نشطة';
  if (state === 'suspended') return 'معلّقة';
  if (state === 'archived') return 'مؤرشفة';
  return 'غير متاحة';
}

function messageFor(state: string) {
  return Object.hasOwn(lifecycleErrors, state) ? lifecycleErrors[state] : 'نتيجة الإجراء غير مؤكدة. راجع حالة الشركة قبل إجراء آخر.';
}
const lifecycleErrors: Record<string, string> = {
    active: 'أُعيد تشغيل الشركة.', suspended: 'عُلّقت الشركة.', archived: 'أُرشفت الشركة.',
    invalid: 'تعذر التحقق من الإجراء.', reason: 'أدخل سببًا من 3 إلى 500 حرف.',
    transition: 'هذا الانتقال غير مسموح من الحالة الحالية.',
    forbidden: 'لا تسمح صلاحيتك الحالية بإدارة حالة الشركات.',
    'not-found': 'لم نعثر على الشركة المطلوبة.',
    failed: 'لم تتأكد نتيجة تغيير الحالة. راجع حالة الشركة الحالية قبل إجراء آخر.',
    setup: 'إعداد الاتصال غير مكتمل.',
};

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator/tenants">قائمة الشركات</Link></header>
    <section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">إدارة حالة الشركات</p>
      <h1 id="status-title">{title}</h1><p className="intro">{detail}</p></section></main>;
}
