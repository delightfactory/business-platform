import Link from 'next/link';
import { Badge, Banner, ButtonLink, PageHeader, WorkspaceTabs } from '@/components/ui';
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
    <WorkspaceTabs label="مهام الشركة" items={[
      ...(commercial?[{href:`${base}/services${suffix}`,label:'الخدمات',current:current==='services'},{href:`${base}/limits${suffix}`,label:'حدود الاستخدام',current:current==='limits'}]:[]),
      ...(lifecycle?[{href:`${base}/status${suffix}`,label:'حالة الشركة',current:current==='status'}]:[]),
    ]}/>
    {tenant.lifecycle_state !== 'active' && <Banner tone="warn" action={lifecycle && current !== 'status' ? <ButtonLink variant="ghost" href={`${base}/status${suffix}`}>إدارة الحالة</ButtonLink> : undefined}>
      الشركة {operatorLifecycleLabel(tenant.lifecycle_state)}: لا يصل مستخدموها لأي خدمة حتى استعادة التشغيل. الخدمات الممنوحة تبقى محفوظة.
    </Banner>}
  </>;
}
