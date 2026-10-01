'use server';

import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject, isUuid } from '../rules';
import {
  MAX_REASON,
  MAX_SOURCE_LENGTH,
  MIN_REASON,
  MIN_SOURCE_LENGTH,
  deltaErrorText,
  isPostingKind,
  mapPostError,
  normalizeDelta,
  postErrorText,
  readBalanceAccess,
  type PostBalanceState,
  type PostErrorCode,
} from './rules';

// The form payload is untrusted. Authentication, leave_balance.adjust authorization and the
// new-work availability gate are re-established on the server before public.leave_post_balance
// is invoked; that command stays authoritative for replay, policy version, scope, occupancy
// and underflow, so no read result is used here as an authorization shortcut.
export async function postBalanceAction(previous: PostBalanceState, formData: FormData): Promise<PostBalanceState> {
  const tenantId = field(formData, 'tenantId');
  const employeeId = field(formData, 'employee');
  const employerId = field(formData, 'employer');
  const kind = field(formData, 'kind');
  const periodId = field(formData, 'period');
  const typeId = field(formData, 'type');
  const typeVersionId = field(formData, 'typeVersion');
  const delta = field(formData, 'delta');
  const reason = field(formData, 'reason');
  const source = field(formData, 'source');
  const operationKey = field(formData, 'operationKey');
  const recovering = field(formData, 'recovering') === 'true';

  const failed = (code: PostErrorCode, detail?: string): PostBalanceState => ({
    uncertain: recovering || code === 'unknown' || code === 'failed',
    error: detail ?? postErrorText(code),
    attempt: previous.attempt + 1,
    accountId: null,
    entryId: null,
    replay: false,
  });

  if (!isUuid(tenantId) || !isUuid(employeeId) || !isUuid(employerId) || !isUuid(periodId)
    || !isUuid(typeId) || !isUuid(typeVersionId) || !isUuid(operationKey)) return failed('input');
  if (!isPostingKind(kind)) return failed('input');

  const trimmedReason = reason.trim();
  if (trimmedReason.length < MIN_REASON || trimmedReason.length > MAX_REASON) return failed('reason');
  const trimmedSource = source.trim();
  if (trimmedSource.length < MIN_SOURCE_LENGTH || trimmedSource.length > MAX_SOURCE_LENGTH) {
    return failed('source');
  }

  const normalized = normalizeDelta(delta, kind);
  if (!normalized.ok) return failed('delta', `${deltaErrorText(normalized.reason)} لم يُرسل أي قيد.`);

  const supabase = await createSupabaseServerClient();
  if (!supabase) return failed('setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return failed('session');

  const accessResult = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  const access = accessResult.error ? null : readBalanceAccess(accessResult.data);
  if (!access) return failed(accessResult.error?.code === '42501' ? 'forbidden' : 'access');
  if (!access.canAdjust) return failed('forbidden');
  if (!access.newWorkEnabled) return failed('new-work-disabled');

  const { data, error } = await supabase.rpc('leave_post_balance', {
    p_tenant: tenantId,
    p_employee: employeeId,
    p_employer: employerId,
    p_type: typeId,
    p_period: periodId,
    p_kind: kind,
    p_delta: normalized.value,
    p_type_version: typeVersionId,
    p_key: operationKey,
    p_source: trimmedSource,
    p_reason: trimmedReason,
  });
  if (error) return failed(mapPostError(error.message, error.code));

  const accountId = isObject(data) && isUuid(data.account_id) ? data.account_id : null;
  const entryId = isObject(data) && isUuid(data.entry_id) ? data.entry_id : null;
  if (!accountId || !entryId) return failed('unknown');

  return {
    uncertain: false,
    error: '',
    attempt: previous.attempt + 1,
    accountId,
    entryId,
    replay: isObject(data) && data.state === 'replay',
  };
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}
