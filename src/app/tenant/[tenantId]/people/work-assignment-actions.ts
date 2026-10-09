'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type AssignmentFormState = {
  tenantId: string; employmentId: string; employeeId: string; siteId: string; departmentId: string;
  jobId: string; managerId: string; effectiveDate: string; error: string; attempt: number;
};

export async function scheduleWorkAssignmentAction(
  previous: AssignmentFormState,
  formData: FormData,
): Promise<AssignmentFormState> {
  const next: AssignmentFormState = {
    tenantId: readForm(formData, 'tenantId'),
    employmentId: readForm(formData, 'employmentId'),
    employeeId: readForm(formData, 'employeeId'),
    siteId: readForm(formData, 'siteId'),
    departmentId: readForm(formData, 'departmentId'),
    jobId: readForm(formData, 'jobId'),
    managerId: readForm(formData, 'managerId'),
    effectiveDate: readForm(formData, 'effectiveDate'),
    error: '',
    attempt: previous.attempt + 1,
  };
  const fail = (message: string) => ({ ...next, error: message });
  if (!isUuid(next.tenantId) || !isUuid(next.employmentId) || !isUuid(next.employeeId) || !isUuid(next.siteId)
      || (next.departmentId && !isUuid(next.departmentId))
      || (next.jobId && !isUuid(next.jobId)) || (next.managerId && !isUuid(next.managerId))
      || !/^\d{4}-\d{2}-\d{2}$/.test(next.effectiveDate)) {
    return fail('راجع بيانات النقل وتاريخه ثم أعد المحاولة.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الخدمة غير متاحة الآن. أعد المحاولة؛ بقيت البيانات التي أدخلتها محفوظة.');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.');
  const { data, error } = await supabase.rpc('schedule_people_work_assignment', {
    p_tenant_id: next.tenantId,
    p_employment_id: next.employmentId,
    p_effective_date: next.effectiveDate,
    p_site_id: next.siteId,
    p_department_id: next.departmentId || null,
    p_job_id: next.jobId || null,
    p_manager_employee_id: next.managerId || null,
  });
  if (error) return fail(assignmentError(error.message));
  const rpcReply = data && typeof data === 'object' && !Array.isArray(data)
    ? data as Record<string, unknown> : null;
  if (rpcReply?.state !== 'scheduled' && rpcReply?.state !== 'transferred') {
    return fail('تعذر تأكيد حفظ النقل. حدّث سجل العمل قبل إعادة المحاولة.');
  }
  redirect(`/tenant/${next.tenantId}/people/${next.employeeId}?assignment=${rpcReply.state}`);
}

export async function correctInitialWorkAssignmentAction(
  previous: AssignmentFormState,
  formData: FormData,
): Promise<AssignmentFormState> {
  const next = { ...readAssignmentForm(formData), error: '', attempt: previous.attempt + 1 };
  const fail = (message: string) => ({ ...next, error: message });
  if (!isUuid(next.tenantId) || !isUuid(next.employmentId) || !isUuid(next.employeeId) || !isUuid(next.siteId)
      || (next.departmentId && !isUuid(next.departmentId))
      || (next.jobId && !isUuid(next.jobId)) || (next.managerId && !isUuid(next.managerId))) {
    return fail('راجع بيانات التصحيح ثم أعد المحاولة.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الخدمة غير متاحة الآن. أعد المحاولة؛ بقيت البيانات التي أدخلتها محفوظة.');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.');
  const { data, error } = await supabase.rpc('correct_initial_people_work_assignment', {
    p_tenant_id: next.tenantId,
    p_employment_id: next.employmentId,
    p_site_id: next.siteId,
    p_department_id: next.departmentId || null,
    p_job_id: next.jobId || null,
    p_manager_employee_id: next.managerId || null,
  });
  if (error) return fail(assignmentError(error.message));
  const reply = data && typeof data === 'object' && !Array.isArray(data)
    ? data as Record<string, unknown> : null;
  if (reply?.state !== 'corrected') return fail('تعذر تأكيد التصحيح. حدّث سجل العمل قبل إعادة المحاولة.');
  redirect(`/tenant/${next.tenantId}/people/${next.employeeId}?assignment=corrected`);
}

export async function cancelWorkAssignmentAction(formData: FormData): Promise<void> {
  const tenantId = readForm(formData, 'tenantId');
  const employmentId = readForm(formData, 'employmentId');
  const assignmentId = readForm(formData, 'assignmentId');
  const employeeId = readForm(formData, 'employeeId');
  if (![tenantId, employmentId, assignmentId, employeeId].every(isUuid)) {
    redirect('/tenant');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`/tenant/${tenantId}/people/${employeeId}?assignment=cancel-error`);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/${employeeId}`)}`);
  const { error } = await supabase.rpc('cancel_people_work_assignment', {
    p_tenant_id: tenantId, p_employment_id: employmentId, p_assignment_id: assignmentId,
  });
  if (error) redirect(`/tenant/${tenantId}/people/${employeeId}?assignment=cancel-error`);
  redirect(`/tenant/${tenantId}/people/${employeeId}?assignment=cancelled`);
}

function readForm(formData: FormData, key: string) { return String(formData.get(key) ?? '').trim(); }
function readAssignmentForm(formData: FormData) {
  return {
    tenantId: readForm(formData, 'tenantId'), employmentId: readForm(formData, 'employmentId'),
    employeeId: readForm(formData, 'employeeId'), siteId: readForm(formData, 'siteId'),
    departmentId: readForm(formData, 'departmentId'), jobId: readForm(formData, 'jobId'),
    managerId: readForm(formData, 'managerId'), effectiveDate: readForm(formData, 'effectiveDate'),
  };
}
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }

