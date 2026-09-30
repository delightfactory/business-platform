'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type LifecycleState = {
  tenantId: string; employeeId: string; employmentId: string; endDate: string;
  error: string; attempt: number;
};

export type RehireState = {
  tenantId: string; employeeId: string; employerId: string; siteId: string;
  departmentId: string; jobId: string; startDate: string; payBasis: string;
  amount: string; payrollEligible: boolean; error: string; attempt: number;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function endEmploymentAction(previous: LifecycleState, formData: FormData): Promise<LifecycleState> {
  const tenantId = value(formData, 'tenantId');
  const employeeId = value(formData, 'employeeId');
  const employmentId = value(formData, 'employmentId');
  const endDate = value(formData, 'endDate');
  const state = { tenantId, employeeId, employmentId, endDate, error: '', attempt: previous.attempt + 1 };
  const fail = (error: string): LifecycleState => ({ ...state, error });
  if (!uuidPattern.test(tenantId) || !uuidPattern.test(employeeId) || !uuidPattern.test(employmentId)
    || !/^\d{4}-\d{2}-\d{2}$/.test(endDate) || formData.get('acknowledgeHandoff') !== 'on') {
    return fail('راجع تأكيد تسليم المهام وتاريخ الإنهاء، ثم أعد المحاولة. لم يتغير سجل العمل.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. أعد المحاولة؛ لم يتغير سجل العمل.');
  const { error } = await supabase.rpc('end_people_employment', {
    p_tenant_id: tenantId, p_employee_id: employeeId, p_employment_id: employmentId, p_end_date: endDate,
  });
  if (error) return fail(endError(error.message));
  redirect(`/tenant/${tenantId}/people/${employeeId}?employment=ended`);
}

export async function rehireEmployeeAction(previous: RehireState, formData: FormData): Promise<RehireState> {
  const tenantId = value(formData, 'tenantId');
  const employeeId = value(formData, 'employeeId');
  const employerId = value(formData, 'employerId');
  const siteId = value(formData, 'siteId');
  const departmentId = value(formData, 'departmentId');
  const jobId = value(formData, 'jobId');
  const startDate = value(formData, 'startDate');
  const payBasis = value(formData, 'payBasis');
  const amount = value(formData, 'amount');
  const payrollEligible = formData.get('payrollEligible') === 'on';
  const state = { tenantId, employeeId, employerId, siteId, departmentId, jobId, startDate,
    payBasis, amount, payrollEligible, error: '', attempt: previous.attempt + 1 };
  const fail = (error: string): RehireState => ({ ...state, error });
  if (!uuidPattern.test(tenantId) || !uuidPattern.test(employeeId) || !uuidPattern.test(employerId)
    || !uuidPattern.test(siteId) || (departmentId && !uuidPattern.test(departmentId))
    || (jobId && !uuidPattern.test(jobId))) {
    return fail('اختر جهة التوظيف والفرع والقسم والوظيفة من القوائم المتاحة. بقيت المدخلات محفوظة.');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate) || !['monthly', 'daily'].includes(payBasis)
    || !/^\d{1,12}(\.\d{1,2})?$/.test(amount)) {
    return fail('راجع تاريخ البداية ونوع الأجر وقيمته، ثم أعد المحاولة. بقيت المدخلات محفوظة.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. أعد المحاولة؛ بقيت المدخلات محفوظة.');
  const { data, error } = await supabase.rpc('rehire_people_employee', {
    p_tenant_id: tenantId, p_employee_id: employeeId, p_employer_entity_id: employerId,
    p_site_id: siteId, p_start_date: startDate, p_pay_basis: payBasis, p_base_amount: amount,
    p_payroll_eligible: payrollEligible, p_department_id: departmentId || null, p_job_id: jobId || null,
  });
  if (error) return fail(rehireError(error.message));
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  if (result?.state !== 'rehired') return fail('تعذر تأكيد إنشاء علاقة العمل الجديدة. تحقّق من سجل الموظف قبل إعادة المحاولة.');
  redirect(`/tenant/${tenantId}/people/${employeeId}?employment=rehired`);
}

function value(data: FormData, key: string) { return String(data.get(key) ?? '').trim(); }

function endError(message: string) {
  if (message.includes('people_employment_manage_forbidden')) return 'لا تملك الصلاحيات اللازمة لإنهاء علاقة العمل وإغلاق بياناتها.';
  if (message.includes('people_employment_end_before_materialized_day') || message.includes('people_assignment_materialized_day')) return 'يوجد يوم حضور مفتوح بعد تاريخ الإنهاء المختار. اختر آخر يوم عمل يشمل أيام الحضور المفتوحة، ثم أعد المحاولة.';
  if (message.includes('people_employment_future_end_unsupported')) return 'لا يمكن تحديد إنهاء مستقبلي في هذه النسخة؛ اختر اليوم أو تاريخًا سابقًا.';
  if (message.includes('people_employment_end_before_start')) return 'لا يمكن أن يسبق آخر يوم عمل تاريخ بداية العلاقة.';
  if (message.includes('people_employment_end_after_effective_change')) return 'يوجد تكليف أو تغيير أجر بدأ بعد التاريخ المختار. اختر تاريخًا أحدث أو راجع السجل قبل الإنهاء.';
  if (message.includes('people_employment_not_started')) return 'لم تبدأ علاقة العمل بعد؛ لا يمكن إنهاؤها قبل يوم بدايتها.';
  if (message.includes('people_employment_not_active')) return 'علاقة العمل منتهية بالفعل أو تغيرت حالتها. حدّث الصفحة للتحقق.';
  if (message.includes('people_employment_current_assignment_missing') || message.includes('people_employment_current_compensation_missing')) return 'بيانات العمل الحالية غير مكتملة؛ راجع سجل التكليف والأجر قبل الإنهاء.';
  return 'تعذر إنهاء علاقة العمل. لم يُحفظ جزء من التغيير؛ حدّث الصفحة وراجع الحالة.';
}

function rehireError(message: string) {
  if (message.includes('people_rehire_forbidden')) return 'لا تملك الصلاحيات اللازمة لإعادة التوظيف وإدارة بيانات العمل والأجر.';
  if (message.includes('people_rehire_requires_ended_employee')) return 'إعادة التوظيف متاحة بعد انتهاء علاقة العمل السابقة فقط.';
  if (message.includes('people_rehire_active_employment_exists')) return 'لدى الموظف علاقة عمل نشطة بالفعل. حدّث الصفحة للتحقق.';
  if (message.includes('people_rehire_start_date_invalid') || message.includes('employee_employment_no_overlap')) return 'تاريخ البداية يجب أن يكون اليوم أو بعده، وبعد آخر يوم في العلاقة السابقة.';
  if (message.includes('people_employer_unavailable')) return 'جهة التوظيف غير نشطة أو غير متاحة. اختر جهة أخرى.';
  if (message.includes('people_site_unavailable')) return 'الفرع غير نشط أو لا يتبع جهة التوظيف المختارة.';
  if (message.includes('people_department_unavailable')) return 'القسم أو أحد أقسامه الأعلى غير نشط. اختر قسمًا متاحًا.';
  if (message.includes('people_job_unavailable')) return 'الوظيفة غير نشطة أو لا تتبع القسم المختار.';
  if (message.includes('people_rehire_input_invalid')) return 'بعض بيانات إعادة التوظيف غير صحيحة. راجع الحقول ثم أعد المحاولة.';
  return 'تعذر إعادة التوظيف. لم تُنشأ علاقة جزئية؛ بقيت المدخلات محفوظة.';
}
