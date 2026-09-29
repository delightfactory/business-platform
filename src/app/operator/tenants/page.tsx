import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type Tenant = { tenant_id: string; tenant_name: string; lifecycle_state: 'active' | 'suspended' | 'archived' };

export default async function OperatorTenantsPage() {
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
  if (error || !Array.isArray(data)) return <Status title="تعذر تحميل الشركات" detail="أعد المحاولة لاحقًا." />;
  const tenants = data as Tenant[];

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب">
          <Link className="secondary-button" href="/operator">العودة للمهام</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
        </nav>
      </header>
      <section className="work-card operator-collection" aria-labelledby="tenants-title">
        <p className="eyebrow">إدارة حالة الشركات</p>
        <h1 id="tenants-title">الشركات</h1>
        <p className="intro">تُسجل كل عملية تعليق أو استعادة أو أرشفة مع سببها.</p>
        {tenants.length === 0 ? <p className="intro">لا توجد شركات بعد.</p> : (
          <ul className="member-list">
            {tenants.map((tenant) => (
              <li className="member-card" key={tenant.tenant_id}>
                <div>
                  <h2>{tenant.tenant_name}</h2>
                  <p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p>
                </div>
                <Link className="secondary-button" href={`/operator/tenants/${tenant.tenant_id}`}>عرض الحالة والإجراءات</Link>
              </li>
            ))}
          </ul>
        )}
      </section>
      <footer className="footer">منصة الأعمال · إدارة حالة الشركات</footer>
    </main>
  );
}

export function stateLabel(state: string) {
  if (state === 'active') return 'نشطة';
  if (state === 'suspended') return 'معلّقة';
  if (state === 'archived') return 'مؤرشفة';
  return 'غير متاحة';
}

function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header>
    <section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">إدارة حالة الشركات</p>
      <h1 id="status-title">{title}</h1><p className="intro">{detail}</p></section></main>;
}
