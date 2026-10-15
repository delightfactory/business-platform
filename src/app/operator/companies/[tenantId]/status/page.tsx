import { redirect } from 'next/navigation';
import { Banner, ButtonLink } from '@/components/ui';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { operatorLifecycleSnapshot, operatorUuid } from '@/lib/operator-read';
import { companyContextSuffix, type CompanyQuery } from '../../company-context';
import { CompanyHeader } from '../CompanyHeader';
import { LifecycleManager } from './LifecycleManager';
import '../company-workspace.css';
export const dynamic = 'force-dynamic';
export default async function StatusPage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Promise<CompanyQuery> }) {
  const { tenantId: rawTenantId } = await params; const tenantId = rawTenantId.toLowerCase(); const query = await searchParams;
  const authority = await readOperatorAuthority();
  if (authority.session === 'signed-out') redirect('/auth/login?state=no-session');
  if (!operatorUuid(tenantId) || !authority.active || !authority.lifecycle) return <main className="app-shell"><Banner>{authority.partial ? 'تعذر التحقق من صلاحية حالة الشركات. أعد المحاولة.' : 'إدارة حالة الشركة غير متاحة لهذا الحساب.'}</Banner><ButtonLink href="/operator/companies" variant="ghost">الشركات</ButtonLink></main>;
  const client = await getWorkspaceClient();
  const result = client ? await client.rpc('platform_tenant_lifecycle_get', { p_tenant_id: tenantId }).then(value => value, () => ({ data: null, error: true })) : null;
  if (!result || result.error || !operatorLifecycleSnapshot(result.data) || result.data.tenant_id !== tenantId) return <main className="app-shell"><Banner tone="warn">تعذر قراءة حالة الشركة.</Banner><ButtonLink variant="ghost" href={`/operator/companies/${tenantId}/status${companyContextSuffix(query)}`}>إعادة المحاولة</ButtonLink></main>;
  const tenant = { tenant_id: tenantId, display_name: result.data.tenant_name, lifecycle_state: result.data.lifecycle_state };
  return <main className="app-shell operator-company-workspace"><CompanyHeader tenant={tenant} current="status" commercial={authority.commercial} lifecycle={true} query={query} /><LifecycleManager key={tenantId} initial={result.data} /></main>;
}
