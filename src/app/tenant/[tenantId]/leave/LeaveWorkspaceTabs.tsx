import { WorkspaceTabs } from '@/components/ui';

export function LeaveWorkspaceTabs({ tenantId, current }: {
  tenantId: string; current: 'requests' | 'balances' | 'settings';
}) {
  const base = `/tenant/${tenantId}/leave`;
  return <WorkspaceTabs label="الإجازات" items={[
    { href: base, label: 'الطلبات', current: current === 'requests' },
    { href: `${base}/balances`, label: 'الأرصدة', current: current === 'balances' },
    { href: `${base}/settings`, label: 'الإعدادات', current: current === 'settings' },
  ]} />;
}
