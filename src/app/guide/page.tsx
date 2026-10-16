import { notFound, redirect } from 'next/navigation';
import { getWorkspaceClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { operatorGuideTopics, tenantGuideTopics, type GuideSnapshots } from '@/lib/guide-topics';

export const dynamic = 'force-dynamic';

// Existing access snapshots only; no financial/history operation is opened.
const reads = [
  ['members', 'tenant_member_access_page', 'p_tenant_id', 'summary'],
  ['structure', 'tenant_entities_sites_snapshot', 'p_tenant_id'],
  ['branding', 'tenant_branding_snapshot', 'p_tenant_id'],
  ['people', 'people_access_snapshot', 'p_tenant_id'],
  ['attendance', 'time_attendance_access_snapshot', 'p_tenant_id'],
  ['channels', 'attendance_channel_access', 'p_tenant'],
  ['workPolicies', 'time_work_policy_catalog', 'p_tenant_id'],
  ['leave', 'leave_access_snapshot', 'p_tenant'],
  ['calendar', 'payroll_access_snapshot', 'p_tenant'],
  ['inputs', 'payroll_input_access', 'p_tenant'],
  ['runs', 'payroll_run_access', 'p_tenant'],
  ['navigation', 'payroll_navigation_access', 'p_tenant'],
  ['payments', 'payroll_payment_access', 'p_tenant'],
  ['corrections', 'payroll_correction_access', 'p_tenant'],
  ['employee', 'tenant_my_employee_snapshot', 'p_tenant_id'],
  ['mobile', 'attendance_mobile_snapshot', 'p_tenant'],
] as const;

export default async function GuidePage({ searchParams }: { searchParams: Promise<{ tenant?: string; workspace?: string }> }) {
  const query = await searchParams;
  const operator = query.workspace === 'operator';
  if (!operator && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(query.tenant ?? '')) notFound();
  const client = await getWorkspaceClient();
  const next = operator ? '/guide?workspace=operator' : `/guide?tenant=${query.tenant}`;
  if (!client) redirect('/user-guide.html?personal=1&partial=1');
  const identity = await getWorkspaceUser(client);
  if (!identity.data.user) redirect(`/auth/login?next=${encodeURIComponent(next)}`);
  let topics: string[];
  let partial = false;
  if (operator) {
    const authority = await readOperatorAuthority();
    topics = operatorGuideTopics(authority);
    partial = authority.partial;
  } else {
    const snapshots: GuideSnapshots = {};
    const results = await Promise.allSettled(reads.map(([, name, argument, view]) => readWorkspaceRpc(client, name, query.tenant!, argument, view)));
    results.forEach((result, index) => {
      if (result.status === 'rejected') { partial = true; return; }
      const { data, error } = result.value;
      if (error && error.code !== '42501') partial = true;
      snapshots[reads[index][0]] = { data: data && typeof data === 'object' && !Array.isArray(data) ? data : null, error };
    });
    topics = tenantGuideTopics(snapshots);
  }
  const params = new URLSearchParams({ personal: '1', topics: topics.join(',') });
  if (partial) params.set('partial', '1');
  redirect(`/user-guide.html?${params}`);
}
