import { redirect } from 'next/navigation';
import { Banner, ButtonLink } from '@/components/ui';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { operatorCommercialSnapshot, operatorUuid } from '@/lib/operator-read';
import { companyContextSuffix, type CompanyQuery } from '../../company-context';
import { CompanyHeader } from '../CompanyHeader';
import { LimitManager } from './LimitManager';
import '../company-workspace.css';
export const dynamic = 'force-dynamic';
export default async function LimitsPage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Promise<CompanyQuery> }) {
  const { tenantId: rawTenantId } = await params; const tenantId = rawTenantId.toLowerCase(); const query = await searchParams;
  const authority = await readOperatorAuthority();
  if (authority.session === 'signed-out') redirect('/auth/login?state=no-session');
  if (!operatorUuid(tenantId) || !authority.active || !authority.commercial) return <main className="app-shell"><Banner>{authority.partial ? 'تعذر التحقق من صلاحية حدود الاستخدام. أعد المحاولة.' : 'إدارة حدود الشركة غير متاحة لهذا الحساب.'}</Banner><ButtonLink href="/operator/companies" variant="ghost">الشركات</ButtonLink></main>;
  const client = await getWorkspaceClient();
  const result = client ? await client.rpc('platform_tenant_commercial_snapshot', { p_tenant_id: tenantId }).then(value => value, () => ({ data: null, error: true })) : null;
  if (!result || result.error || !operatorCommercialSnapshot(result.data) || result.data.tenant_id !== tenantId) return <main className="app-shell"><Banner tone="warn">تعذر قراءة حدود الشركة. لم تتأكد الحالة الحالية.</Banner><ButtonLink variant="ghost" href={`/operator/companies/${tenantId}/limits${companyContextSuffix(query)}`}>إعادة المحاولة</ButtonLink></main>;
  return <main className="app-shell operator-company-workspace"><CompanyHeader tenant={result.data} current="limits" commercial={true} lifecycle={authority.lifecycle} query={query} />
    <LimitManager key={`${tenantId}:${result.data.lifecycle_state}`} initial={result.data} /></main>;
}
