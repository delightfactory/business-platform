'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type WorkPolicySaveState = { error: string };

export async function saveWorkPolicyAction(_previous: WorkPolicySaveState, formData: FormData): Promise<WorkPolicySaveState> {
  const tenantId = text(formData, 'tenantId');
  const templateId = text(formData, 'templateId') || null;
  const code = text(formData, 'code');
  const name = text(formData, 'name');
  const kind = text(formData, 'kind');
  const overtimeEnabled = formData.get('overtimeEnabled') === 'on';
  const autoApproveClean = formData.get('autoApproveClean') === 'on';
  const overtimeMinimum = Number(text(formData, 'overtimeMinimum') || '30');
  const overtimeRounding = Number(text(formData, 'overtimeRounding') || '15');
  const mappingEnabled = formData.get('leaveMappingEnabled') === 'on';
  const breakMinutes = Number(text(formData, 'breakMinutes') || '0');
  const fixedBreakStart = kind === 'fixed' && breakMinutes > 0 && mappingEnabled ? text(formData, 'fixedBreakStart') || null : null;
  const fixedBreakEnd = kind === 'fixed' && breakMinutes > 0 && mappingEnabled ? text(formData, 'fixedBreakEnd') || null : null;
  const halfdayBreakText = text(formData, 'flexibleHalfdayBreak');
  const halfdayBreak = kind === 'flexible' && mappingEnabled && halfdayBreakText !== '' ? Number(halfdayBreakText) : null;
  if (!Number.isInteger(breakMinutes) || breakMinutes < 0 || breakMinutes > 360
    || (mappingEnabled && kind === 'fixed' && breakMinutes > 0 && (!fixedBreakStart || !fixedBreakEnd || !/^\d{2}:\d{2}$/.test(fixedBreakStart) || !/^\d{2}:\d{2}$/.test(fixedBreakEnd)))
    || (mappingEnabled && kind === 'flexible' && (halfdayBreak === null || !Number.isInteger(halfdayBreak) || halfdayBreak < 0 || halfdayBreak > 360))) return { error: 'راجع إعداد نصف اليوم: حدد أوقات الاستراحة، أو أدخل مدة استراحة الدوام المرن بين صفر و360 دقيقة.' };
  const days = formData.getAll('workDays').map(Number).filter((day) => Number.isInteger(day) && day >= 1 && day <= 7);
  if (!isUuid(tenantId) || (templateId && !isUuid(templateId)) || !code || !name || !['fixed', 'flexible'].includes(kind) || !days.length
    || !Number.isInteger(overtimeMinimum) || overtimeMinimum < 15 || overtimeMinimum > 480
    || !Number.isInteger(overtimeRounding) || overtimeRounding < 5 || overtimeRounding > 60 || overtimeRounding > overtimeMinimum) return { error: 'تحقق من بيانات القالب وأيام العمل ومدد العمل الإضافي.' };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { error: 'الاتصال غير متاح. بياناتك محفوظة في النموذج؛ أعد المحاولة.' };
  const { error } = await supabase.rpc(mappingEnabled ? 'save_time_work_policy_with_leave_mapping' : 'save_time_work_policy', {
    p_tenant_id: tenantId, p_template_id: templateId, p_code: code, p_name: name, p_kind: kind,
    p_timezone: text(formData, 'timezone') || 'Africa/Cairo', p_work_days: days,
    p_start: kind === 'fixed' ? text(formData, 'shiftStart') || null : null,
    p_end: kind === 'fixed' ? text(formData, 'shiftEnd') || null : null,
    p_next_day: kind === 'fixed' && formData.get('nextDay') === 'on',
    p_break: kind === 'fixed' ? breakMinutes : 0,
    p_required: kind === 'flexible' ? Number(text(formData, 'requiredMinutes')) : null,
    p_earliest: kind === 'flexible' ? text(formData, 'earliestPunch') || null : null,
    p_latest: kind === 'flexible' ? text(formData, 'latestPunch') || null : null,
    p_before: Number(text(formData, 'attributionBefore') || '120'),
    p_after: Number(text(formData, 'attributionAfter') || '360'),
    p_overtime_enabled: overtimeEnabled, p_overtime_minimum: overtimeMinimum, p_overtime_rounding: overtimeRounding,
    p_auto_approve_clean: autoApproveClean,
    ...(mappingEnabled ? { p_fixed_break_start: fixedBreakStart, p_fixed_break_end: fixedBreakEnd, p_flexible_halfday_break_minutes: halfdayBreak } : {}),
  });
  if (error) return { error: error.message.includes('attendance_policy_manage_forbidden') ? 'لا تملك صلاحية إدارة سياسات الحضور.' : error.message.includes('time_policy_halfday_mapping') ? 'راجع أوقات الاستراحة: يجب أن تقع داخل الوردية وتساوي مدتها المحددة. بياناتك محفوظة في النموذج.' : 'تعذر حفظ القالب. بياناتك محفوظة في النموذج؛ أعد المحاولة.' };
  const returnToRequest = text(formData, 'returnToRequest');
  redirect(`/tenant/${tenantId}/people/work-policies?state=saved${isUuid(returnToRequest) ? `&returnToRequest=${returnToRequest}` : ''}`);
}

