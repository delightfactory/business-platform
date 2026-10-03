'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import {
  MAX_REASON_LENGTH,
  MIN_REASON_LENGTH,
  detailStateHref,
  isInteger,
  isObject,
  isUuid,
  mapReviewError,
  readAccess,
  reviewErrorText,
  type LeaveAccess,
  type ReviewActionState,
} from './rules';

type ServerClient = NonNullable<Awaited<ReturnType<typeof createSupabaseServerClient>>>;

export async function decideRequestAction(previous: ReviewActionState, formData: FormData): Promise<ReviewActionState> {
  const decision = field(formData, 'decision');
  if (decision === 'approve') return approveRequestAction(previous, formData);
  if (decision === 'reject') return rejectRequestAction(previous, formData);
  return { error: 'اختر اعتماد الطلب أو رفضه.', attempt: previous.attempt + 1 };
}

type Gate =
  | { ok: false; code: string }
  | { ok: true; supabase: ServerClient; access: LeaveAccess };

type Need = 'approve' | 'manage';

export async function replaceApprovedRequestAction(previous: ReviewActionState, formData: FormData): Promise<ReviewActionState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const replacementId = field(formData, 'replacementId');
  const operationKey = field(formData, 'operationKey');
  const expectedVersion = parseVersion(field(formData, 'expectedVersion'));
  const reviewedPreviewVersion = parseVersion(field(formData, 'reviewedPreviewVersion'));
  const replacementVersion = parseVersion(field(formData, 'replacementVersion'));
  const replacementPreviewVersion = parseVersion(field(formData, 'replacementPreviewVersion'));
  const reason = reasonOf(formData);
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(replacementId) || requestId === replacementId
    || !isUuid(operationKey) || expectedVersion === null || reviewedPreviewVersion === null
    || replacementVersion === null || replacementPreviewVersion === null) return failed('input', previous.attempt);
  if (reason === null) return failed('reason', previous.attempt);
  const gate = await openGate(tenantId, 'approve');
  if (!gate.ok) return failed(gate.code, previous.attempt);
  if (!gate.access.newWorkEnabled) return failed('new-work-disabled', previous.attempt);
  const { data, error } = await gate.supabase.rpc('leave_correct_approved_request', {
    p_tenant: tenantId, p_original_request: requestId,
    p_original_expected_version: expectedVersion, p_original_preview_version: reviewedPreviewVersion,
    p_replacement_request: replacementId, p_replacement_expected_version: replacementVersion,
    p_replacement_preview_version: replacementPreviewVersion, p_reason: reason, p_idempotency_key: operationKey,
  });
  if (error) return failed(mapReviewError(error.message, error.code), previous.attempt);
  if (!isObject(data)) return failed('unknown', previous.attempt);
  if (data.state === 'refresh_required') return failed('refresh-required', previous.attempt);
  if (data.state !== 'corrected') return failed('unknown', previous.attempt);
  redirect(detailStateHref(tenantId, requestId, 'replaced'));
}

async function openGate(tenantId: string, need: Need): Promise<Gate> {
  if (!isUuid(tenantId)) return { ok: false, code: 'input' };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { ok: false, code: 'setup' };
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { ok: false, code: 'session' };
  const { data, error } = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  if (error) return { ok: false, code: error.code === '42501' ? 'forbidden' : 'failed' };
  const access = readAccess(data);
  if (!access) return { ok: false, code: 'failed' };
  if (need === 'approve' ? !access.canApprove : !access.canManage) return { ok: false, code: 'forbidden' };
  return { ok: true, supabase, access };
}

function failed(code: string, previousAttempt: number): ReviewActionState {
  return { error: reviewErrorText(code as Parameters<typeof reviewErrorText>[0]), attempt: previousAttempt + 1 };
}

function field(formData: FormData, name: string): string {
  return String(formData.get(name) ?? '').trim();
}

function parseVersion(raw: string): number | null {
  if (!/^\d{1,9}$/.test(raw)) return null;
  const value = Number(raw);
  return isInteger(value) && value >= 1 ? value : null;
}

