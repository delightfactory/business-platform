'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { safeReturn } from '@/lib/return-to';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { inputAction } from '../../payroll/inputs/actions';
import { inputError, type InputState } from '../../payroll/inputs/rules';
import { uuid } from '../../payroll/rules';

export async function employeeAdjustmentAction(tenant: string, employee: string, previous: InputState, form: FormData): Promise<InputState> {
  const fail = (code?: string) => ({ ...previous, saved: false, error: inputError(code) });
  if (!uuid(tenant) || !uuid(employee) || form.get('tenant') !== tenant
    || !['adjustment', 'component'].includes(String(form.get('kind')))) return fail('22023');
  const client = await createSupabaseServerClient();
  if (!client) return fail();
  const { data: { user } } = await client.auth.getUser();
  if (!user) return fail('42501');
  const snapshot = await client.rpc('people_employee_snapshot', { p_tenant_id: tenant, p_employee_id: employee });
  if (snapshot.error || !snapshot.data?.employment
    || snapshot.data.employment.employer_id !== form.get('employer')
    || form.get('kind') === 'adjustment' && snapshot.data.employment.id !== form.get('employment')) return fail('42501');
  if(form.get('kind')==='adjustment'&&!previous.head&&!String(form.get('reference')??'').trim())form.set('reference','تسجيل من ملف الموظف');
  const result = await inputAction(previous, form);
  if (result.saved) {
    revalidatePath(`/tenant/${tenant}/people/${employee}`);
    revalidatePath(`/tenant/${tenant}/payroll`);
    const period = String(form.get('viewPeriod') ?? form.get('period') ?? '');
    const returnTo = safeReturn(tenant, String(form.get('return') ?? ''));
    const query = new URLSearchParams({tab:'adjustments',adjustmentResult:form.get('kind')==='component'?'type':result.status,adjustmentFocus:result.head});
    if(uuid(period)) query.set('adjustmentPeriod',period);
    if(returnTo) query.set('return',returnTo);
    redirect(`/tenant/${tenant}/people/${employee}?${query}`);
  }
  return result;
}
