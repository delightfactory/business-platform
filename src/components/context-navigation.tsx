import type { ReactNode } from 'react';
import { operatorPermission } from '@/lib/operator-access';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
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
    const { data: { user } } = await getWorkspaceUser(supabase);
    if (user) {
      const [operator, onboarding, lifecycle, commercial, statutory] = await Promise.all([
        supabase.rpc('current_operator_can_manage_operators'),
        supabase.rpc('current_operator_can_onboard_tenants'),
        supabase.rpc('current_operator_can_manage_tenant_lifecycle'),
        supabase.rpc('current_operator_can_manage_commercial_access'),
        supabase.rpc('current_operator_can_manage_statutory_rules'),
      ]);
      if (operatorPermission(lifecycle)) links.push({ href: '/operator/tenants', label: 'الشركات' });
      if (operatorPermission(onboarding)) {
        links.push({ href: '/operator/invitations', label: 'دعوات الشركات' });
        links.push({ href: '/operator/onboarding', label: 'إعداد شركة' });
      }
      if (operatorPermission(commercial)) {
        links.push({ href: '/operator/commercial', label: 'حدود الاشتراك' });
        links.push({ href: '/operator/entitlements', label: 'خدمات الشركات' });
      }
      if (operatorPermission(operator)) links.push({ href: '/operator/operators', label: 'المشغّلون' });
      if (operatorPermission(statutory)) links.push({ href: '/operator/statutory', label: 'قواعد الرواتب' });
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
    const { data: { user } } = await getWorkspaceUser(supabase);
    if (user) {
      const [members, entitiesSites, branding, spaces, peopleAccess, attendanceAccess, ownEmployee, leaveAccess, payrollAccess, payrollInputs, payrollRuns, payrollNavigation, mobileAttendance, channelAccess] = await Promise.all([
        readWorkspaceRpc(supabase, 'tenant_member_access_page', tenantId, 'p_tenant_id', 'summary'),
        readWorkspaceRpc(supabase, 'tenant_entities_sites_snapshot', tenantId, 'p_tenant_id'),
        readWorkspaceRpc(supabase, 'tenant_branding_snapshot', tenantId, 'p_tenant_id'),
        supabase.rpc('current_tenant_spaces'),
        readWorkspaceRpc(supabase, 'people_access_snapshot', tenantId, 'p_tenant_id'),
        readWorkspaceRpc(supabase, 'time_attendance_access_snapshot', tenantId, 'p_tenant_id'),
        readWorkspaceRpc(supabase, 'tenant_my_employee_snapshot', tenantId, 'p_tenant_id'),
        readWorkspaceRpc(supabase, 'leave_access_snapshot', tenantId, 'p_tenant'),
        readWorkspaceRpc(supabase, 'payroll_access_snapshot', tenantId, 'p_tenant'),
        readWorkspaceRpc(supabase, 'payroll_input_access', tenantId, 'p_tenant'),
        readWorkspaceRpc(supabase, 'payroll_run_access', tenantId, 'p_tenant'),
        readWorkspaceRpc(supabase, 'payroll_navigation_access', tenantId, 'p_tenant'),
        readWorkspaceRpc(supabase, 'attendance_mobile_snapshot', tenantId, 'p_tenant'),
        readWorkspaceRpc(supabase, 'attendance_channel_access', tenantId, 'p_tenant'),
      ]);
      if (!mobileAttendance.error && mobileAttendance.data) businessLinks.push({ href: `/tenant/${tenantId}/me/attendance`, label: 'حضوري', mobilePriority: 10 });
      if (!channelAccess.error && channelAccess.data?.can_view === true) businessLinks.push({ href: `/tenant/${tenantId}/attendance/sources`, label: 'قنوات الحضور' });
      if (!payrollAccess.error && payrollAccess.data?.can_manage === true && (payrollRuns.error || payrollRuns.data?.can_view !== true)) businessLinks.push({ href: `/tenant/${tenantId}/payroll`, label: 'دورة الرواتب' });
      if (!payrollInputs.error && payrollInputs.data) businessLinks.push({ href: `/tenant/${tenantId}/payroll/inputs`, label: 'المدخلات والإعدادات' });
      if (!payrollAccess.error && payrollAccess.data?.can_manage === true) businessLinks.push({ href: `/tenant/${tenantId}/payroll/setup`, label: 'دورة الرواتب والفترات' });
      if (!payrollRuns.error && payrollRuns.data?.can_view === true) businessLinks.push({ href: !payrollAccess.error && payrollAccess.data ? `/tenant/${tenantId}/payroll` : `/tenant/${tenantId}/payroll/runs`, label: 'الرواتب', mobilePriority: 50 });
      if (!payrollRuns.error && payrollRuns.data?.can_view === true) businessLinks.push({ href: `/tenant/${tenantId}/payroll/runs`, label: 'المراجعة والاعتماد' });
      if (!payrollNavigation.error && payrollNavigation.data?.can_view_advances === true) businessLinks.push({ href: `/tenant/${tenantId}/payroll/advances`, label: 'سلف الموظفين' });
      if (!payrollNavigation.error && payrollNavigation.data?.can_view_reports === true) businessLinks.push({ href: `/tenant/${tenantId}/payroll/reports?report=${payrollNavigation.data.report_kind === 'advances' ? 'advances' : 'sheet'}`, label: payrollNavigation.data.report_kind === 'advances' ? 'أرصدة السلف' : 'تقارير الرواتب' });
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
        businessLinks.push({ href: `/tenant/${tenantId}/people`, label: 'الموظفون', mobilePriority: 60 });
      }
      if (!attendanceAccess.error && attendanceAccess.data && typeof attendanceAccess.data === 'object') {
        businessLinks.push({ href: `/tenant/${tenantId}/attendance`, label: 'الحضور', mobilePriority: 30 });
      }
      if (!ownEmployee.error && ownEmployee.data && typeof ownEmployee.data === 'object') {
        businessLinks.push({ href: `/tenant/${tenantId}/me`, label: 'ملفي' });
      }
      const leave = !leaveAccess.error && leaveAccess.data && typeof leaveAccess.data === 'object' && !Array.isArray(leaveAccess.data)
        ? leaveAccess.data as Record<string, unknown> : null;
      if (leave?.self_access === true) {
        businessLinks.push({ href: `/tenant/${tenantId}/me/leave`, label: 'إجازاتي', mobilePriority: 20 });
      }
      if (leave?.can_view === true) {
        businessLinks.push({ href: `/tenant/${tenantId}/leave`, label: 'مراجعة الإجازات', mobilePriority: 40 });
        businessLinks.push({ href: `/tenant/${tenantId}/leave/settings`, label: 'إعدادات الإجازات' });
      }
      if (leave?.can_view === true || leave?.can_adjust === true) {
        businessLinks.push({ href: `/tenant/${tenantId}/leave/balances`, label: 'أرصدة الإجازات' });
      }
    }
  }
  return <ContextNavigation homeHref={`/tenant/${tenantId}`} homeLabel="مساحة الشركة" contextLabel={tenantName}
    links={links} businessLinks={businessLinks} mode="tenant" logoUrl={logoUrl}
    switchHref={canSwitchTenant ? '/tenant/select' : undefined} switchLabel={canSwitchTenant ? 'تبديل الشركة' : undefined} />;
}

export function PageFrame({ children }: { children: ReactNode; footer?: string }) {
  return <main className="app-shell">{children}</main>;
}
