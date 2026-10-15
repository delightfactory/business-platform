'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { bundleKeySet, PEOPLE_ROLE_BUNDLES } from '../users/bundles';

export async function enableEmployeeSelfServiceAction(form: FormData) {
  const tenantId = String(form.get('tenantId') ?? '');
  const employeeId = String(form.get('employeeId') ?? '');
  const bundle = String(form.get('bundle') ?? '');
  const expectedUser = String(form.get('linkedUserId') ?? '');
  const expected = form.getAll('expectedBundleKey').map(String);
  const validId = (id: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id);
  if (!validId(tenantId) || !validId(employeeId)) redirect('/tenant/select');
  const finish = (state: string): never => redirect(`/tenant/${tenantId}/people/${employeeId}?tab=account&selfService=${state}`);
  if (!validId(expectedUser) || !['employee.attendance.self.v1', 'employee.leave.self.v1'].includes(bundle)
    || expected.length > PEOPLE_ROLE_BUNDLES.length || new Set(expected).size !== expected.length
    || expected.some(key => !bundleKeySet.has(key))) finish('invalid');
  const client = await createSupabaseServerClient();
  if (!client) return finish('unknown');
  let state = 'unknown';
  try {
    // Never trust a submitted user ID: resolve the employee's current linked account.
    const { data: link, error: linkError } = await client.rpc('people_employee_user_link_snapshot', { p_tenant_id: tenantId, p_employee_id: employeeId });
    if (linkError || link?.linked !== true || link.user_id !== expectedUser) state = 'link-changed';
    else {
      const result = await client.rpc('set_tenant_member_people_bundles', {
        p_tenant_id: tenantId, p_user_id: link.user_id,
        p_bundle_keys: [...new Set([...expected, bundle])], p_expected_bundle_keys: expected,
      });
      if (result.error?.message.includes('tenant_people_role_bundle_stale')) state = 'stale';
      else if (result.error?.code === '42501') state = 'forbidden';
      else if (!result.error && ['updated', 'unchanged'].includes(result.data?.state)) state = 'saved';
    }
  } catch { state = 'unknown'; }
  finish(state);
}
