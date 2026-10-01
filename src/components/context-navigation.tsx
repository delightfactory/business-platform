import type { ReactNode } from 'react';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { ContextNavigationClient, type ContextLink } from './context-navigation-client';

export function ContextNavigation({
  homeHref,
  homeLabel,
  contextLabel,
  links,
  mode,
  logoUrl,
  businessLinks = [],
  switchHref,
  switchLabel,
}: {
  homeHref: string;
  homeLabel: string;
  contextLabel: string;
  links: ContextLink[];
  mode: 'operator' | 'tenant';
  logoUrl?: string | null;
  businessLinks?: ContextLink[];
  switchHref?: string;
  switchLabel?: string;
}) {
  return <ContextNavigationClient homeHref={homeHref} homeLabel={homeLabel} contextLabel={contextLabel}
    links={links} businessLinks={businessLinks} mode={mode} logoUrl={logoUrl}
    switchHref={switchHref} switchLabel={switchLabel} />;
}

export async function OperatorNavigation() {
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
      if (lifecycle.data) links.push({ href: '/operator/tenants', label: 'الشركات' });
      if (onboarding.data) {
        links.push({ href: '/operator/invitations', label: 'دعوات الشركات' });
        links.push({ href: '/operator/onboarding', label: 'إعداد شركة' });
      }
      if (commercial.data) {
        links.push({ href: '/operator/commercial', label: 'حدود الاشتراك' });
        links.push({ href: '/operator/entitlements', label: 'الوحدات المتاحة' });
      }
      if (operator.data) links.push({ href: '/operator/operators', label: 'المشغّلون' });
    }
  }
  return <ContextNavigation homeHref="/operator" homeLabel="تشغيل المنصة" contextLabel="تشغيل المنصة" links={links} mode="operator" />;
}

export async function TenantNavigation({
  tenantId,
  tenantName,
  logoUrl,
}: {
  tenantId: string;
  tenantName: string;
  logoUrl?: string | null;
}) {
  const supabase = await createSupabaseServerClient();
  const links: ContextLink[] = [];
  const businessLinks: ContextLink[] = [];
  let canSwitchTenant = false;
  if (supabase) {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      const [members, entitiesSites, branding, spaces, peopleAccess, attendanceAccess, ownEmployee, leaveAccess] = await Promise.all([
        supabase.rpc('tenant_member_access_page', { p_tenant_id: tenantId, p_view: 'summary' }),
        supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId }),
        supabase.rpc('tenant_branding_snapshot', { p_tenant_id: tenantId }),
        supabase.rpc('current_tenant_spaces'),
        supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId }),
        supabase.rpc('time_attendance_access_snapshot', { p_tenant_id: tenantId }),
        supabase.rpc('tenant_my_employee_snapshot', { p_tenant_id: tenantId }),
        supabase.rpc('leave_access_snapshot', { p_tenant: tenantId }),
      ]);
      canSwitchTenant = Array.isArray(spaces.data) && spaces.data.length > 1;
      if (members.data && typeof members.data === 'object') links.push({ href: `/tenant/${tenantId}/users`, label: 'المستخدمون' });
      const identity = entitiesSites.data && typeof entitiesSites.data === 'object' && !Array.isArray(entitiesSites.data)
        ? entitiesSites.data as Record<string, unknown> : null;
      if (identity?.can_manage_legal_entities === true || identity?.can_manage_sites === true) {
        links.push({ href: `/tenant/${tenantId}/entities-sites`, label: 'الجهات والفروع' });
      }
      const brand = branding.data && typeof branding.data === 'object' && !Array.isArray(branding.data)
        ? branding.data as Record<string, unknown> : null;
      if (brand?.can_manage_branding === true) links.push({ href: `/tenant/${tenantId}/branding`, label: 'هوية الشركة' });
      if (!peopleAccess.error && peopleAccess.data && typeof peopleAccess.data === 'object') {
        businessLinks.push({ href: `/tenant/${tenantId}/people`, label: 'الموظفون' });
      }
      if (!attendanceAccess.error && attendanceAccess.data && typeof attendanceAccess.data === 'object') {
        businessLinks.push({ href: `/tenant/${tenantId}/attendance`, label: 'الحضور' });
      }
      if (!ownEmployee.error && ownEmployee.data && typeof ownEmployee.data === 'object') {
        businessLinks.push({ href: `/tenant/${tenantId}/me`, label: 'ملفي' });
      }
      const leave = !leaveAccess.error && leaveAccess.data && typeof leaveAccess.data === 'object' && !Array.isArray(leaveAccess.data)
        ? leaveAccess.data as Record<string, unknown> : null;
      if (leave?.self_access === true) {
        businessLinks.push({ href: `/tenant/${tenantId}/me/leave`, label: 'إجازاتي' });
      }
      if (leave?.can_view === true) {
        businessLinks.push({ href: `/tenant/${tenantId}/leave/settings`, label: 'إعدادات الإجازات' });
      }
    }
  }
  return <ContextNavigation homeHref={`/tenant/${tenantId}`} homeLabel="مساحة الشركة" contextLabel={tenantName}
    links={links} businessLinks={businessLinks} mode="tenant" logoUrl={logoUrl}
    switchHref={canSwitchTenant ? '/tenant/select' : undefined} switchLabel={canSwitchTenant ? 'تبديل الشركة' : undefined} />;
}

export function PageFrame({ children, footer = 'منصة الأعمال' }: { children: ReactNode; footer?: string }) {
  return <main className="app-shell">{children}<footer className="footer">{footer}</footer></main>;
}
