'use server';

import { revalidatePath } from 'next/cache';
import { getWorkspaceClient, getWorkspaceUser } from '@/lib/workspace-access';
import { uuid } from '@/app/tenant/[tenantId]/payroll/rules';
import { payrollInclusion, type InclusionState } from './payroll-inclusion-rules';

export async function changePayrollInclusion(previous: InclusionState, form: FormData): Promise<InclusionState> {
  const tenant = String(form.get('tenant') ?? ''), employment = String(form.get('employment') ?? ''), attempt = String(form.get('attempt') ?? '');
  const stamp = String(form.get('stamp') ?? ''), target = String(form.get('included') ?? '');
  const fail = (error: string, uncertain = false, stale = false): InclusionState => ({ ...previous, saved: false, error, uncertain, stale });
  if (!uuid(tenant) || !uuid(employment) || !uuid(attempt) || !/^[a-f0-9]{32}$/.test(stamp) || !['true', 'false'].includes(target)) return fail('تعذر التحقق من الموظف أو الحالة. أعد فتح الملف.');
  const client = await getWorkspaceClient();
  if (!client) return fail('تعذر الاتصال. أعد المحاولة بنفس الاختيار.', true);
  const { data: { user } } = await getWorkspaceUser(client);
  if (!user) return fail('سجّل الدخول بحساب مسؤول الموظفين، ثم أعد فتح الملف.');
  const result = await client.rpc('set_people_payroll_inclusion', { p_tenant_id: tenant, p_employment_id: employment, p_expected_stamp: stamp, p_included: target === 'true', p_attempt: attempt });
  if (result.error) {
    if (result.error.code === '42501') return fail('تحتاج صلاحيات عرض وإدارة الموظفين وإدارة علاقة العمل. راجع مدير الشركة.');
    if (result.error.code === 'PT409') return fail('تغيرت الحالة أثناء العمل. حدّث الملف قبل اختيار حالة جديدة.', false, true);
    if (result.error.message?.includes('people_employment_not_active')) return fail('انتهت علاقة العمل أثناء التعديل. حدّث الملف لمراجعة حالتها.', false, true);
    if (result.error.code === '23514') return fail('تعذر تغيير هذا التوظيف؛ إذا ارتبط براتب مقفل، استخدم مسار تصحيح الرواتب.', false, true);
    if (result.error.code === 'P0002' || result.error.code?.startsWith('22')) return fail('لم يعد اختيار الموظف متاحًا. أعد فتح الملف.', false, true);
    return fail('لم تصل نتيجة مؤكدة. استعد نتيجة التغيير بنفس الاختيار.', true);
  }
  const snapshot = payrollInclusion(result.data);
  if (!snapshot) return fail('لم تصل حالة مؤكدة. استعد نتيجة التغيير بنفس الاختيار.', true);
  revalidatePath(`/tenant/${tenant}/people`);
  revalidatePath(`/tenant/${tenant}/payroll`);
  return { snapshot, error: '', saved: true, uncertain: false, stale: false };
}
