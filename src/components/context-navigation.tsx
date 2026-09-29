import type { ReactNode } from 'react';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { ContextNavigationClient, type ContextLink } from './context-navigation-client';

export function ContextNavigation({
  homeHref,
  homeLabel,
  contextLabel,
  links,
  switchHref,
  switchLabel,
  showContextTitle = true,
}: {
  homeHref: string;
  homeLabel: string;
  contextLabel: string;
  links: ContextLink[];
  switchHref?: string;
  switchLabel?: string;
  showContextTitle?: boolean;
}) {
  return <ContextNavigationClient homeHref={homeHref} homeLabel={homeLabel} contextLabel={contextLabel} links={links} switchHref={switchHref} switchLabel={switchLabel} showContextTitle={showContextTitle} />;
}

export async function OperatorNavigation({ current }: { current: string }) {
  const supabase = await createSupabaseServerClient();
  const links: ContextLink[] = [];
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const [operator, onboarding, lifecycle, commercial] = await Promise.all([
        supabase.rpc('current_operator_can_manage_operators'),
        supabase.rpc('current_operator_can_onboard_tenants'),
        supabase.rpc('current_operator_can_manage_tenant_lifecycle'),
        supabase.rpc('current_operator_can_manage_commercial_access'),
      ]);
      if (operator.data) links.push({ href: '/operator/operators', label: 'المشغّلون', current: current === 'operators' });
      if (onboarding.data) {
        links.push({ href: '/operator/onboarding', label: 'إعداد شركة', current: current === 'onboarding' });
        links.push({ href: '/operator/invitations', label: 'دعوات الشركة', current: current === 'invitations' });
      }
      if (lifecycle.data) links.push({ href: '/operator/tenants', label: 'حالة الشركات', current: current === 'tenants' });
      if (commercial.data) {
        links.push({ href: '/operator/commercial', label: 'الحدود', current: current === 'commercial' });
        links.push({ href: '/operator/entitlements', label: 'إتاحة الوحدات', current: current === 'entitlements' });
      }
    }
  }
  return <ContextNavigationClient homeHref="/operator" homeLabel="تشغيل المنصة" contextLabel={currentLabel(current)} links={links} deriveContext />;
}

function currentLabel(current: string) {
  const labels: Record<string, string> = {
    home: 'المهام', operators: 'المشغّلون', onboarding: 'إعداد شركة', invitations: 'دعوات الشركة',
    tenants: 'حالة الشركات', commercial: 'الحدود', entitlements: 'إتاحة الوحدات',
  };
  return labels[current] ?? 'تشغيل المنصة';
}

export async function TenantNavigation({
  tenantId,
  tenantName,
  current,
}: {
  tenantId: string;
  tenantName: string;
  current: 'home' | 'users' | 'entities-sites' | 'branding';
}) {
  const supabase = await createSupabaseServerClient();
  const links: ContextLink[] = [];
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const [members, entitiesSites, branding] = await Promise.all([
        supabase.rpc('tenant_member_access_list', { p_tenant_id: tenantId }),
        supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId }),
        supabase.rpc('tenant_branding_snapshot', { p_tenant_id: tenantId }),
      ]);
      if (members.data && typeof members.data === 'object') links.push({ href: `/tenant/${tenantId}/users`, label: 'المستخدمون', current: current === 'users' });
      const identity = entitiesSites.data && typeof entitiesSites.data === 'object' && !Array.isArray(entitiesSites.data)
        ? entitiesSites.data as Record<string, unknown> : null;
      if (identity?.can_manage_legal_entities === true || identity?.can_manage_sites === true) {
        links.push({ href: `/tenant/${tenantId}/entities-sites`, label: 'الجهات والفروع', current: current === 'entities-sites' });
      }
      const brand = branding.data && typeof branding.data === 'object' && !Array.isArray(branding.data)
        ? branding.data as Record<string, unknown> : null;
      if (brand?.can_manage_branding === true) links.push({ href: `/tenant/${tenantId}/branding`, label: 'هوية الشركة', current: current === 'branding' });
    }
  }
  return <ContextNavigation homeHref={`/tenant/${tenantId}`} homeLabel="مساحة الشركة" contextLabel={tenantName}
    links={links.map((item) => ({ ...item, current: current === 'home' ? false : item.current }))}
    switchHref="/tenant/select" switchLabel="تبديل الشركة" showContextTitle={false} />;
}

export function PageFrame({ children, footer = 'منصة الأعمال' }: { children: ReactNode; footer?: string }) {
  return <main className="app-shell">{children}<footer className="footer">{footer}</footer></main>;
}
