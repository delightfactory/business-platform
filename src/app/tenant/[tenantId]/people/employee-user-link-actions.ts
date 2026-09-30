'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function linkEmployeeUserAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employeeId');
  const userId = field(formData, 'userId');
  const path = `/tenant/${tenantId}/people/${employeeId}`;
  if (![tenantId, employeeId, userId].every(isUuid)) redirect(`${path}?userLink=error`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${path}?userLink=error`);
  const { error } = await supabase.rpc('link_people_employee_user', {
    p_tenant_id: tenantId, p_employee_id: employeeId, p_user_id: userId,
  });
  redirect(`${path}?userLink=${error ? mapLinkError(error.message) : 'linked'}`);
}

export async function unlinkEmployeeUserAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employeeId');
  const path = `/tenant/${tenantId}/people/${employeeId}`;
  if (![tenantId, employeeId].every(isUuid)) redirect(`${path}?userLink=error`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${path}?userLink=error`);
  const { error } = await supabase.rpc('unlink_people_employee_user', {
    p_tenant_id: tenantId, p_employee_id: employeeId,
  });
  redirect(`${path}?userLink=${error ? mapLinkError(error.message) : 'unlinked'}`);
}

function field(data: FormData, name: string) { return String(data.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function mapLinkError(message: string) {
  if (message.includes('people_employee_already_linked')) return 'employee-linked';
  if (message.includes('people_user_already_linked')) return 'user-linked';
  if (message.includes('employee_user_links_one_employee_idx')) return 'employee-linked';
  if (message.includes('employee_user_links_one_user_idx')) return 'user-linked';
  if (message.includes('people_link_member_unavailable')) return 'member-unavailable';
  if (message.includes('people_manage_forbidden')) return 'forbidden';
  return 'error';
}
