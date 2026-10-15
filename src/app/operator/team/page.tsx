import { redirect } from 'next/navigation';
import { readOperatorAuthority } from '@/lib/operator-authority';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { operatorGrantList } from '@/lib/operator-read';
import { Banner, ButtonLink, PageHeader } from '@/components/ui';
import { OperatorTeam } from './OperatorTeam';
import './team.css';
export const dynamic = 'force-dynamic';
export default async function TeamPage({ searchParams }: { searchParams: Promise<{ state?: string }> }) {
  const authority = await readOperatorAuthority();
  if (authority.session === 'signed-out') redirect('/auth/login?state=no-session');
  if (!authority.active || !authority.manage || !authority.userId) return <main className="app-shell"><PageHeader title="فريق التشغيل غير متاح" /><Banner tone="warn">لم تتأكد صلاحية إدارة الفريق. أعد القراءة للتحقق من حسابك وصلاحيتك الحالية.</Banner><ButtonLink href="/operator/team">إعادة قراءة الصفحة</ButtonLink></main>;
  const client = await getWorkspaceClient();
  const result = await client?.rpc('platform_operator_grant_list');
  const grants = result && !result.error ? operatorGrantList(result.data) : null;
  if (!grants) return <main className="app-shell"><PageHeader title="تعذر تحميل فريق التشغيل" /><Banner tone="warn">لم تصل قائمة صلاحيات مؤكدة. أعد القراءة قبل أي تغيير.</Banner><ButtonLink href="/operator/team">إعادة القراءة</ButtonLink></main>;
  const query = await searchParams;
  return <main className="app-shell operator-team"><OperatorTeam key={JSON.stringify(grants)} grants={grants} currentUserId={authority.userId} changed={['granted', 'updated', 'revoked'].includes(query.state ?? '')} /></main>;
}
