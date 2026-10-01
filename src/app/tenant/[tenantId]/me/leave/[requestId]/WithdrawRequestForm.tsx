'use client';

import { useActionState, useState, type ChangeEvent } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { withdrawLeaveRequestAction } from '../actions';
import { newOperationKey } from '../operation-key';
import { PendingLink } from '../pending-link';

export function WithdrawRequestForm({ tenantId, requestId, expectedVersion, idempotencyKey }: {
  tenantId: string;
  requestId: string;
  expectedVersion: number;
  idempotencyKey: string;
}) {
  const [operationKey, setOperationKey] = useState(idempotencyKey);
  const [reason, setReason] = useState('');
  const [submitState, action, pending] = useActionState(withdrawLeaveRequestAction, { error: '', attempt: 0 });

  function handleReasonChange(event: ChangeEvent<HTMLTextAreaElement>) {
    setReason(event.target.value);
    setOperationKey(newOperationKey());
  }

  return <form className="auth-form compact-form" action={action} aria-busy={pending}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="requestId" value={requestId} />
    <input type="hidden" name="expectedVersion" value={expectedVersion} />
    <input type="hidden" name="idempotencyKey" value={operationKey} />
    <label htmlFor="withdraw-reason">سبب السحب</label>
    <textarea id="withdraw-reason" name="reason" required minLength={3} maxLength={500}
      value={reason} onChange={handleReasonChange} disabled={pending} aria-invalid={Boolean(submitState.error)}
      aria-describedby="withdraw-reason-hint" />
    <p id="withdraw-reason-hint" className="field-hint">من 3 إلى 500 حرف. يُحفظ السبب في سجل العملية مع هويتك ووقتها.</p>
    {submitState.error && <p key={submitState.attempt} className="form-message form-error" role="alert">{submitState.error}</p>}
    <div className="workspace-form-actions">
      <SubmitButton className="danger-button" label="سحب الطلب" pendingLabel="جارٍ السحب…" />
      <PendingLink className="secondary-button" href={`/tenant/${tenantId}/me/leave/${requestId}`}>إلغاء</PendingLink>
    </div>
  </form>;
}
