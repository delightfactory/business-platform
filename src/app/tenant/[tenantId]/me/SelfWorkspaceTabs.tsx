import { WorkspaceTabs } from '@/components/ui';
import { getWorkspaceClient, readWorkspaceRpc } from '@/lib/workspace-access';

export async function SelfWorkspaceTabs({ tenantId, current, hasAttendance, hasLeave }: {
  tenantId: string; current: 'today' | 'attendance' | 'leave'; hasAttendance?: boolean; hasLeave?: boolean;
}) {
  let attendance = hasAttendance === true, leave = hasLeave === true;
  if (hasAttendance === undefined || hasLeave === undefined) {
    const client = await getWorkspaceClient();
    if (client) {
      const results = await Promise.allSettled([
        hasAttendance === undefined ? readWorkspaceRpc(client, 'attendance_mobile_snapshot', tenantId, 'p_tenant') : null,
        hasLeave === undefined ? readWorkspaceRpc(client, 'leave_access_snapshot', tenantId, 'p_tenant') : null,
      ]);
      const attendanceResult = results[0].status === 'fulfilled' ? results[0].value : null;
      const leaveResult = results[1].status === 'fulfilled' ? results[1].value : null;
      attendance = attendance || Boolean(attendanceResult && !attendanceResult.error && attendanceResult.data);
      leave = leave || Boolean(leaveResult && !leaveResult.error && leaveResult.data?.self_access === true);
    }
  }
  const base = `/tenant/${tenantId}/me`;
  return <WorkspaceTabs label="مساحتي" items={[
    { href: base, label: 'يومي وملفي', current: current === 'today' },
    ...(attendance || current === 'attendance' ? [{ href: `${base}/attendance`, label: 'حضوري', current: current === 'attendance' }] : []),
    ...(leave || current === 'leave' ? [{ href: `${base}/leave`, label: 'إجازاتي', current: current === 'leave' }] : []),
  ]}/>;
}
