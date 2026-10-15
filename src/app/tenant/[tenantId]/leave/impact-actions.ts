'use server';

import { createSupabaseServerClient } from '@/lib/supabase/server';
import { leaveImpactSignature, type LeaveImpactInput, type LeaveImpactResult, type LeaveCurrentBalance } from '@/lib/leave-impact';
import { daySpan, isDate, isObject, isUuid, MAX_DATE_SPAN } from '../me/leave/form-rules';

// Independent from the date preview: missing calendar coverage must not erase the current accounts.
export async function loadLeaveCurrentBalance(input: Pick<LeaveImpactInput, 'tenantId' | 'typeId' | 'employeeId'>, page = 0): Promise<LeaveCurrentBalance> {
  const unavailable: LeaveCurrentBalance = { state: 'unavailable' };
  if (!isUuid(input.tenantId) || !isUuid(input.typeId) || (input.employeeId !== undefined && !isUuid(input.employeeId))
    || !Number.isInteger(page) || page < 0 || page > 21474836) return unavailable;
  try {
    const client = await createSupabaseServerClient();
    if (!client) return unavailable;
    const { data: { user } } = await client.auth.getUser();
    if (!user) return unavailable;
    const { data, error } = await client.rpc(input.employeeId ? 'leave_hr_balances' : 'leave_my_balances', {
      p_tenant: input.tenantId, p_limit: 100, p_offset: page * 100,
      ...(input.employeeId ? { p_employee: input.employeeId } : {}),
    });
    if (error) return error.code === '42501' ? { state: 'hidden' } : unavailable;
    if (!isObject(data) || !Array.isArray(data.items) || typeof data.has_more !== 'boolean') return unavailable;
    const accounts: NonNullable<LeaveCurrentBalance['accounts']> = [];
    for (const item of data.items) {
      if (!isObject(item) || !isUuid(item.leave_type_id) || !isUuid(item.period_id)
        || typeof item.period_label !== 'string' || typeof item.starts_on !== 'string' || !isDate(item.starts_on)
        || (input.employeeId && item.employee_id !== input.employeeId)
        || typeof item.balance_days !== 'number' || !Number.isFinite(item.balance_days)) return unavailable;
      if (item.leave_type_id === input.typeId) accounts.push({ periodId: item.period_id, label: item.period_label,
        startsOn: item.starts_on, days: String(item.balance_days) });
    }
    return { state: 'ready', accounts, hasMore: data.has_more };
  } catch { return unavailable; }
}

export async function loadLeaveImpact(input: LeaveImpactInput): Promise<LeaveImpactResult> {
  const signature = leaveImpactSignature(input);
  const failed = (reason: string): LeaveImpactResult => ({ signature, impact: { state: 'unavailable', reason } });
  if (!isUuid(input.tenantId) || !isUuid(input.typeId) || !isDate(input.start) || !isDate(input.end)
    || input.end < input.start || daySpan(input.start,input.end) > MAX_DATE_SPAN || typeof input.halfDay !== 'boolean'
    || (input.halfDay && input.start !== input.end) || ![null,'first','second'].includes(input.part)
    || (!input.halfDay && input.part !== null)) return failed('input');
  const hr = input.employeeId !== undefined || input.employmentId !== undefined;
  if (hr && (!isUuid(input.employeeId) || !isUuid(input.employmentId))) return failed('input');
  try {
    const client = await createSupabaseServerClient();
    if (!client) return failed('connection');
    const { data: { user } } = await client.auth.getUser();
    if (!user) return failed('session');
    const { data, error } = await client.rpc(hr ? 'leave_hr_request_preview' : 'leave_my_request_preview', {
      p_tenant: input.tenantId,p_type: input.typeId,p_start: input.start,p_end: input.end,
      p_half_day: input.halfDay,p_half_day_part: input.part,
      ...(hr ? { p_employee: input.employeeId,p_employment: input.employmentId } : {}),
    });
    if (error) return failed(error.code === '42501' ? 'forbidden' : 'connection');
    if (!isObject(data) || !isObject(data.input) || data.input.type !== input.typeId || data.input.start !== input.start
      || data.input.end !== input.end || data.input.half_day !== input.halfDay || data.input.part !== input.part) return failed('response');
    if (data.state === 'unavailable' && typeof data.reason === 'string') return { signature, impact: { state: 'unavailable', reason: data.reason } };
    const decimal = (value: unknown): value is string => typeof value === 'string' && /^\d+\.\d{2}$/.test(value);
    const balance = data.balance;
    if (data.state !== 'ready' || !decimal(data.total_units) || !decimal(data.tracked_units) || !Array.isArray(data.days)
      || !isObject(balance) || !['shown','hidden','not_tracked','unavailable'].includes(String(balance.state))) return failed('response');
    for (const day of data.days) {
      if (!isObject(day) || typeof day.date !== 'string' || !isDate(day.date) || !decimal(day.units) || typeof day.eligible !== 'boolean'
        || typeof day.is_weekly_rest !== 'boolean' || (day.holiday_name !== null && typeof day.holiday_name !== 'string')
        || !['paid','unpaid'].includes(String(day.pay_effect)) || !['tracked','untracked'].includes(String(day.balance_mode))
        || (day.halfday_state !== null && typeof day.halfday_state !== 'string')) return failed('response');
    }
    if (balance.state === 'shown' && (!decimal(balance.available_days) || !decimal(balance.shortfall_days)
      || (balance.after_approval_days !== null && !decimal(balance.after_approval_days)) || !Array.isArray(balance.accounts)
      || balance.accounts.some(account => !isObject(account) || typeof account.period_label !== 'string'
        || typeof account.starts_on !== 'string' || !isDate(account.starts_on)
        || typeof account.ends_on !== 'string' || !isDate(account.ends_on) || !decimal(account.balance_days)))) return failed('response');
    // The checked RPC shape contains display facts only, never a write token or approval authority.
    return { signature, impact: data as unknown as LeaveImpactResult['impact'] };
  } catch { return failed('connection'); }
}
