'use client';

import { useActionState, useRef, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import {
  acceptCancellationAction,
  approveRequestAction,
  refreshRequestAction,
  rejectCancellationAction,
  rejectRequestAction,
  requestCancellationAction,
} from '../../actions';
import { PendingLink } from '../../pending-link';
import {
  EMPTY_REVIEW_STATE,
  MAX_REASON_LENGTH,
  MIN_REASON_LENGTH,
  type ReviewActionState,
  type ReviewIntent,
} from '../../rules';

type ReviewAction = (previous: ReviewActionState, formData: FormData) => Promise<ReviewActionState>;

const ACTION_BY_INTENT: Record<ReviewIntent, ReviewAction> = {
  refresh: refreshRequestAction,
  approve: approveRequestAction,
  reject: rejectRequestAction,
  'cancellation-request': requestCancellationAction,
  'cancellation-accept': acceptCancellationAction,
  'cancellation-reject': rejectCancellationAction,
};

const REASON_LABEL: Record<ReviewIntent, string> = {
  refresh: 'سبب تحديث المعاينة',
  approve: 'سبب الاعتماد',
  reject: 'سبب الرفض',
  'cancellation-request': 'سبب طلب إلغاء الاعتماد',
  'cancellation-accept': 'سبب قبول طلب الإلغاء',
  'cancellation-reject': 'سبب رفض طلب الإلغاء',
};

const KEY_NOTE = 'المفتاح ثابت لكل بيانات محددة، فتُعاد المحاولة الفاشلة بالنتيجة نفسها دون تكرار.';

export function ReviewIntentForm({
  intent,
  tenantId,
  requestId,
  expectedVersion,
  reviewedPreviewVersion,
  cancellationId,
  cancellationVersion,
  submitLabel,
  pendingLabel,
  buttonClass = 'primary-button',
  backHref,
  hint,
}: {
  intent: ReviewIntent;
  tenantId: string;
  requestId: string;
  expectedVersion: number;
  reviewedPreviewVersion?: number;
  cancellationId?: string;
  cancellationVersion?: number;
  submitLabel: string;
  pendingLabel: string;
  buttonClass?: string;
  backHref?: string;
  hint: string;
}) {
  const [state, action, pending] = useActionState(ACTION_BY_INTENT[intent], EMPTY_REVIEW_STATE);
  const [reason, setReason] = useState('');
  const [operationKey, setOperationKey] = useState(() => newKey());
  const keysRef = useRef<Map<string, string> | null>(null);
  if (keysRef.current === null) keysRef.current = new Map([[signature(''), operationKey]]);
  const reasonId = `review-reason-${intent}`;

  function signature(value: string): string {
    return [
      intent,
      requestId,
      expectedVersion,
      reviewedPreviewVersion ?? '',
      cancellationId ?? '',
      cancellationVersion ?? '',
      value.trim(),
    ].join('|');
  }

  function handleReasonChange(value: string) {
    setReason(value);
    const key = signature(value);
    const keys = keysRef.current ?? new Map<string, string>();
    keysRef.current = keys;
    const existing = keys.get(key);
    if (existing) {
      setOperationKey(existing);
      return;
    }
    const fresh = newKey();
    keys.set(key, fresh);
    setOperationKey(fresh);
  }

  return <form key={state.attempt} action={action} className="auth-form compact-form" aria-busy={pending}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="requestId" value={requestId} />
    <input type="hidden" name="expectedVersion" value={expectedVersion} />
    {reviewedPreviewVersion !== undefined
      && <input type="hidden" name="reviewedPreviewVersion" value={reviewedPreviewVersion} />}
    {cancellationId !== undefined && <input type="hidden" name="cancellationId" value={cancellationId} />}
    {cancellationVersion !== undefined
      && <input type="hidden" name="cancellationVersion" value={cancellationVersion} />}
    <input type="hidden" name="operationKey" value={operationKey} />

    <label htmlFor={reasonId}>{REASON_LABEL[intent]}</label>
    <textarea id={reasonId} name="reason" required minLength={MIN_REASON_LENGTH} maxLength={MAX_REASON_LENGTH}
      value={reason} onChange={(event) => handleReasonChange(event.target.value)} disabled={pending}
      aria-invalid={Boolean(state.error)} aria-describedby={`${reasonId}-hint`} />
    <p id={`${reasonId}-hint`} className="field-hint">{hint} {KEY_NOTE}</p>

    {state.error && <p key={state.attempt} className="form-message form-error" role="alert">{state.error}</p>}
    {pending && <p className="field-hint" role="status">جارٍ التنفيذ… لا تغلق الصفحة.</p>}

    <div className="workspace-form-actions">
      <SubmitButton className={buttonClass} label={submitLabel} pendingLabel={pendingLabel} />
      {backHref && <PendingLink className="secondary-button" href={backHref}>إلغاء</PendingLink>}
    </div>
  </form>;
}

function newKey(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  let hex = '';
  for (let index = 0; index < 32; index += 1) hex += Math.floor(Math.random() * 16).toString(16);
  const variant = ['8', '9', 'a', 'b'][Math.floor(Math.random() * 4)];
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-${variant}${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}