function assignmentError(message: string) {
  if (message.includes('lock timeout') || message.includes('deadlock detected')) return 'هناك إجراء جارٍ على مصادر الرواتب. البيانات محفوظة؛ أعد المحاولة بعد اكتماله.';
  if (message.includes('payroll_people_correction_required')) return 'يمس هذا التغيير فترة راتب مقفلة. لم تتغير البيانات؛ راجع مسؤول تصحيح الرواتب لإعداد مقترح التصحيح بتاريخ سريان محدد ومراجعة المسيرات المحفوظة المتأثرة للفترة نفسها.';
  if (message.includes('people_org_manage_forbidden')) return 'تحتاج إلى صلاحية تعديل بيانات العمل في هذه الشركة.';
  if (message.includes('people_assignment_materialized_day')) return 'بدأ تسجيل حضور لهذا اليوم وفق بيانات العمل الحالية؛ لا يمكن تغيير بياناته بعد فتح اليوم. اختر تاريخ سريان لاحقًا لم يُفتح للحضور.';
  if (message.includes('people_assignment_future_exists')) return 'يوجد نقل مقرر بالفعل. ألغِ النقل المقرر قبل إضافة تغيير آخر.';
  if (message.includes('people_assignment_current_missing')) return 'لا يوجد تعيين حالي مفتوح يمكن نقله. راجع سجل العمل أو مسؤول الموارد البشرية.';
  if (message.includes('people_assignment_before_current_start')) return 'يجب أن يبدأ التغيير بعد تاريخ بداية التعيين الحالي.';
  if (message.includes('people_assignment_initial_correction_window_closed')) return 'انتهت الفترة المسموح فيها بتصحيح بيانات يوم بداية العمل. استخدم تغيير العمل بتاريخ سريان جديد.';
  if (message.includes('people_assignment_initial_correction_only')) return 'التصحيح متاح لبيانات العمل الأولى في يوم بداية العمل فقط.';
  if (message.includes('people_assignment_future_exists')) return 'ألغِ النقل المقرر أولًا قبل تصحيح بيانات العمل عند بداية التعيين.';
  if (message.includes('people_assignment_backdate_not_supported')) return 'لا يمكن تسجيل تغيير بتاريخ سابق. اختر اليوم أو تاريخًا لاحقًا.';
  if (message.includes('people_assignment_site_unavailable')) return 'الفرع غير نشط أو لا يتبع جهة التوظيف الحالية. اختر فرعًا آخر.';
  if (message.includes('people_assignment_department_unavailable')) return 'القسم غير نشط أو لا يتبع هذه الشركة. اختر قسمًا متاحًا.';
  if (message.includes('people_assignment_job_department_mismatch')) return 'الوظيفة تتبع قسمًا آخر. اختر وظيفة مناسبة للقسم المحدد.';
  if (message.includes('people_assignment_job_unavailable')) return 'الوظيفة غير نشطة أو لم تعد متاحة. اختر وظيفة أخرى.';
  if (message.includes('people_assignment_self_manager')) return 'لا يمكن اختيار الموظف مديرًا لنفسه.';
  if (message.includes('people_assignment_manager_unavailable')) return 'المدير غير نشط في تاريخ سريان التغيير أو لا يتبع هذه الشركة. اختر مديرًا متاحًا في ذلك التاريخ.';
  if (message.includes('people_assignment_employment_inactive')) return 'لا يمكن تغيير بيانات العمل لعلاقة توظيف منتهية.';
  if (message.includes('people_assignment_after_employment_end')) return 'تاريخ التغيير يأتي بعد نهاية علاقة العمل.';
  if (message.includes('people_assignment_audit')) return 'تعذر تسجيل التغيير؛ لم يُحفظ أي تعديل. أعد المحاولة.';
  if (message.includes('work_assignment_no_overlap')) return 'يتعارض هذا التاريخ مع تعيين آخر. حدّث سجل العمل ثم أعد المحاولة.';
  return 'تعذر حفظ تغيير العمل. لم يُحفظ تعديل جزئي؛ راجع البيانات ثم أعد المحاولة.';
}
