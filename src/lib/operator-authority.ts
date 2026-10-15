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

type OperatorPermissionRpc = typeof permissionReads[number][1] | 'current_platform_operator_status';
type OperatorClient = NonNullable<Awaited<ReturnType<typeof getWorkspaceClient>>>;
type PermissionRead = { data: unknown; error: unknown };

// Share these six reads with existing pages while retaining their error/denial handling.
export const readOperatorRpc = cache(async (client: OperatorClient, name: OperatorPermissionRpc): Promise<PermissionRead> => {
  if (name !== 'current_platform_operator_status') {
    const status = await readOperatorRpc(client, 'current_platform_operator_status');
    if (status.error || status.data !== 'active') return { data: false, error: status.error };
  }
  const { data, error } = await client.rpc(name);
  return { data, error };
});

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

  const status = await readOperatorRpc(client, 'current_platform_operator_status').then(
    result => result, () => ({ data: null, error: true }),
  );
  if (status.error || status.data !== 'active') return { ...authority, partial: Boolean(status.error) };
  authority.active = true;
  const results = await Promise.all(permissionReads.map(([, rpc]) => readOperatorRpc(client, rpc).then(
    result => result, () => ({ data: null, error: true }),
  )));
  results.forEach((result, index) => {
    authority[permissionReads[index][0]] = operatorPermission(result);
    if (result.error) authority.partial = true;
  });
  return authority;
});
