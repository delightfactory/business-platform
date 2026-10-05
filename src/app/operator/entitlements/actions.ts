'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function changeTenantEntitlementAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId');
  const capability = text(formData, 'capability');
  const decision = text(formData, 'decision');
  const expiresOn = text(formData, 'expiresOn');
  const reason = text(formData, 'reason');
  if (!isUuid(tenantId) || !['hr.people', 'hr.payroll', 'hr.attendance', 'hr.leave', 'hr.employee_finance'].includes(capability)
    || !['grant', 'deny'].includes(decision) || (expiresOn && !/^\d{4}-\d{2}-\d{2}$/.test(expiresOn))) return 'invalid';
  if (reason.length < 3 || reason.length > 500) return 'reason';
  const supabase = await createSupabaseServerClient();
  if (!supabase) return 'setup';
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { error } = await supabase.rpc('change_tenant_capability_entitlement', {
    p_tenant_id: tenantId,
    p_capability_key: capability,
    p_is_granted: decision === 'grant',
    p_valid_until: expiresOn || null,
    p_reason: reason,
  });
  if (error) {
    const state = mapError(error.message);
    if (capability === 'hr.employee_finance' && state === 'people-required') return 'finance-people-required';
    return capability === 'hr.leave' && state === 'people-required' ? 'leave-people-required' : state;
  }
  redirect(`/operator/entitlements/${tenantId}?state=updated`);
}

function text(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function mapError(message: string) {
  if (message.includes('commercial_access_forbidden')) return 'forbidden';
  if (message.includes('commercial_tenant_unavailable')) return 'not-found';
  if (message.includes('tenant_entitlement_people_required')) return 'people-required';
  if (message.includes('tenant_entitlement_payroll_must_end_first')) return 'payroll-first';
  if (message.includes('tenant_entitlement_finance_must_end_first')) return 'finance-first';
  if (message.includes('tenant_entitlement_leave_must_end_first')) return 'leave-first';
  if (message.includes('tenant_entitlement_people_children_must_end_first')) return 'people-children-first';
  if (message.includes('tenant_entitlement_future_conflict')) return 'future-conflict';
  if (message.includes('tenant_entitlement_conflict')) return 'conflict';
  if (message.includes('tenant_entitlement_expiry_invalid')) return 'expiry';
  if (message.includes('tenant_entitlement_reason_required')) return 'reason';
  if (message.includes('tenant_entitlement_input_invalid')) return 'invalid';
  return 'failed';
}

