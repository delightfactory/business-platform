import { cache } from 'react';
import { createSupabaseServerClient } from '@/lib/supabase/server';

// React cache is confined to the current server render: no access data survives
// between requests, accounts or companies.
export const getWorkspaceClient = cache(createSupabaseServerClient);
type Client = NonNullable<Awaited<ReturnType<typeof getWorkspaceClient>>>;

export const readWorkspaceRpc = cache(async (
  client: Client, name: string, tenantId: string, argument: 'p_tenant' | 'p_tenant_id', view?: string,
) => {
  const args: Record<string, string> = { [argument]: tenantId };
  if (view) args.p_view = view;
  return await client.rpc(name, args);
});

export const getWorkspaceUser = cache(async (client: Client) => client.auth.getUser());
