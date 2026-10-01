'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import {
  MAX_CODE_LENGTH,
  MAX_LABEL_LENGTH,
  MAX_NAME_LENGTH,
  MAX_REASON_LENGTH,
  MAX_SOURCE_LENGTH,
  MIN_REASON_LENGTH,
  type ActivationState,
  type CreateCalendarState,
  type CreateTypeState,
  type CreateYearPeriodState,
  type ReviseCalendarState,
  type ReviseTypeState,
  cairoToday,
  configErrorText,
  holidaysProblem,
  isBalanceMode,
  isDate,
  isDayCountBasis,
  isPayEffect,
  isUuid,
  mapConfigError,
  parseRestDays,
  readHolidayRows,
} from './rules';

export async function createCalendarAction(
  previous: CreateCalendarState,
  formData: FormData,
): Promise<CreateCalendarState> {
  const tenantId = field(formData, 'tenantId');
  const employerId = field(formData, 'employerId');
  const code = field(formData, 'code');
  const name = field(formData, 'name');
  const effectiveFrom = field(formData, 'effectiveFrom');
  const effectiveUntil = field(formData, 'effectiveUntil');
  const source = field(formData, 'source');
  const reason = field(formData, 'reason');
  const restDays = parseRestDays(formData.getAll('restDay'));
  const holidays = readHolidayRows(formData);
  const state = (): CreateCalendarState => ({
    code, name, effectiveFrom, effectiveUntil,
    restDays: restDays ?? [], holidays, source, reason, error: '', attempt: previous.attempt + 1,
  });
  const fail = (code_: string): CreateCalendarState => ({
    ...state(), error: configErrorText('calendar-create', code_),
  });
  if (!isUuid(tenantId) || !isUuid(employerId)) return fail('invalid');
  if (!code || code.length > MAX_CODE_LENGTH || !name || name.length > MAX_NAME_LENGTH) return fail('calendar-input');
  if (!isDate(effectiveFrom) || (effectiveUntil !== '' && (!isDate(effectiveUntil) || effectiveUntil <= effectiveFrom))) {
    return fail('range');
  }
  if (restDays === null) return fail('calendar-input');
  const holidayIssue = holidaysProblem(holidays, effectiveFrom, effectiveUntil);
  if (holidayIssue) return fail(holidayIssue === 'duplicate-date' ? 'duplicate-date' : 'calendar-input');
  if (!source || source.length > MAX_SOURCE_LENGTH) return fail('source');
  if (reason.length < MIN_REASON_LENGTH || reason.length > MAX_REASON_LENGTH) return fail('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('session');
  const { data, error } = await supabase.rpc('leave_create_calendar', {
    p_tenant: tenantId,
    p_employer: employerId,
    p_code: code,
    p_name: name,
    p_effective_from: effectiveFrom,
    p_effective_until: effectiveUntil === '' ? null : effectiveUntil,
    p_rest_days: restDays,
    p_holidays: holidays.filter((row) => row.date !== '' && row.name !== ''),
    p_source: source,
    p_reason: reason,
  });
  if (error) return fail(mapConfigError(error.message, error.code));
  if (!isUuid(data)) return fail('unknown');
  redirect(`/tenant/${tenantId}/leave/settings/${employerId}?state=calendar-created`);
}

export async function reviseCalendarAction(
  previous: ReviseCalendarState,
  formData: FormData,
): Promise<ReviseCalendarState> {
  const tenantId = field(formData, 'tenantId');
  const employerId = field(formData, 'employerId');
  const calendarId = field(formData, 'calendarId');
  const effectiveFrom = field(formData, 'effectiveFrom');
  const effectiveUntil = field(formData, 'effectiveUntil');
  const source = field(formData, 'source');
  const reason = field(formData, 'reason');
  const restDays = parseRestDays(formData.getAll('restDay'));
  const holidays = readHolidayRows(formData);
  const state = (): ReviseCalendarState => ({
    effectiveFrom, effectiveUntil, restDays: restDays ?? [], holidays, source, reason,
    error: '', attempt: previous.attempt + 1,
  });
  const fail = (code_: string): ReviseCalendarState => ({
    ...state(), error: configErrorText('calendar-revise', code_),
  });
  if (!isUuid(tenantId) || !isUuid(employerId) || !isUuid(calendarId)) return fail('invalid');
  if (!isDate(effectiveFrom) || (effectiveUntil !== '' && (!isDate(effectiveUntil) || effectiveUntil <= effectiveFrom))) {
    return fail('range');
  }
  if (effectiveFrom <= cairoToday()) return fail('future');
  if (restDays === null) return fail('calendar-input');
  const holidayIssue = holidaysProblem(holidays, effectiveFrom, effectiveUntil);
  if (holidayIssue) return fail(holidayIssue === 'duplicate-date' ? 'duplicate-date' : 'calendar-input');
  if (!source || source.length > MAX_SOURCE_LENGTH) return fail('source');
  if (reason.length < MIN_REASON_LENGTH || reason.length > MAX_REASON_LENGTH) return fail('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('session');
  const { data, error } = await supabase.rpc('leave_revise_calendar', {
    p_tenant: tenantId,
    p_calendar: calendarId,
    p_effective_from: effectiveFrom,
    p_effective_until: effectiveUntil === '' ? null : effectiveUntil,
    p_rest_days: restDays,
    p_holidays: holidays.filter((row) => row.date !== '' && row.name !== ''),
    p_source: source,
    p_reason: reason,
  });
  if (error) return fail(mapConfigError(error.message, error.code));
  if (!isUuid(data)) return fail('unknown');
  redirect(`/tenant/${tenantId}/leave/settings/${employerId}/calendars/${calendarId}?state=revision-created`);
}

export async function createYearPeriodAction(
  previous: CreateYearPeriodState,
  formData: FormData,
): Promise<CreateYearPeriodState> {
  const tenantId = field(formData, 'tenantId');
  const employerId = field(formData, 'employerId');
  const calendarId = field(formData, 'calendarId');
  const startsOn = field(formData, 'startsOn');
  const endsOn = field(formData, 'endsOn');
  const label = field(formData, 'label');
  const reason = field(formData, 'reason');
  const state = (): CreateYearPeriodState => ({
    calendarId, startsOn, endsOn, label, reason, error: '', attempt: previous.attempt + 1,
  });
  const fail = (code_: string): CreateYearPeriodState => ({
    ...state(), error: configErrorText('period-create', code_),
  });
  if (!isUuid(tenantId) || !isUuid(employerId)) return fail('invalid');
  if (!isUuid(calendarId)) return fail('period-input');
  if (!isDate(startsOn) || !isDate(endsOn) || endsOn < startsOn) return fail('range');
  if (!label || label.length > MAX_LABEL_LENGTH) return fail('label');
  if (reason.length < MIN_REASON_LENGTH || reason.length > MAX_REASON_LENGTH) return fail('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('session');
  const { data, error } = await supabase.rpc('leave_create_year_period', {
    p_tenant: tenantId,
    p_employer: employerId,
    p_calendar: calendarId,
    p_starts: startsOn,
    p_ends: endsOn,
    p_label: label,
    p_reason: reason,
  });
  if (error) return fail(mapConfigError(error.message, error.code));
  if (!isUuid(data)) return fail('unknown');
  redirect(`/tenant/${tenantId}/leave/settings/${employerId}?state=year-created`);
}

export async function createTypeAction(
  previous: CreateTypeState,
  formData: FormData,
): Promise<CreateTypeState> {
  const tenantId = field(formData, 'tenantId');
  const employerId = field(formData, 'employerId');
  const code = field(formData, 'code');
  const name = field(formData, 'name');
  const effectiveFrom = field(formData, 'effectiveFrom');
  const payEffect = field(formData, 'payEffect');
  const balanceMode = field(formData, 'balanceMode');
  const dayCountBasis = field(formData, 'dayCountBasis');
  const halfDayRaw = field(formData, 'halfDay');
  const halfDay = halfDayRaw === 'true';
  const source = field(formData, 'source');
  const reason = field(formData, 'reason');
  const state = (): CreateTypeState => ({
    code, name, effectiveFrom,
    payEffect: isPayEffect(payEffect) ? payEffect : 'paid',
    balanceMode: isBalanceMode(balanceMode) ? balanceMode : 'tracked',
    dayCountBasis: isDayCountBasis(dayCountBasis) ? dayCountBasis : 'working_days',
    halfDay,
    source, reason, error: '', attempt: previous.attempt + 1,
  });
  const fail = (code_: string): CreateTypeState => ({
    ...state(), error: configErrorText('type-create', code_),
  });
  if (!isUuid(tenantId) || !isUuid(employerId)) return fail('invalid');
  if (!code || code.length > MAX_CODE_LENGTH || !name || name.length > MAX_NAME_LENGTH) return fail('type-input');
  if (!isDate(effectiveFrom)) return fail('type-input');
  if (!isPayEffect(payEffect) || !isBalanceMode(balanceMode) || !isDayCountBasis(dayCountBasis)
    || (halfDayRaw !== '' && halfDayRaw !== 'true' && halfDayRaw !== 'false')) return fail('type-input');
  if (!source || source.length > MAX_SOURCE_LENGTH) return fail('source');
  if (reason.length < MIN_REASON_LENGTH || reason.length > MAX_REASON_LENGTH) return fail('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('session');
  const { data, error } = await supabase.rpc('leave_create_type', {
    p_tenant: tenantId,
    p_employer: employerId,
    p_code: code,
    p_name: name,
    p_effective_from: effectiveFrom,
    p_pay_effect: payEffect,
    p_balance_mode: balanceMode,
    p_half: halfDay,
    p_source: source,
    p_reason: reason,
    p_day_count_basis: dayCountBasis,
  });
  if (error) return fail(mapConfigError(error.message, error.code));
  if (!isUuid(data)) return fail('unknown');
  redirect(`/tenant/${tenantId}/leave/settings/${employerId}?state=type-created`);
}

export async function reviseTypeAction(
  previous: ReviseTypeState,
  formData: FormData,
): Promise<ReviseTypeState> {
  const tenantId = field(formData, 'tenantId');
  const employerId = field(formData, 'employerId');
  const typeId = field(formData, 'typeId');
  const effectiveFrom = field(formData, 'effectiveFrom');
  const payEffect = field(formData, 'payEffect');
  const balanceMode = field(formData, 'balanceMode');
  const dayCountBasis = field(formData, 'dayCountBasis');
  const halfDayRaw = field(formData, 'halfDay');
  const halfDay = halfDayRaw === 'true';
  const source = field(formData, 'source');
  const reason = field(formData, 'reason');
  const state = (): ReviseTypeState => ({
    effectiveFrom,
    payEffect: isPayEffect(payEffect) ? payEffect : 'paid',
    balanceMode: isBalanceMode(balanceMode) ? balanceMode : 'tracked',
    dayCountBasis: isDayCountBasis(dayCountBasis) ? dayCountBasis : 'working_days',
    halfDay,
    source, reason, error: '', attempt: previous.attempt + 1,
  });
  const fail = (code_: string): ReviseTypeState => ({
    ...state(), error: configErrorText('type-revise', code_),
  });
  if (!isUuid(tenantId) || !isUuid(employerId) || !isUuid(typeId)) return fail('invalid');
  if (!isDate(effectiveFrom)) return fail('type-input');
  if (effectiveFrom <= cairoToday()) return fail('future');
  if (!isPayEffect(payEffect) || !isBalanceMode(balanceMode) || !isDayCountBasis(dayCountBasis)
    || (halfDayRaw !== '' && halfDayRaw !== 'true' && halfDayRaw !== 'false')) return fail('type-input');
  if (!source || source.length > MAX_SOURCE_LENGTH) return fail('source');
  if (reason.length < MIN_REASON_LENGTH || reason.length > MAX_REASON_LENGTH) return fail('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('session');
  const { data, error } = await supabase.rpc('leave_revise_type', {
    p_tenant: tenantId,
    p_type: typeId,
    p_effective_from: effectiveFrom,
    p_pay_effect: payEffect,
    p_balance_mode: balanceMode,
    p_day_count_basis: dayCountBasis,
    p_half: halfDay,
    p_source: source,
    p_reason: reason,
  });
  if (error) return fail(mapConfigError(error.message, error.code));
  if (!isUuid(data)) return fail('unknown');
  redirect(`/tenant/${tenantId}/leave/settings/${employerId}/types/${typeId}?state=revision-created`);
}

export async function setTypeActiveAction(
  previous: ActivationState,
  formData: FormData,
): Promise<ActivationState> {
  const tenantId = field(formData, 'tenantId');
  const employerId = field(formData, 'employerId');
  const typeId = field(formData, 'typeId');
  const isActive = field(formData, 'isActive');
  const reason = field(formData, 'reason');
  const operationKey = field(formData, 'operationKey');
  const state = (): ActivationState => ({ reason, error: '', attempt: previous.attempt + 1 });
  const fail = (code_: string): ActivationState => ({
    ...state(), error: configErrorText('type-activate', code_),
  });
  if (!isUuid(tenantId) || !isUuid(employerId) || !isUuid(typeId)) return fail('invalid');
  if (isActive !== 'true' && isActive !== 'false') return fail('invalid');
  if (reason.length < MIN_REASON_LENGTH || reason.length > MAX_REASON_LENGTH) return fail('reason');
  if (operationKey.length < 1 || operationKey.length > 120) return fail('invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('session');
  const { data, error } = await supabase.rpc('leave_set_type_active', {
    p_tenant: tenantId,
    p_type: typeId,
    p_is_active: isActive === 'true',
    p_reason: reason,
    p_idempotency_key: operationKey,
  });
  if (error) return fail(mapConfigError(error.message, error.code));
  if (!isObjectResult(data)) return fail('unknown');
  const result = data as Record<string, unknown>;
  const resultingActive = result.is_active === true;
  const resultingState = result.state === 'unchanged' ? 'unchanged' : 'updated';
  if (resultingState === 'unchanged') {
    redirect(`/tenant/${tenantId}/leave/settings/${employerId}/types/${typeId}?state=type-unchanged`);
  }
  redirect(`/tenant/${tenantId}/leave/settings/${employerId}/types/${typeId}?state=${resultingActive ? 'type-activated' : 'type-deactivated'}`);
}

function isObjectResult(value: unknown): boolean {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}
