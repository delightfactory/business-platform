'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject, isUuid, readAccess } from '../rules';
import {
  MAX_DATE_SPAN,
  MAX_QUERY_LENGTH,
  MAX_REASON_LENGTH,
  MIN_REASON_LENGTH,
  daySpan,
  isDate,
  mapRecordError,
  readHalfDayContext,
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
  const backQuery = field(formData, 'q').slice(0, MAX_QUERY_LENGTH);
  const reason = field(formData, 'reason');
  const failed = (code: RecordErrorCode): RecordLeaveState =>
    ({ error: recordErrorText(code), attempt: previous.attempt + 1 });

  if (!isUuid(tenantId) || !isUuid(employeeId) || !isUuid(employmentId) || !isUuid(leaveTypeId)) return failed('input');
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

  let halfDayPart: string | null = null;
  if (halfDay) {
    const contextResult = await supabase.rpc('leave_hr_halfday_mapping_options', {
      p_tenant: tenantId,
      p_employment: employmentId,
      p_operational_date: startDate,
    });
    const context = contextResult.error ? null : readHalfDayContext(contextResult.data);
    if (!context) {
      const message = contextResult.error?.message ?? '';
      if (contextResult.error?.code === '23514') return failed('employment');
      if (contextResult.error?.code === '42501') return failed('forbidden');
      if (message.includes('leave_new_work_disabled')) return failed('new-work-disabled');
      return failed('half-day-context');
    }
    const fixed = context.state === 'mapped_options' && context.scheduleKind === 'fixed';
    if (fixed) {
      if (partValue !== 'first' && partValue !== 'second') return failed('part');
      halfDayPart = partValue;
    } else if (partValue !== '') {
      return failed('part');
    }
  }

  const idempotencyKey = await deriveIdempotencyKey([
    'hr.recorded_submitted', tenantId, employeeId, employmentId, leaveTypeId,
    startDate, endDate, halfDay ? 'true' : 'false', halfDayPart ?? '', trimmedReason,
  ]);
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

  const params = new URLSearchParams({ state: 'submitted', request: requestId, start: startDate, end: endDate });
  if (backQuery) params.set('q', backQuery);
  redirect(`/tenant/${tenantId}/leave/new?${params.toString()}`);
}

async function deriveIdempotencyKey(parts: string[]): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(parts)));
  const bytes = new Uint8Array(digest.slice(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}
