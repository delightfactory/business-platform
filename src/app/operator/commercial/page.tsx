import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type Tenant = { tenant_id: string; display_name: string; lifecycle_state: string };

export default async function CommercialTenantsPage() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [{ data: operatorStatus }, { data: authorized }] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_commercial_access'),
  ]);
  if (operatorStatus !== 'active' || !authorized) return <Status title="إدارة الحدود غير متاحة" />;
  const { data, error } = await supabase.rpc('platform_tenant_commercial_list');
  if (error || !Array.isArray(data)) return <Status title="تعذر تحميل الشركات" />;
  const tenants = data as Tenant[];

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator">العودة للمهام</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
    <section className="work-card operator-collection" aria-labelledby="commercial-title">
      <p className="eyebrow">الوصول التجاري</p><h1 id="commercial-title">حدود استخدام الشركات</h1>
      <p className="intro">غيّر الحد الفعّال للمستخدمين أو المواقع. خفض الحد لا يعطّل الموجود، لكنه يمنع إضافة موارد حتى يصبح الاستخدام أقل من الحد أو يُرفع الحد.</p>
      {tenants.length === 0 ? <p className="intro">لا توجد شركات بعد.</p> : <ul className="member-list">
        {tenants.map((tenant) => <li className="member-card" key={tenant.tenant_id}>
          <div><h2>{tenant.display_name}</h2><p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p></div>
          <Link className="secondary-button" href={`/operator/commercial/${tenant.tenant_id}`}>عرض الحدود والاستخدام</Link>
        </li>)}
      </ul>}
    </section><footer className="footer">منصة الأعمال · حدود الاستخدام</footer>
  </main>;
}

function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><Link className="secondary-button" href="/operator">العودة للمهام</Link></section></main>; }