function reasonOf(formData: FormData): string | null {
  const trimmed = field(formData, 'reason');
  if (trimmed.length < MIN_REASON_LENGTH || trimmed.length > MAX_REASON_LENGTH) return null;
  return trimmed;
}

export async function approveRequestAction(
  previous: ReviewActionState,
  formData: FormData,
): Promise<ReviewActionState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const operationKey = field(formData, 'operationKey');
  const expectedVersion = parseVersion(field(formData, 'expectedVersion'));
  const reviewedPreviewVersion = parseVersion(field(formData, 'reviewedPreviewVersion'));
  const reason = reasonOf(formData);
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(operationKey)
    || expectedVersion === null || reviewedPreviewVersion === null) return failed('input', previous.attempt);
  if (reason === null) return failed('reason', previous.attempt);

  const gate = await openGate(tenantId, 'approve');
  if (!gate.ok) return failed(gate.code, previous.attempt);
  if (!gate.access.newWorkEnabled) return failed('new-work-disabled', previous.attempt);

  const historicalAddition = field(formData, 'historicalPayrollCorrection') === 'on';
  const { data, error } = await gate.supabase.rpc(historicalAddition ? 'leave_approve_historical_request' : 'leave_approve_request', {
    p_tenant: tenantId,
    p_request: requestId,
    p_expected_version: expectedVersion,
    p_reviewed_preview_version: reviewedPreviewVersion,
    p_reason: reason,
    p_idempotency_key: operationKey,
  });
  if (error?.message.includes('payroll_locked_leave_addition_requires_correction')) {
    return { error: 'هذه الإجازة تؤثر في مسير مقفل. اختر الإضافة التاريخية لإنشاء مسؤولية تصحيح، ثم أكملها من تصحيحات الرواتب.', attempt: previous.attempt + 1 };
  }
  if (error) return failed(mapReviewError(error.message, error.code), previous.attempt);
  if (!isObject(data)) return failed('unknown', previous.attempt);
  if (data.state === 'refresh_required') return failed('refresh-required', previous.attempt);
  if (data.state !== 'approved') return failed('unknown', previous.attempt);
  redirect(detailStateHref(tenantId, requestId, 'approved') + (historicalAddition ? '&payrollCorrection=required' : ''));
}

export async function rejectRequestAction(
  previous: ReviewActionState,
  formData: FormData,
): Promise<ReviewActionState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const operationKey = field(formData, 'operationKey');
  const expectedVersion = parseVersion(field(formData, 'expectedVersion'));
  const reason = reasonOf(formData);
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(operationKey)
    || expectedVersion === null) return failed('input', previous.attempt);
  if (reason === null) return failed('reason', previous.attempt);

  const gate = await openGate(tenantId, 'approve');
  if (!gate.ok) return failed(gate.code, previous.attempt);

  const { data, error } = await gate.supabase.rpc('leave_reject_request', {
    p_tenant: tenantId,
    p_request: requestId,
    p_expected_version: expectedVersion,
    p_reason: reason,
    p_idempotency_key: operationKey,
  });
  if (error) return failed(mapReviewError(error.message, error.code), previous.attempt);
  if (!isObject(data) || data.state !== 'rejected') return failed('unknown', previous.attempt);
  redirect(detailStateHref(tenantId, requestId, 'rejected'));
}

