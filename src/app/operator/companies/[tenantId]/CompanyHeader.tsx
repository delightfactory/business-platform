import Link from 'next/link';
import { Badge, Banner, ButtonLink, PageHeader } from '@/components/ui';
import { operatorLifecycleLabel } from '@/lib/operator-labels';
import { companyContextSuffix, type CompanyQuery } from '../company-context';

export function CompanyHeader({ tenant, current, commercial, lifecycle, query }: {
  tenant: { tenant_id: string; display_name: string; lifecycle_state: string };
  current: 'services' | 'limits' | 'status'; commercial: boolean; lifecycle: boolean; query: CompanyQuery;
}) {
  const suffix = companyContextSuffix(query);
  const base = `/operator/companies/${tenant.tenant_id}`;
  return <>
    <nav className="operator-company-breadcrumb" aria-label="مسار الشركة"><Link href={`/operator/companies${suffix}`}>الشركات</Link><span aria-hidden="true">/</span><bdi>{tenant.display_name}</bdi></nav>
    <PageHeader title={<bdi>{tenant.display_name}</bdi>} action={<Badge tone={tenant.lifecycle_state === 'active' ? 'ok' : 'warn'}>{operatorLifecycleLabel(tenant.lifecycle_state)}</Badge>} />
    <nav className="operator-company-tabs" aria-label="مهام الشركة">
      {commercial && <><Link href={`${base}/services${suffix}`} aria-current={current === 'services' ? 'page' : undefined}>الخدمات</Link><Link href={`${base}/limits${suffix}`} aria-current={current === 'limits' ? 'page' : undefined}>حدود الاستخدام</Link></>}
      {lifecycle && <Link href={`${base}/status${suffix}`} aria-current={current === 'status' ? 'page' : undefined}>حالة الشركة</Link>}
    </nav>
    {tenant.lifecycle_state !== 'active' && <Banner tone="warn" action={lifecycle && current !== 'status' ? <ButtonLink variant="ghost" href={`${base}/status${suffix}`}>إدارة الحالة</ButtonLink> : undefined}>
      الشركة {operatorLifecycleLabel(tenant.lifecycle_state)}: لا يصل مستخدموها لأي خدمة حتى استعادة التشغيل. الخدمات الممنوحة تبقى محفوظة.
    </Banner>}
  </>;
}
