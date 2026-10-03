'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type NewEmployeeState = {
  code: string; name: string; employerId: string; siteId: string;
  departmentId: string; jobId: string; startDate: string;
  payBasis: string; amount: string; payrollEligible: boolean;
  error: string; attempt: number;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function createEmployeeAction(previous: NewEmployeeState, formData: FormData): Promise<NewEmployeeState> {
  const tenantId = value(formData, 'tenantId');
  const code = value(formData, 'code');
  const name = value(formData, 'name');
  const employerId = value(formData, 'employerId');
  const siteId = value(formData, 'siteId');
  const departmentId = value(formData, 'departmentId');
  const jobId = value(formData, 'jobId');
  const startDate = value(formData, 'startDate');
  const payBasis = value(formData, 'payBasis');
  const amount = value(formData, 'amount');
  const payrollEligible = formData.get('payrollEligible') === 'on';
  const state = { code, name, employerId, siteId, departmentId, jobId, startDate,
    payBasis, amount, payrollEligible, error: '', attempt: previous.attempt + 1 };
  const fail = (error: string): NewEmployeeState => ({ ...state, error });

  if (!uuidPattern.test(tenantId) || !uuidPattern.test(employerId) || !uuidPattern.test(siteId)
    || (departmentId && !uuidPattern.test(departmentId)) || (jobId && !uuidPattern.test(jobId))) {
    return fail('اختر جهة التوظيف والفرع من القوائم المتاحة ثم أعد المحاولة. بقيت البيانات التي أدخلتها محفوظة.');
  }
  if (!code || code.length > 40 || name.length < 2 || name.length > 160
    || !/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !['monthly', 'daily'].includes(payBasis)
    || !/^\d{1,12}(\.\d{1,2})?$/.test(amount)) {
    return fail('راجع رمز الموظف واسمه وتاريخ البداية والأجر، ثم أعد المحاولة. بقيت البيانات التي أدخلتها محفوظة.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. أعد المحاولة؛ بقيت البيانات التي أدخلتها محفوظة.');
  const { data, error } = await supabase.rpc('create_people_employee', {
    p_tenant_id: tenantId, p_employee_code: code, p_full_name: name,
    p_employer_entity_id: employerId, p_site_id: siteId, p_start_date: startDate,
    p_pay_basis: payBasis, p_base_amount: amount, p_payroll_eligible: payrollEligible,
    p_department_id: departmentId || null, p_job_id: jobId || null,
  });
  if (error) return fail(errorText(error.message));
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  const employeeId = typeof result?.employee_id === 'string' ? result.employee_id : '';
  if (!uuidPattern.test(employeeId)) return fail('تعذر تأكيد حفظ الموظف. أعد المحاولة بعد التحقق من الدليل.');
  redirect(`/tenant/${tenantId}/people/${employeeId}?state=created`);
}

function value(data: FormData, key: string) { return String(data.get(key) ?? '').trim(); }

function errorText(message: string) {
  if (message.includes('payroll_people_correction_required')) return 'يمس التوظيف فترة راتب نهائية. البيانات التي أدخلتها محفوظة؛ اطلب من مسؤول تصحيح الرواتب مراجعة إضافة التوظيف قبل المتابعة.';
  if (message.includes('lock timeout') || message.includes('deadlock detected')) return 'هناك إجراء جارٍ على مصادر الرواتب. البيانات محفوظة؛ أعد المحاولة بعد اكتماله.';
  if (message.includes('employees_code_per_tenant_idx')) return 'رمز الموظف مستخدم بالفعل في هذه الشركة. اختر رمزًا آخر؛ بقيت بقية البيانات محفوظة.';
  if (message.includes('people_onboard_forbidden')) return 'ليس لديك صلاحية إضافة موظف أو إدارة بيانات توظيفه وأجره، أو أن خدمة الموارد البشرية غير مفعّلة.';
  if (message.includes('people_employer_unavailable')) return 'جهة التوظيف غير نشطة أو لم تعد متاحة. اختر جهة أخرى.';
  if (message.includes('people_site_unavailable')) return 'الفرع غير نشط أو لا يتبع جهة التوظيف المختارة. اختر فرعًا مناسبًا.';
  if (message.includes('people_department_unavailable')) return 'القسم غير نشط أو لم يعد متاحًا. اختر قسمًا آخر.';
  if (message.includes('people_job_unavailable')) return 'الوظيفة غير متاحة أو لا تتبع القسم المختار. اختر وظيفة مناسبة.';
  if (message.includes('people_assignment_department_unavailable')) return 'القسم أو أحد أقسامه الأعلى غير نشط. اختر قسمًا نشطًا.';
  if (message.includes('people_assignment_job_unavailable')) return 'الوظيفة أو قسمها غير نشط. اختر وظيفة متاحة.';
  if (message.includes('people_assignment_job_department_mismatch')) return 'الوظيفة لا تتبع القسم المختار. اختر وظيفة مناسبة.';
  if (message.includes('people_onboard_invalid')) return 'بعض البيانات غير صحيحة. راجع الحقول ثم أعد المحاولة.';
  return 'تعذر إضافة الموظف الآن. لم يُحفظ سجل جزئي؛ راجع البيانات وأعد المحاولة.';
}
