'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import {
  MAX_DATE_SPAN,
  daySpan,
  isDate,
  isObject,
  isUuid,
  type LeaveOptionType,
  type LeaveOptionVersion,
  type LeaveOptionsState,
  type SubmitLeaveState,
  type WithdrawLeaveState,
} from './form-rules';

export async function loadLeaveRequestOptionsAction(formData: FormData): Promise<LeaveOptionsState> {
  const tenantId = field(formData, 'tenantId');
  const startDate = field(formData, 'startDate');
  const endDate = field(formData, 'endDate');
  const failed = (code: string): LeaveOptionsState => ({ startDate, endDate, types: [], error: optionsErrorText(code) });
  if (!isUuid(tenantId)) return failed('failed');
  if (!isDate(startDate) || !isDate(endDate) || endDate < startDate || daySpan(startDate, endDate) > MAX_DATE_SPAN) return failed('range');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failed('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return failed('session');
  const { data, error } = await supabase.rpc('leave_my_request_options', { p_tenant: tenantId, p_start: startDate, p_end: endDate });
  if (error) return failed(mapOptionsError(error.message, error.code));
  if (!isObject(data) || !Array.isArray(data.types)) return failed('failed');
  return { startDate, endDate, types: readOptionTypes(data.types), error: '' };
}

export async function submitLeaveRequestAction(previous: SubmitLeaveState, formData: FormData): Promise<SubmitLeaveState> {
  const tenantId = field(formData, 'tenantId');
  const leaveTypeId = field(formData, 'leaveTypeId');
  const startDate = field(formData, 'startDate');
  const endDate = field(formData, 'endDate');
  const halfDayFlag = field(formData, 'halfDay');
  const reason = field(formData, 'reason');
  const idempotencyKey = field(formData, 'idempotencyKey');
  const failed = (code: string): SubmitLeaveState => ({ error: submitErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !isUuid(leaveTypeId) || !isUuid(idempotencyKey)) return failed('invalid');
  if (halfDayFlag !== 'true' && halfDayFlag !== 'false') return failed('invalid');
  if (!isDate(startDate) || !isDate(endDate) || endDate < startDate || daySpan(startDate, endDate) > MAX_DATE_SPAN) return failed('range');
  if (halfDayFlag === 'true' && startDate !== endDate) return failed('half-day');
  const trimmedReason = reason.trim();
  if (trimmedReason.length < 3 || trimmedReason.length > 500) return failed('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failed('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return failed('session');
  const { data, error } = await supabase.rpc('leave_submit_own_request', {
    p_tenant: tenantId,
    p_type: leaveTypeId,
    p_start: startDate,
    p_end: endDate,
    p_half_day: halfDayFlag === 'true',
    p_half_day_part: null,
    p_reason: trimmedReason,
    p_idempotency_key: idempotencyKey,
  });
  if (error) return failed(mapSubmitError(error.message, error.code));
  const requestId = isObject(data) ? data.id : null;
  if (typeof requestId !== 'string' || !isUuid(requestId)) return failed('failed');
  redirect(`/tenant/${tenantId}/me/leave/${requestId}?state=submitted`);
}

export async function withdrawLeaveRequestAction(previous: WithdrawLeaveState, formData: FormData): Promise<WithdrawLeaveState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const versionText = field(formData, 'expectedVersion');
  const reason = field(formData, 'reason');
  const idempotencyKey = field(formData, 'idempotencyKey');
  const failed = (code: string): WithdrawLeaveState => ({ error: withdrawErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(idempotencyKey)) return failed('invalid');
  if (!/^\d{1,9}$/.test(versionText)) return failed('version');
  const expectedVersion = Number(versionText);
  if (!Number.isSafeInteger(expectedVersion) || expectedVersion < 1) return failed('version');
  const trimmedReason = reason.trim();
  if (trimmedReason.length < 3 || trimmedReason.length > 500) return failed('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failed('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return failed('session');
  const { data, error } = await supabase.rpc('leave_withdraw_own_request', {
    p_tenant: tenantId,
    p_request: requestId,
    p_expected_version: expectedVersion,
    p_reason: trimmedReason,
    p_idempotency_key: idempotencyKey,
  });
  if (error) return failed(mapWithdrawError(error.message, error.code));
  if (!isObject(data)) return failed('failed');
  redirect(`/tenant/${tenantId}/me/leave/${requestId}?state=withdrawn`);
}

function readOptionTypes(value: unknown[]): LeaveOptionType[] {
  const types: LeaveOptionType[] = [];
  for (const entry of value) {
    if (!isObject(entry) || !isUuid(entry.id) || typeof entry.name !== 'string' || entry.name.length === 0) continue;
    const versions: LeaveOptionVersion[] = [];
    if (Array.isArray(entry.versions)) {
      for (const version of entry.versions) {
        if (!isObject(version) || !isUuid(version.id) || typeof version.effective_from !== 'string'
          || !isDate(version.effective_from)) continue;
        const effectiveUntil = version.effective_until;
        versions.push({
          id: version.id,
          version: typeof version.version === 'number' ? version.version : 0,
          effective_from: version.effective_from,
          effective_until: typeof effectiveUntil === 'string' && isDate(effectiveUntil) ? effectiveUntil : null,
          half_day_allowed: version.half_day_allowed === true,
        });
      }
    }
    types.push({ id: entry.id, code: typeof entry.code === 'string' ? entry.code : '', name: entry.name, versions });
  }
  return types;
}

function mapOptionsError(message: string, code?: string): string {
  if (message.includes('leave_new_work_disabled')) return 'new-work-disabled';
  if (message.includes('leave_self_link_required')) return 'link';
  if (message.includes('leave_request_range_invalid')) return 'range';
  if (message.includes('leave_employment_range_unavailable')) return 'employment';
  if (message.includes('leave_self_forbidden') || message.includes('leave_forbidden') || code === '42501') return 'forbidden';
  return 'failed';
}

function mapSubmitError(message: string, code?: string): string {
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_new_work_disabled')) return 'new-work-disabled';
  if (message.includes('leave_self_link_required')) return 'link';
  if (message.includes('half_day')) return 'half-day';
  if (message.includes('leave_request_input_invalid') || message.includes('leave_request_range_invalid')) return 'range';
  if (message.includes('leave_type_unavailable')) return 'type';
  if (message.includes('leave_year_period_unavailable') || message.includes('leave_calendar_version_unavailable')
    || message.includes('leave_calendar_unavailable') || message.includes('leave_type_version_unavailable')) return 'configuration';
  if (message.includes('leave_request_zero_days')) return 'zero-days';
  if (message.includes('leave_employment_range_unavailable')) return 'employment';
  if (message.includes('leave_approval_queue_unavailable')) return 'queue';
  if (message.includes('leave_employer_unavailable') || message.includes('leave_employee_unavailable')) return 'unavailable';
  if (message.includes('leave_self_forbidden') || message.includes('leave_forbidden') || code === '42501') return 'forbidden';
  return 'failed';
}

function mapWithdrawError(message: string, code?: string): string {
  if (message.includes('leave_request_version_conflict')) return 'conflict';
  if (message.includes('leave_request_not_withdrawable')) return 'not-withdrawable';
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_request_unavailable') || code === 'P0002') return 'unavailable';
  if (message.includes('leave_withdraw_input_invalid')) return 'version';
  if (message.includes('leave_self_forbidden') || message.includes('leave_forbidden') || code === '42501') return 'forbidden';
  return 'failed';
}

function optionsErrorText(code: string): string {
  const messages: Record<string, string> = {
    range: 'اختر تاريخ بداية ونهاية صحيحين، بحد أقصى 732 يومًا متتاليًا (مدة تقويمية) في الطلب الواحد.',
    employment: 'تعذّر تغطية التواريخ المحددة ببيانات عملك لدى الشركة. اختر تواريخًا أخرى أو راجع إدارة الموارد البشرية.',
    'new-work-disabled': 'استعراض الأنواع متاح فقط عندما تكون خدمة الإجازات مفعّلة في الشركة. يمكنك مراجعة سجل طلباتك وأرصدتك.',
    link: 'حسابك غير مرتبط بملف موظف لدى الشركة. راجع إدارة الموارد البشرية لربط حسابك.',
    forbidden: 'ليست لديك صلاحية طلب إجازة من هذا الحساب. راجع إدارة الموارد البشرية.',
    session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
    setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
    failed: 'تعذر تحميل أنواع الإجازة المتاحة لهذه الفترة. أعد المحاولة أو تواصل مع إدارة الموارد البشرية.',
  };
  return messages[code] ?? messages.failed;
}

function submitErrorText(code: string): string {
  const messages: Record<string, string> = {
    invalid: 'راجع بيانات الطلب ثم أعد المحاولة.',
    range: 'اختر تاريخ بداية ونهاية صحيحين، بحد أقصى 732 يومًا متتاليًا (مدة تقويمية) في الطلب الواحد.',
    'half-day': 'طلب نصف يوم يتطلب تاريخ بداية ونهاية متطابقين، ونوعًا يسمح بنصف يوم في هذا التاريخ.',
    reason: 'اكتب سببًا واضحًا من 3 إلى 500 حرف.',
    type: 'نوع الإجازة المحدد لم يعد متاحًا. أعد تحميل الأنواع واختر نوعًا آخر.',
    configuration: 'الفترة أو تقويم الإجازات غير مهيأين لهذه التواريخ. اختر تواريخًا ضمن فترة إجازات مفعّلة.',
    'zero-days': 'لا توجد أيام عمل مؤهلة ضمن التاريخين المحددين. اختر تواريخ أخرى.',
    employment: 'تعذّر تغطية التواريخ المحددة ببيانات عملك لدى الشركة. اختر تواريخًا أخرى أو راجع إدارة الموارد البشرية.',
    queue: 'إرسال الطلبات غير متاح حاليًا في الشركة. تواصل مع إدارة الموارد البشرية.',
    unavailable: 'تعذر فتح طلب الإجازة الآن. أعد المحاولة أو حدّث الصفحة.',
    'key-conflict': 'تعذّر تأكيد نتيجة الإرسال بسبب تعارض في بيانات الطلب. أعد المحاولة بنفس البيانات دون تغيير، أو راجع سجل طلباتك.',
    'new-work-disabled': 'إنشاء طلبات الإجازة غير متاح حاليًا. يمكنك مراجعة سجل طلباتك وأرصدتك من صفحة إجازاتي.',
    link: 'حسابك غير مرتبط بملف موظف لدى الشركة. راجع إدارة الموارد البشرية لربط حسابك.',
    forbidden: 'ليست لديك صلاحية إرسال طلبات إجازة من هذا الحساب.',
    session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
    setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
    failed: 'تعذّر تأكيد نتيجة إرسال طلب الإجازة. أعد المحاولة بنفس البيانات دون تغيير، أو راجع سجل طلباتك للتحقق من حالة الطلب.',
  };
  return messages[code] ?? messages.failed;
}

function withdrawErrorText(code: string): string {
  const messages: Record<string, string> = {
    invalid: 'تعذر تنفيذ السحب. حدّث الصفحة ثم أعد المحاولة.',
    version: 'رقم إصدار الطلب غير صالح أو تغيّر منذ فتح الصفحة. حدّث الصفحة ثم أعد المحاولة.',
    reason: 'اكتب سبب السحب من 3 إلى 500 حرف.',
    unavailable: 'الطلب غير متاح للسحب. حدّث الصفحة للتحقق من حالته.',
    'not-withdrawable': 'لا يمكن سحب هذا الطلب بعد حالته الحالية. راجع حالته في صفحة إجازاتي.',
    conflict: 'تغيّر الطلب منذ فتح الصفحة. حدّثها ثم أعد المحاولة.',
    'key-conflict': 'تعذّر تأكيد نتيجة السحب بسبب تعارض في بيانات الطلب. أعد المحاولة بنفس البيانات دون تغيير، أو راجع صفحة الطلب للتحقق من حالته.',
    forbidden: 'ليست لديك صلاحية سحب هذا الطلب.',
    session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
    setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
    failed: 'تعذّر تأكيد نتيجة سحب طلب الإجازة. أعد المحاولة بنفس البيانات دون تغيير، أو راجع صفحة الطلب للتحقق من حالته.',
  };
  return messages[code] ?? messages.failed;
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}
