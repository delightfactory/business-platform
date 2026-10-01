'use server';

import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject, isUuid, readAccess } from '../rules';
import {
  MAX_DATE_SPAN,
  MAX_REASON_LENGTH,
  MIN_REASON_LENGTH,
  daySpan,
  isDate,
  mapRecordError,
  recordErrorText,
  type RecordErrorCode,
  type RecordLeaveState,
} from './rules';

export async function recordLeaveAction(previous: RecordLeaveState, formData: FormData): Promise<RecordLeaveState> {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employee');
  const employmentId = field(formData, 'employment');
  const leaveTypeId = field(formData, 'leaveTypeId');
  const startDate = field(formData, 'startDate');
  const endDate = field(formData, 'endDate');
  const halfDayFlag = field(formData, 'halfDay');
  const partValue = field(formData, 'halfDayPart');
  const reason = field(formData, 'reason');
  const idempotencyKey = field(formData, 'operationKey');
  const failed = (code: RecordErrorCode): RecordLeaveState =>
    ({ error: recordErrorText(code), attempt: previous.attempt + 1, requestId: null });

  if (!isUuid(tenantId) || !isUuid(employeeId) || !isUuid(employmentId) || !isUuid(leaveTypeId)
    || !isUuid(idempotencyKey)) return failed('input');
  if (halfDayFlag !== 'true' && halfDayFlag !== 'false') return failed('input');
  if (partValue !== '' && partValue !== 'first' && partValue !== 'second') return failed('part');
  if (!isDate(startDate) || !isDate(endDate) || endDate < startDate
    || daySpan(startDate, endDate) > MAX_DATE_SPAN) return failed('range');
  const trimmedReason = reason.trim();
  if (trimmedReason.length < MIN_REASON_LENGTH || trimmedReason.length > MAX_REASON_LENGTH) return failed('reason');
  const halfDay = halfDayFlag === 'true';
  if (halfDay && startDate !== endDate) return failed('half-day');
  if (!halfDay && partValue !== '') return failed('part');

  const supabase = await createSupabaseServerClient();
  if (!supabase) return failed('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return failed('session');

  const accessResult = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  const access = accessResult.error ? null : readAccess(accessResult.data);
  if (!access) return failed(accessResult.error?.code === '42501' ? 'forbidden' : 'access');
  if (!access.canManage) return failed('forbidden');
  if (!access.newWorkEnabled) return failed('new-work-disabled');

  // Preserve the exact submitted intent on retry. The command validates mapping
  // and parts for new work; its authoritative replay precedes those current checks.
  const halfDayPart = halfDay && partValue !== '' ? partValue : null;

  const { data, error } = await supabase.rpc('leave_record_hr_request', {
    p_tenant: tenantId,
    p_employee: employeeId,
    p_employment: employmentId,
    p_type: leaveTypeId,
    p_start: startDate,
    p_end: endDate,
    p_half_day: halfDay,
    p_half_day_part: halfDayPart,
    p_reason: trimmedReason,
    p_idempotency_key: idempotencyKey,
  });
  if (error) return failed(mapRecordError(error.message, error.code));

  const requestId = isObject(data) && isUuid(data.id) ? data.id : null;
  if (!requestId) return failed('unknown');

  return { error: '', attempt: previous.attempt + 1, requestId };
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}
