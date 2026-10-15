import { cache } from 'react';
import { operatorPermission } from './operator-access';
import { getWorkspaceClient, getWorkspaceUser } from './workspace-access';

const permissionReads = [
  ['manage', 'current_operator_can_manage_operators'],
  ['onboard', 'current_operator_can_onboard_tenants'],
  ['lifecycle', 'current_operator_can_manage_tenant_lifecycle'],
  ['commercial', 'current_operator_can_manage_commercial_access'],
  ['statutory', 'current_operator_can_manage_statutory_rules'],
] as const;

export type OperatorAuthority = Record<typeof permissionReads[number][0], boolean> & {
  active: boolean;
  partial: boolean;
  session: 'verified' | 'signed-out' | 'unavailable' | 'unconfigured';
  userId: string | null;
};

// Request-local only. Mutations still authenticate and authorize inside their RPC.
export const readOperatorAuthority = cache(async (): Promise<OperatorAuthority> => {
  const authority: OperatorAuthority = {
    active: false, partial: false, session: 'unconfigured', userId: null,
    manage: false, onboard: false, lifecycle: false, commercial: false, statutory: false,
  };
  const client = await getWorkspaceClient();
  if (!client) return authority;
  const identity = await getWorkspaceUser(client).catch(() => null);
  if (identity?.error?.name === 'AuthSessionMissingError') return { ...authority, session: 'signed-out' };
  if (!identity || identity.error) return { ...authority, session: 'unavailable', partial: true };
  if (!identity.data.user) return { ...authority, session: 'signed-out' };
  authority.session = 'verified';
  authority.userId = identity.data.user.id;

  const status = await client.rpc('current_platform_operator_status').then(
    result => result, () => ({ data: null, error: true }),
  );
  if (status.error || status.data !== 'active') return { ...authority, partial: Boolean(status.error) };
  authority.active = true;
  const results = await Promise.all(permissionReads.map(([, rpc]) => client.rpc(rpc).then(
    result => result, () => ({ data: null, error: true }),
  )));
  results.forEach((result, index) => {
    authority[permissionReads[index][0]] = operatorPermission(result);
    if (result.error) authority.partial = true;
  });
  return authority;
});
