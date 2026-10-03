'use client';

import { useActionState, useRef, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import {
  acceptCancellationAction,
  decideRequestAction,
  approveRequestAction,
  refreshRequestAction,
  rejectCancellationAction,
  rejectRequestAction,
  requestCancellationAction,
  replaceApprovedRequestAction,
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
  replacement: replaceApprovedRequestAction,
  'cancellation-request': requestCancellationAction,
  'cancellation-accept': acceptCancellationAction,
  'cancellation-reject': rejectCancellationAction,
};

const REASON_LABEL: Record<ReviewIntent, string> = {
  refresh: 'سبب تحديث المعاينة',
  approve: 'سبب الاعتماد',
  reject: 'سبب الرفض',
  replacement: 'سبب استبدال الإجازة',
  'cancellation-request': 'سبب طلب إلغاء الاعتماد',
  'cancellation-accept': 'سبب قبول طلب الإلغاء',
  'cancellation-reject': 'سبب رفض طلب الإلغاء',
};

const KEY_NOTE = 'إذا تعذر تأكيد النتيجة، أعد المحاولة بنفس البيانات أو حدّث الصفحة للتحقق من الحالة.';

export function ReviewIntentForm(props: Parameters<typeof IntentForm>[0]) {
  const identity = [props.intent, props.requestId, props.expectedVersion,
    props.reviewedPreviewVersion, props.cancellationId, props.cancellationVersion,
    props.replacementId, props.replacementVersion, props.replacementPreviewVersion].join(':');
  return <IntentForm key={identity} {...props} />;
}

function IntentForm({
  intent: initialIntent,
  decision = false,
  canApprove = true,
  tenantId,
  requestId,
  expectedVersion,
  reviewedPreviewVersion,
  cancellationId,
  cancellationVersion,
  replacementId,
  replacementVersion,
  replacementPreviewVersion,
  submitLabel,
  pendingLabel,
  buttonClass = 'primary-button',
  backHref,
  hint,
}: {
  intent: ReviewIntent;
  decision?: boolean;
  canApprove?: boolean;
  tenantId: string;
  requestId: string;
  expectedVersion: number;
  reviewedPreviewVersion?: number;
  cancellationId?: string;
  cancellationVersion?: number;
  replacementId?: string;
  replacementVersion?: number;
  replacementPreviewVersion?: number;
  submitLabel: string;
  pendingLabel: string;
  buttonClass?: string;
  backHref?: string;
  hint: string;
}) {
  const [intent, setIntent] = useState(initialIntent);
  const [state, action, pending] = useActionState(decision ? decideRequestAction : ACTION_BY_INTENT[intent], EMPTY_REVIEW_STATE);
  const [reason, setReason] = useState('');
  const [historicalAddition, setHistoricalAddition] = useState(false);
  const [operationKey, setOperationKey] = useState(() => newKey());
  const keysRef = useRef<Map<string, string> | null>(null);
  if (keysRef.current === null) keysRef.current = new Map([[signature(''), operationKey]]);
  const reasonId = `review-reason-${intent}`;

  function signature(value: string, selectedIntent = intent, historical = historicalAddition): string {
    return [
      selectedIntent,
      requestId,
      expectedVersion,
      reviewedPreviewVersion ?? '',
      cancellationId ?? '',
      cancellationVersion ?? '',
      replacementId ?? '', replacementVersion ?? '', replacementPreviewVersion ?? '',
      value.trim(),
      selectedIntent === 'approve' && historical ? 'historical-payroll-correction' : '',
    ].join('|');
  }

  function handleReasonChange(value: string, selectedIntent = intent, historical = historicalAddition) {
    setReason(value);
    const key = signature(value, selectedIntent, historical);
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
    {replacementId && <>
      <input type="hidden" name="replacementId" value={replacementId} />
      <input type="hidden" name="replacementVersion" value={replacementVersion} />
      <input type="hidden" name="replacementPreviewVersion" value={replacementPreviewVersion} />
    </>}

    {decision && <><label htmlFor="leave-request-decision">قرار الطلب</label>
      <select id="leave-request-decision" name="decision" value={intent} disabled={pending} onChange={(event) => {
        const selectedIntent = event.target.value === 'approve' ? 'approve' : 'reject';
        setIntent(selectedIntent);
        handleReasonChange(reason, selectedIntent);
      }}>
        {canApprove && <option value="approve">اعتماد الطلب</option>}
        <option value="reject">رفض الطلب</option>
      </select></>}
    <label htmlFor={reasonId}>{decision ? 'سبب القرار' : REASON_LABEL[intent]}</label>
    <textarea id={reasonId} name="reason" required minLength={MIN_REASON_LENGTH} maxLength={MAX_REASON_LENGTH}
      value={reason} onChange={(event) => handleReasonChange(event.target.value)} disabled={pending}
      aria-invalid={Boolean(state.error)} aria-describedby={`${reasonId}-hint`} />
    <p id={`${reasonId}-hint`} className="field-hint">{hint} {KEY_NOTE}</p>
    {intent === 'approve' && <label>
      <input type="checkbox" name="historicalPayrollCorrection" checked={historicalAddition} disabled={pending}
        onChange={(event) => {
          const selected = event.target.checked;
          setHistoricalAddition(selected);
          handleReasonChange(reason, intent, selected);
        }} />
      إضافة تاريخية بعد إقفال الرواتب
      <span className="field-hint">ينشئ الاعتماد مسؤولية تصحيح لكل مسير متأثر. أكملها من تصحيحات الرواتب؛ لا تتغير مبالغ المسير المقفل تلقائيًا.</span>
    </label>}

    {state.error && <p key={state.attempt} className="form-message form-error" role="alert">{state.error}</p>}
    {pending && <p className="field-hint" role="status">جارٍ التنفيذ… لا تغلق الصفحة.</p>}

    <div className="workspace-form-actions">
      <SubmitButton className={decision && intent === 'reject' ? 'danger-button' : buttonClass}
        label={decision ? intent === 'approve' ? 'اعتماد الطلب' : 'رفض الطلب' : submitLabel}
        pendingLabel={decision ? 'جارٍ حفظ القرار…' : pendingLabel} />
      {backHref && (pending ? <span className="secondary-button" aria-disabled="true">إلغاء</span>
        : <PendingLink className="secondary-button" href={backHref}>إلغاء</PendingLink>)}
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
