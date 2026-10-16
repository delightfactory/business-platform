import { redirect } from 'next/navigation';
import { OperatorRecovery } from '../../../OperatorRecovery';
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
  const retryHref = `/operator/companies/${encodeURIComponent(tenantId)}/limits${companyContextSuffix(query)}`;
  const backHref = authority.active && (authority.commercial || authority.lifecycle) ? `/operator/companies${companyContextSuffix(query)}` : authority.active ? '/operator' : '/tenant/select';
  const uncertainAuthority = authority.partial || authority.session === 'unconfigured' || authority.session === 'unavailable';
  if (authority.session === 'signed-out') redirect(`/auth/login?next=${encodeURIComponent(retryHref)}`);
  if (!operatorUuid(tenantId) || !authority.active || !authority.commercial) return <OperatorRecovery title="حدود الشركة غير متاحة" detail={uncertainAuthority ? 'تعذر التحقق من صلاحية حدود الاستخدام. أعد قراءة الصلاحية قبل المتابعة.' : 'إدارة حدود الشركة غير متاحة لهذا الحساب.'} retryHref={uncertainAuthority && operatorUuid(tenantId) ? retryHref : undefined} backHref={backHref} />;
  const client = await getWorkspaceClient();
  const result = client ? await client.rpc('platform_tenant_commercial_snapshot', { p_tenant_id: tenantId }).then(value => value, () => ({ data: null, error: true })) : null;
  if (!result || result.error || !operatorCommercialSnapshot(result.data) || result.data.tenant_id !== tenantId) return <OperatorRecovery title="تعذر قراءة حدود الشركة" detail="لم تتأكد الحالة الحالية. أعد القراءة قبل أي تعديل." retryHref={retryHref} backHref={backHref} />;
  return <main className="app-shell operator-company-workspace"><CompanyHeader tenant={result.data} current="limits" commercial={true} lifecycle={authority.lifecycle} query={query} />
    <LimitManager key={`${tenantId}:${result.data.lifecycle_state}`} initial={result.data} /></main>;
}
