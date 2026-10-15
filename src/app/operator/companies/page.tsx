import Link from 'next/link';
import { redirect } from 'next/navigation';
import { Banner, Badge, ButtonLink, EmptyState, PageHeader, Panel, RecordCard } from '@/components/ui';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { operatorLifecycleLabel } from '@/lib/operator-labels';
import { operatorPage, operatorTenant } from '@/lib/operator-read';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { OperatorListControls, operatorListQuery } from '../operator-list-controls';

export const dynamic = 'force-dynamic';

export default async function CompanyDirectory({ searchParams }: {
  searchParams: Promise<{ page?: string; q?: string }>;
}) {
  const authority = await readOperatorAuthority();
  if (authority.session === 'signed-out') redirect('/auth/login?state=no-session');
  if (authority.session === 'unconfigured') return <Status title="إعداد الاتصال غير مكتمل" detail="اطلب من مسؤول التشغيل مراجعة إعدادات الاتصال." />;
  if (authority.session === 'unavailable' || (!authority.active && authority.partial)) {
    return <Status title="تعذر التحقق من الصلاحية" detail="أعد المحاولة؛ لم تتأكد صلاحيات الحساب الآن." />;
  }
  if (!authority.active || (!authority.lifecycle && !authority.commercial)) {
    return <Status title="عرض الشركات غير متاح" detail="تحتاج صلاحية حالة الشركات أو خدماتها وحدودها." />;
  }
  const { page, search } = operatorListQuery(await searchParams);
  const client = await getWorkspaceClient();
  if (!client) return <Status title="تعذر الاتصال" detail="أعد المحاولة لاحقًا." />;
  const response = await client.rpc('platform_tenant_list_page', {
    p_scope: authority.lifecycle ? 'lifecycle' : 'commercial', p_page: page, p_query: search,
  }).then(result => result, () => ({ data: null, error: true }));
  const result = !response.error ? operatorPage(response.data, operatorTenant, row => row.tenant_id) : null;
  if (!result) return <Status title="تعذر تحميل الشركات" detail="لم تتأكد قائمة الشركات. أعد المحاولة؛ لا يعني هذا عدم وجود شركات." />;
  const context = new URLSearchParams();
  if (search) context.set('q', search);
  if (page > 1) context.set('page', String(page));
  const suffix = context.size ? `?${context}` : '';

  return <main className="app-shell">
    <PageHeader title="الشركات" description="اختر شركة لمتابعة المهام المسموحة لحسابك."
      action={authority.onboard ? <ButtonLink href="/operator/invitations/new" icon="plus">شركة جديدة</ButtonLink> : undefined} />
    {authority.partial && <Banner>تعذر التحقق من بعض المهام. تظهر الصلاحيات المؤكدة فقط.</Banner>}
    <Panel className="operator-collection">
      <OperatorListControls basePath="/operator/companies" search={search} page={page} matchingCount={result.matching_count}
        searchLabel="البحث باسم الشركة" inputId="company-directory-search" />
      {result.rows.length ? <ul className="member-list">{result.rows.map(company => <RecordCard key={company.tenant_id}>
        <Link className="operator-work-link" href={`/operator/companies/${company.tenant_id}${suffix}`}>
          <span><strong><bdi>{company.display_name}</bdi></strong><Badge>{operatorLifecycleLabel(company.lifecycle_state)}</Badge></span>
          <span aria-hidden="true">←</span>
        </Link>
      </RecordCard>)}</ul> : page > Math.max(1, Math.ceil(result.matching_count / 25)) ? null :
        <EmptyState title={search ? `لا توجد نتائج لـ «${search}»` : 'لا توجد شركات بعد'}
          action={search ? <ButtonLink href="/operator/companies" variant="ghost">مسح البحث</ButtonLink> :
            authority.onboard ? <ButtonLink href="/operator/invitations/new">شركة جديدة</ButtonLink> : undefined} />}
    </Panel>
  </main>;
}

function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><PageHeader title={title} description={detail} />
    <ButtonLink href="/operator/companies" variant="ghost">إعادة المحاولة</ButtonLink>
    <ButtonLink href="/operator" variant="ghost">مهام التشغيل</ButtonLink></main>;
}
