'use client';
import { ButtonLink, Input } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { createSiteFormAction, type NewSiteState } from '../../../actions';

export function NewSiteForm({ tenantId, entityId }: { tenantId: string; entityId: string }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const initial: NewSiteState = { displayName: '', reason: '', error: '', attempt: 0 };
  const [state, action, actionPending] = useActionState(createSiteFormAction, initial);
  const showOffline0 = offline && !actionPending;
  return <form key={state.attempt} action={action} className="auth-form compact-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="legalEntityId" value={entityId} />
    <label htmlFor="site-name">اسم الفرع أو الموقع</label>
    <Input id="site-name" name="displayName" required maxLength={160} autoFocus defaultValue={state.displayName} />
    <label htmlFor="site-create-reason">سبب الإضافة</label>
    <Input id="site-create-reason" name="reason" required minLength={3} maxLength={500} defaultValue={state.reason} />
    {state.error && <p className="form-message error-message" role="alert">{state.error}</p>}
    <div className="workspace-form-actions"><SubmitButton label="إضافة الفرع" pendingLabel="جارٍ الإضافة…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
      <ButtonLink variant="ghost" className="secondary-button" href={`/tenant/${tenantId}/entities-sites/${entityId}`}>إلغاء</ButtonLink></div>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
