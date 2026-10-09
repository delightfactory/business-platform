'use client';
import { Message } from '@/components/ui';
import { ButtonLink, Input } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState } from 'react';
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
    <Input id="member-email" name="email" type="email" autoComplete="email" required maxLength={254} autoFocus defaultValue={state.email} aria-invalid={Boolean(state.error)} aria-describedby={state.error ? 'member-invite-error' : undefined} />
    <p className="field-hint">سيدخل بدور «عضو». يمكنك تعديل دوره بعد قبوله الدعوة.</p>
    {state.error && <Message tone="bad" id="member-invite-error"  role="alert">{state.error}</Message>}
    <div className="workspace-form-actions"><SubmitButton label="إرسال الدعوة" pendingLabel="جارٍ الإرسال…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
      <ButtonLink variant="ghost"  href={employeeId ? `/tenant/${tenantId}/people/${employeeId}` : `/tenant/${tenantId}/users`}>إلغاء</ButtonLink></div>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
