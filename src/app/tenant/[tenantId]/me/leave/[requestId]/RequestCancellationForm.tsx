'use client';

import styles from '../leave.module.css';

import { useActionState, useState, type ChangeEvent } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { newOperationKey } from '../operation-key';
import { PendingLink } from '../pending-link';
import { requestLeaveCancellationAction } from './cancellation-actions';
import type { RequestCancellationState } from './cancellation-rules';

export function RequestCancellationForm({ tenantId, requestId, expectedVersion, idempotencyKey }: {
  tenantId: string;
  requestId: string;
  expectedVersion: number;
  idempotencyKey: string;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [operationKey, setOperationKey] = useState(idempotencyKey);
  const [reason, setReason] = useState('');
  const [submitState, action, pending] = useActionState<RequestCancellationState, FormData>(
    requestLeaveCancellationAction, { error: '', attempt: 0 });

  function handleReasonChange(event: ChangeEvent<HTMLTextAreaElement>) {
    setReason(event.target.value);
    setOperationKey(newOperationKey());
  }

  const showOfflineNotice = offline && !pending;

  return <form className="auth-form compact-form" action={action} aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="requestId" value={requestId} />
    <input type="hidden" name="expectedVersion" value={expectedVersion} />
    <input type="hidden" name="idempotencyKey" value={operationKey} />
    <label htmlFor="cancellation-reason">سبب طلب الإلغاء</label>
    <textarea id="cancellation-reason" name="reason" required minLength={3} maxLength={500}
      value={reason} onChange={handleReasonChange} disabled={pending}
      aria-invalid={Boolean(submitState.error)} aria-describedby="cancellation-reason-hint" />
    <p id="cancellation-reason-hint" className="field-hint">وضح السبب في 3 إلى 500 حرف. يبقى طلب الإجازة معتمدًا حتى قرار الموارد البشرية.</p>
    {submitState.error && <p key={submitState.attempt} className="form-message form-error" role="alert">{submitState.error}</p>}
    {pending && <p className="field-hint" role="status">جارٍ إرسال طلب الإلغاء… لا تغلق الصفحة ولا تغيّر السبب.</p>}
    <div className="workspace-form-actions">
      <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label="إرسال طلب الإلغاء" pendingLabel="جارٍ الإرسال…" />
      {pending ? <span className={`secondary-button ${styles.disabledAction}`} aria-disabled="true">إغلاق</span>
        : <PendingLink className="secondary-button" href={`/tenant/${tenantId}/me/leave/${requestId}`}>إغلاق</PendingLink>}
    </div>
    {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
  </form>;
}