export async function setWorkPolicyActiveAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId'); const policyId = text(formData, 'policyId');
  const active = text(formData, 'active') === 'true';
  if (!isUuid(tenantId) || !isUuid(policyId)) redirect(`/tenant/${tenantId}/people/work-policies?state=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`/tenant/${tenantId}/people/work-policies?state=setup`);
  const { error } = await supabase.rpc('set_time_work_policy_active', { p_tenant_id: tenantId, p_template_id: policyId, p_active: active });
  if (error) redirect(`/tenant/${tenantId}/people/work-policies?state=failed`);
  redirect(`/tenant/${tenantId}/people/work-policies?state=${active ? 'activated' : 'deactivated'}`);
}

export async function assignWorkPolicyAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId'); const employeeId = text(formData, 'employeeId');
  const employmentId = text(formData, 'employmentId'); const policyId = text(formData, 'policyId'); const effectiveDate = text(formData, 'effectiveDate');
  if (!isUuid(tenantId) || !isUuid(employeeId) || !isUuid(employmentId) || !isUuid(policyId) || !/^\d{4}-\d{2}-\d{2}$/.test(effectiveDate)) redirect(`/tenant/${tenantId}/people/${employeeId}?policy=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`/tenant/${tenantId}/people/${employeeId}?policy=failed`);
  const { error } = await supabase.rpc('assign_people_work_policy', { p_tenant_id: tenantId, p_employment_id: employmentId, p_policy_id: policyId, p_effective_date: effectiveDate });
  if (error) redirect(`/tenant/${tenantId}/people/${employeeId}?policy=${error.message.includes('people_assignment_materialized_day') ? 'materialized' : error.message.includes('people_assignment_future_exists') ? 'pending' : 'failed'}`);
  redirect(`/tenant/${tenantId}/people/${employeeId}?policy=assigned`);
}

export async function assignAttendancePolicyOverrideAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId'); const employeeId = text(formData, 'employeeId');
  const employmentId = text(formData, 'employmentId'); const policyId = text(formData, 'policyId');
  const validFrom = text(formData, 'validFrom'); const validThrough = text(formData, 'validThrough');
  const reason = text(formData, 'reason');
  const path = `/tenant/${tenantId}/people/${employeeId}`;
  if (!isUuid(tenantId) || !isUuid(employeeId) || !isUuid(employmentId) || !isUuid(policyId)
    || !/^\d{4}-\d{2}-\d{2}$/.test(validFrom) || !/^\d{4}-\d{2}-\d{2}$/.test(validThrough)
    || reason.length < 3 || reason.length > 500) redirect(`${path}?policyOverride=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${path}?policyOverride=failed`);
  const { error } = await supabase.rpc('assign_attendance_work_policy_override', {
    p_tenant_id: tenantId, p_employment_id: employmentId, p_policy_id: policyId,
    p_valid_from: validFrom, p_valid_through: validThrough, p_reason: reason,
  });
  if (error) {
    const state = error.message.includes('attendance_policy_manage_forbidden') ? 'forbidden'
      : error.message.includes('attendance_policy_override_overlap') ? 'overlap'
        : error.message.includes('attendance_policy_override_materialized_date') ? 'materialized'
          : error.message.includes('attendance_policy_override_historical') ? 'historical'
            : 'failed';
    redirect(`${path}?policyOverride=${state}`);
  }
  redirect(`${path}?policyOverride=assigned`);
}

export async function cancelAttendancePolicyOverrideAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId'); const employeeId = text(formData, 'employeeId');
  const overrideId = text(formData, 'overrideId'); const reason = text(formData, 'cancelReason');
  const path = `/tenant/${tenantId}/people/${employeeId}`;
  if (!isUuid(tenantId) || !isUuid(employeeId) || !isUuid(overrideId) || reason.length < 3 || reason.length > 500) redirect(`${path}?policyOverride=invalid`);
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${path}?policyOverride=failed`);
  const { error } = await supabase.rpc('cancel_attendance_work_policy_override', {
    p_tenant_id: tenantId, p_override_id: overrideId, p_reason: reason,
  });
  if (error) redirect(`${path}?policyOverride=cancel-failed`);
  redirect(`${path}?policyOverride=cancelled`);
}

function text(data: FormData, key: string) { return String(data.get(key) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
