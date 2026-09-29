import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeTenantLifecycleAction } from '../actions';

export const dynamic = 'force-dynamic';

type Tenant = { tenant_id: string; tenant_name: string; lifecycle_state: 'active' | 'suspended' | 'archived' };
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
  const [{ data: operatorStatus }, { data: canManageLifecycle }] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle'),
  ]);
  if (operatorStatus !== 'active' || !canManageLifecycle) {
    return <Status title="إدارة حالة الشركات غير متاحة" detail="تحتاج هذه الصفحة إلى صلاحية إدارة حالة الشركات الحالية." />;
  }
  const { data, error } = await supabase.rpc('platform_tenant_lifecycle_list');
  const tenant = !error && Array.isArray(data)
    ? (data as Tenant[]).find((item) => item.tenant_id === tenantId)
    : undefined;
  if (!tenant) return <Status title="الشركة غير متاحة" detail="لم نعثر على شركة بهذه البيانات." />;

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
      <section className="work-card" aria-labelledby="tenant-title">
        <p className="eyebrow">إدارة حالة الشركة</p>
        <h1 id="tenant-title">{tenant.tenant_name}</h1>
        <p className="intro">الحالة الحالية: <strong>{stateLabel(tenant.lifecycle_state)}</strong></p>
        {query.state === 'stale' && <p className="form-message" role="status">تغيّرت حالة الشركة منذ فتح الصفحة. راجع الحالة الحالية قبل اختيار إجراء جديد.</p>}
        {query.state && query.state !== 'stale' && query.state !== 'updated'
          && <p className="form-message" role="status">{messageFor(query.state)}</p>}
        {query.state === 'updated' && query.to === tenant.lifecycle_state
          ? <p className="form-message" role="status">تم حفظ الحالة الجديدة وسجل السبب.</p>
          : query.state === 'updated' && <p className="form-message" role="status">تغيّرت حالة الشركة بعد الإجراء. الحالة الحالية معروضة أدناه.</p>}
        <div className="lifecycle-actions">
          {transitions.map((transition) => (
            <details className="role-change-confirmation" key={transition.target}>
              <summary className="secondary-button">{transition.label}</summary>
              <p className="field-hint">أنت على وشك {transition.label} الشركة <bdi>{tenant.tenant_name}</bdi>. {transition.description}</p>
              <form action={changeTenantLifecycleAction} className="auth-form compact-form">
                <input type="hidden" name="tenantId" value={tenant.tenant_id} />
                <input type="hidden" name="expectedState" value={tenant.lifecycle_state} />
                <input type="hidden" name="targetState" value={transition.target} />
                <label htmlFor={`reason-${transition.target}`}>سبب الإجراء</label>
                <textarea id={`reason-${transition.target}`} name="reason" required minLength={3} maxLength={500} rows={3} />
                <button className="primary-button" type="submit">تأكيد الإجراء وحفظ السبب</button>
              </form>
            </details>
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
  const messages: Record<string, string> = {
    active: 'أُعيد تشغيل الشركة.', suspended: 'عُلّقت الشركة.', archived: 'أُرشفت الشركة.',
    invalid: 'تعذر التحقق من الإجراء.', reason: 'أدخل سببًا من 3 إلى 500 حرف.',
    transition: 'هذا الانتقال غير مسموح من الحالة الحالية.',
    forbidden: 'لا تسمح صلاحيتك الحالية بإدارة حالة الشركات.',
    'not-found': 'لم نعثر على الشركة المطلوبة.',
    failed: 'تعذر حفظ التغيير. لم تُعتمد أي حالة بلا سجل تدقيق.',
    setup: 'إعداد الاتصال غير مكتمل.',
  };
  return messages[state] ?? 'تعذر إتمام الإجراء.';
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator/tenants">قائمة الشركات</Link></header>
    <section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">إدارة حالة الشركات</p>
      <h1 id="status-title">{title}</h1><p className="intro">{detail}</p></section></main>;
}
