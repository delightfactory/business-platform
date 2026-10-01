'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject, isUuid } from '../form-rules';
import { cancellationErrorText, mapCancellationError, type RequestCancellationState } from './cancellation-rules';

export async function requestLeaveCancellationAction(
  previous: RequestCancellationState,
  formData: FormData,
): Promise<RequestCancellationState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const versionText = field(formData, 'expectedVersion');
  const reason = field(formData, 'reason');
  const idempotencyKey = field(formData, 'idempotencyKey');
  const failed = (code: string): RequestCancellationState => ({ error: cancellationErrorText(code), attempt: previous.attempt + 1 });
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
  const { data, error } = await supabase.rpc('leave_my_request_cancellation', {
    p_tenant: tenantId,
    p_request: requestId,
    p_expected_version: expectedVersion,
    p_reason: trimmedReason,
    p_idempotency_key: idempotencyKey,
  });
  if (error) return failed(mapCancellationError(error.message, error.code));
  if (!isObject(data) || data.state !== 'pending') return failed('unknown');
  redirect(`/tenant/${tenantId}/me/leave/${requestId}?state=cancellation-requested`);
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}
