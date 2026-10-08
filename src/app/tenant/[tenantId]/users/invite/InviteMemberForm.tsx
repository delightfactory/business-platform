'use client';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState } from 'react';
import Link from 'next/link';
import { SubmitButton } from '@/components/submit-button';
import { inviteMemberFormAction, type InviteMemberState } from '../actions';

export function InviteMemberForm({ tenantId, employeeId, idempotencyKey }: { tenantId: string; employeeId?: string; idempotencyKey: string }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const initial: InviteMemberState = { email: '', idempotencyKey, error: '', attempt: 0 };
  const [state, action, actionPending] = useActionState(inviteMemberFormAction, initial);
  const showOffline0 = offline && !actionPending;
  return <form key={state.attempt} className="auth-form compact-form" action={action} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    {employeeId && <input type="hidden" name="employeeId" value={employeeId} />}
    <label htmlFor="member-email">البريد الإلكتروني</label>
    <input id="member-email" name="email" type="email" autoComplete="email" required maxLength={254} autoFocus defaultValue={state.email} aria-invalid={Boolean(state.error)} aria-describedby={state.error ? 'member-invite-error' : undefined} />
    <p className="field-hint">سيدخل بدور «عضو». يمكنك تعديل دوره بعد قبوله الدعوة.</p>
    {state.error && <p id="member-invite-error" className="form-message error-message" role="alert">{state.error}</p>}
    <div className="workspace-form-actions"><SubmitButton label="إرسال الدعوة" pendingLabel="جارٍ الإرسال…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
      <Link className="secondary-button" href={employeeId ? `/tenant/${tenantId}/people/${employeeId}` : `/tenant/${tenantId}/users`}>إلغاء</Link></div>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
