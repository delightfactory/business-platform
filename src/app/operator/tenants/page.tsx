import { PageHeader, RecordCard, Badge } from '@/components/ui';
import { Panel } from '@/components/ui';
import { Button, ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { operatorPage, operatorTenant } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { OperatorListControls, operatorListQuery } from '@/app/operator/operator-list-controls';

export const dynamic = 'force-dynamic';



export default async function OperatorTenantsPage({ searchParams }: { searchParams: Promise<{ page?: string; q?: string }> }) {
  const { page, search } = operatorListQuery(await searchParams);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [{ data: operatorStatus, error: statusError }, { data: canManageLifecycle, error: capabilityError }] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle'),
  ]);
  if (statusError || capabilityError) return <Status title="تعذر التحقق من الصلاحية" detail="تعذر التحقق من مهامك الآن. أعد تحميل الصفحة." />;
  if (operatorStatus !== 'active' || !operatorPermission({ data: canManageLifecycle, error: capabilityError })) {
    return <Status title="إدارة حالة الشركات غير متاحة" detail="تحتاج هذه الصفحة إلى صلاحية إدارة حالة الشركات الحالية." />;
  }
  const { data, error } = await supabase.rpc('platform_tenant_list_page', { p_scope: 'lifecycle', p_page: page, p_query: search });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل الشركات" detail="أعد المحاولة لاحقًا." />;
  const result = operatorPage(data, operatorTenant, row => row.tenant_id);
  if (!result) return <Status title="تعذر تحميل الشركات" detail="بيانات القائمة غير مكتملة. أعد تحميل الصفحة؛ لم تتأكد قائمة فارغة." />;
  const tenants = result.rows;
  const matchingCount = result.matching_count;

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب">
          <ButtonLink variant="ghost"  href="/operator">العودة للمهام</ButtonLink>
          <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form>
        </nav>
      </header>
      <Panel className="operator-collection" aria-labelledby="tenants-title">
        <p className="eyebrow">إدارة حالة الشركات</p>
        <PageHeader id="tenants-title" title={<>الشركات</>} />
        <p className="intro">تُسجل كل عملية تعليق أو استعادة أو أرشفة مع سببها.</p>
        <OperatorListControls basePath="/operator/tenants" search={search} page={page} matchingCount={matchingCount} searchLabel="البحث باسم الشركة" inputId="tenant-search" />
        {tenants.length === 0 ? <p className="intro">{matchingCount ? 'لا توجد نتائج في هذه الصفحة.' : 'لا توجد شركات مطابقة.'}</p> : (
          <ul className="member-list">
            {tenants.map((tenant) => (
              <RecordCard className="member-card" key={tenant.tenant_id}>
                <div>
                  <h2>{tenant.display_name}</h2>
                  <Badge as="p" className={` ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</Badge>
                </div>
                <ButtonLink variant="ghost"  href={`/operator/tenants/${tenant.tenant_id}`}>عرض الحالة والإجراءات</ButtonLink>
              </RecordCard>
            ))}
          </ul>
        )}
      </Panel>

    </main>
  );
}

function stateLabel(state: string) {
  if (state === 'active') return 'نشطة';
  if (state === 'suspended') return 'معلّقة';
  if (state === 'archived') return 'مؤرشفة';
  return 'غير متاحة';
}

function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header>
    <Panel className="auth-card" aria-labelledby="status-title"><p className="eyebrow">إدارة حالة الشركات</p>
      <PageHeader id="status-title" title={<>{title}</>} /><p className="intro">{detail}</p></Panel></main>;
}
