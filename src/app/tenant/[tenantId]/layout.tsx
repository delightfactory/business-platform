import type { CSSProperties, ReactNode } from 'react';
import { customBrandStyle, normalizeBrandColor } from '@/lib/brand-colors.mjs';
import { TenantNavigation } from '@/components/context-navigation';
import { AppShell } from '@/components/shell/app-shell';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Branding = { tenant_name: string; primary_color_key: string; logo_object_path: string | null };

export default async function TenantBrandingLayout({ children, params }: { children: ReactNode; params: Params }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return children;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) return children;
  const { data, error } = await readWorkspaceRpc(supabase, 'tenant_branding_snapshot', tenantId, 'p_tenant_id');
  const branding = !error && data && typeof data === 'object' && !Array.isArray(data) ? data as Branding : null;
  let tenantName = branding?.tenant_name;
  if (!tenantName) {
    const { data: membership, error: membershipError } = await readWorkspaceRpc(supabase, 'tenant_membership_snapshot', tenantId, 'p_tenant_id');
    if (!membershipError && membership && typeof membership === 'object' && !Array.isArray(membership) && typeof membership.tenant_name === 'string') tenantName = membership.tenant_name;
  }
  const brandKey = normalizeBrandColor(branding?.primary_color_key) || 'teal';
  const brandStyle = customBrandStyle(brandKey);
  let logoUrl: string | null = null;
  if (branding?.logo_object_path) {
    const { data: signed } = await supabase.storage.from('tenant-branding').createSignedUrl(branding.logo_object_path, 60);
    logoUrl = signed?.signedUrl ?? null;
  }

  return <AppShell mode="tenant" brand={brandStyle ? 'custom' : brandKey} style={brandStyle as CSSProperties}
    navigation={<TenantNavigation tenantId={tenantId} tenantName={tenantName || 'مساحة الشركة'} logoUrl={logoUrl} />}>
    {children}
  </AppShell>;
}
