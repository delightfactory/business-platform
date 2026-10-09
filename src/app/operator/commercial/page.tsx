import { Button, ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { operatorPage, operatorTenant } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { OperatorListControls, operatorListQuery } from '@/app/operator/operator-list-controls';

export const dynamic = 'force-dynamic';


export default async function CommercialTenantsPage({ searchParams }: { searchParams: Promise<{ page?: string; q?: string }> }) {
  const { page, search } = operatorListQuery(await searchParams);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [{ data: operatorStatus, error: statusError }, { data: authorized, error: capabilityError }] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_commercial_access'),
  ]);
  if (statusError || capabilityError) return <Status title="تعذر التحقق من الصلاحية" />;
  if (operatorStatus !== 'active' || !operatorPermission({ data: authorized, error: capabilityError })) return <Status title="إدارة الحدود غير متاحة" />;
  const { data, error } = await supabase.rpc('platform_tenant_list_page', { p_scope: 'commercial', p_page: page, p_query: search });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل الشركات" />;
  const result = operatorPage(data, operatorTenant, row => row.tenant_id);
  if (!result) return <Status title="تعذر تحميل الشركات" />;
  const tenants = result.rows;
  const matchingCount = result.matching_count;

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><ButtonLink variant="ghost" className="secondary-button" href="/operator">العودة للمهام</ButtonLink>
        <form action={signOutAction}><Button variant="ghost" className="secondary-button" type="submit">تسجيل الخروج</Button></form></nav></header>
    <section className="work-card operator-collection" aria-labelledby="commercial-title">
      <p className="eyebrow">الوصول التجاري</p><h1 id="commercial-title">حدود استخدام الشركات</h1>
      <p className="intro">غيّر حد المستخدمين أو الفروع. خفض الحد لا يعطّل الموجود، لكنه يمنع إضافة المزيد حتى يصبح الاستخدام أقل من الحد أو يُرفع الحد.</p>
      <OperatorListControls basePath="/operator/commercial" search={search} page={page} matchingCount={matchingCount} searchLabel="البحث باسم الشركة" inputId="commercial-search" />
      {tenants.length === 0 ? <p className="intro">{matchingCount ? 'لا توجد نتائج في هذه الصفحة.' : 'لا توجد شركات مطابقة.'}</p> : <ul className="member-list">
        {tenants.map((tenant) => <li className="member-card" key={tenant.tenant_id}>
          <div><h2>{tenant.display_name}</h2><p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p></div>
          <ButtonLink variant="ghost" className="secondary-button" href={`/operator/commercial/${tenant.tenant_id}`}>عرض الحدود والاستخدام</ButtonLink>
        </li>)}
      </ul>}
    </section>
  </main>;
}

function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><ButtonLink variant="ghost" className="secondary-button" href="/operator">العودة للمهام</ButtonLink></section></main>; }
