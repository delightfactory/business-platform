import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { operatorPage, operatorTenant } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { OperatorListControls, operatorListQuery } from '@/app/operator/operator-list-controls';

export const dynamic = 'force-dynamic';


export default async function EntitlementsPage({ searchParams }: { searchParams: Promise<{ page?: string; q?: string }> }) {
  const { page, search } = operatorListQuery(await searchParams);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [{ data: status, error: statusError }, { data: authorized, error: capabilityError }] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_commercial_access'),
  ]);
  if (statusError || capabilityError) return <Status title="تعذر التحقق من الصلاحية" />;
  if (status !== 'active' || !operatorPermission({ data: authorized, error: capabilityError })) return <Status title="إدارة إتاحة الوحدات غير متاحة" />;
  const { data, error } = await supabase.rpc('platform_tenant_list_page', { p_scope: 'commercial', p_page: page, p_query: search });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل الشركات" />;
  const result = operatorPage(data, operatorTenant, row => row.tenant_id);
  if (!result) return <Status title="تعذر تحميل الشركات" />;
  const tenants = result.rows;
  const matchingCount = result.matching_count;

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator">العودة للمهام</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
    <section className="work-card operator-collection" aria-labelledby="entitlements-title">
      <p className="eyebrow">إتاحة الوحدات</p><h1 id="entitlements-title">الوحدات المتاحة للشركات</h1>
      <p className="intro">الإتاحة والإنهاء لا يحذفان بيانات الشركة. تُسجل كل مراجعة مع سببها.</p>
      <OperatorListControls basePath="/operator/entitlements" search={search} page={page} matchingCount={matchingCount} searchLabel="البحث باسم الشركة" inputId="entitlements-search" />
      {tenants.length === 0 ? <p className="intro">{matchingCount ? 'لا توجد نتائج في هذه الصفحة.' : 'لا توجد شركات مطابقة.'}</p> : <ul className="member-list">
        {tenants.map((tenant) => <li className="member-card" key={tenant.tenant_id}>
          <div><h2><bdi>{tenant.display_name}</bdi></h2><p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p></div>
          <Link className="secondary-button" href={`/operator/entitlements/${tenant.tenant_id}`}>عرض الإتاحة</Link>
        </li>)}
      </ul>}
    </section><footer className="footer">منصة الأعمال · إتاحة الوحدات</footer>
  </main>;
}

function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><Link className="secondary-button" href="/operator">العودة للمهام</Link></section></main>; }