export async function refreshRequestAction(
  previous: ReviewActionState,
  formData: FormData,
): Promise<ReviewActionState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const operationKey = field(formData, 'operationKey');
  const expectedVersion = parseVersion(field(formData, 'expectedVersion'));
  const reason = reasonOf(formData);
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(operationKey)
    || expectedVersion === null) return failed('input', previous.attempt);
  if (reason === null) return failed('reason', previous.attempt);

  const gate = await openGate(tenantId, 'approve');
  if (!gate.ok) return failed(gate.code, previous.attempt);
  if (!gate.access.newWorkEnabled) return failed('new-work-disabled', previous.attempt);

  const { data, error } = await gate.supabase.rpc('leave_refresh_request_preview', {
    p_tenant: tenantId,
    p_request: requestId,
    p_expected_version: expectedVersion,
    p_reason: reason,
    p_idempotency_key: operationKey,
  });
  if (error) return failed(mapReviewError(error.message, error.code), previous.attempt);
  if (!isObject(data) || data.state !== 'refreshed') return failed('unknown', previous.attempt);
  if (!isObject(data.request) || !isInteger(data.request.version) || !isInteger(data.request.preview_version))
    return failed('unknown', previous.attempt);
  redirect(`${detailStateHref(tenantId, requestId, 'refreshed')}&rv=${data.request.version}&pv=${data.request.preview_version}`);
}

export async function requestCancellationAction(
  previous: ReviewActionState,
  formData: FormData,
): Promise<ReviewActionState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const operationKey = field(formData, 'operationKey');
  const expectedVersion = parseVersion(field(formData, 'expectedVersion'));
  const reason = reasonOf(formData);
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(operationKey)
    || expectedVersion === null) return failed('input', previous.attempt);
  if (reason === null) return failed('reason', previous.attempt);

  const gate = await openGate(tenantId, 'manage');
  if (!gate.ok) return failed(gate.code, previous.attempt);

  const { data, error } = await gate.supabase.rpc('leave_request_cancellation', {
    p_tenant: tenantId,
    p_request: requestId,
    p_expected_version: expectedVersion,
    p_reason: reason,
    p_idempotency_key: operationKey,
  });
  if (error) return failed(mapReviewError(error.message, error.code), previous.attempt);
  if (!isObject(data) || data.state !== 'pending') return failed('unknown', previous.attempt);
  redirect(detailStateHref(tenantId, requestId, 'cancellation-requested'));
}

async function decideCancellation(
  previous: ReviewActionState,
  formData: FormData,
  decision: 'accept' | 'reject',
): Promise<ReviewActionState> {
  const tenantId = field(formData, 'tenantId');
  const requestId = field(formData, 'requestId');
  const cancellationId = field(formData, 'cancellationId');
  const operationKey = field(formData, 'operationKey');
  const expectedVersion = parseVersion(field(formData, 'cancellationVersion'));
  const reason = reasonOf(formData);
  if (!isUuid(tenantId) || !isUuid(requestId) || !isUuid(cancellationId) || !isUuid(operationKey)
    || expectedVersion === null) return failed('input', previous.attempt);
  if (reason === null) return failed('reason', previous.attempt);

  const gate = await openGate(tenantId, 'approve');
  if (!gate.ok) return failed(gate.code, previous.attempt);

  const { data, error } = await gate.supabase.rpc('leave_decide_cancellation', {
    p_tenant: tenantId,
    p_cancellation: cancellationId,
    p_expected_version: expectedVersion,
    p_decision: decision,
    p_reason: reason,
    p_idempotency_key: operationKey,
  });
  if (error) return failed(mapReviewError(error.message, error.code), previous.attempt);
  if (!isObject(data)) return failed('unknown', previous.attempt);
  const expectedState = decision === 'accept' ? 'accepted' : 'rejected';
  if (data.state !== expectedState) return failed('unknown', previous.attempt);
  const needsTime = decision === 'accept' && data.time_reconciliation_required === true;
  const state = decision === 'accept'
    ? (needsTime ? 'cancellation-accepted-time' : 'cancellation-accepted')
    : 'cancellation-rejected';
  redirect(detailStateHref(tenantId, requestId, state));
}

export async function acceptCancellationAction(
  previous: ReviewActionState,
  formData: FormData,
): Promise<ReviewActionState> {
  return decideCancellation(previous, formData, 'accept');
}

export async function rejectCancellationAction(
  previous: ReviewActionState,
  formData: FormData,
): Promise<ReviewActionState> {
  return decideCancellation(previous, formData, 'reject');
}
