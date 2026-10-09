import type { ReactNode } from 'react';
import { TenantNavigation } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Branding = { tenant_name: string; primary_color_key: string; logo_object_path: string | null };
const colors: Record<string, string> = {
  teal: '#126b68', blue: '#2563eb', violet: '#7c3aed', emerald: '#047857',
};

export default async function TenantBrandingLayout({ children, params }: { children: ReactNode; params: Params }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return children;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return children;
  const { data, error } = await supabase.rpc('tenant_branding_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return children;
  const branding = data as Branding;
  const brandKey = Object.hasOwn(colors, branding.primary_color_key) ? branding.primary_color_key : 'teal';
  let logoUrl: string | null = null;
  if (branding.logo_object_path) {
    const { data: signed } = await supabase.storage.from('tenant-branding').createSignedUrl(branding.logo_object_path, 60);
    logoUrl = signed?.signedUrl ?? null;
  }

  return <div className="tenant-area workspace-frame" data-workspace="tenant" data-brand={brandKey}>
    <TenantNavigation tenantId={tenantId} tenantName={branding.tenant_name} logoUrl={logoUrl} />
    <div className="workspace-content">{children}</div>
  </div>;
}
