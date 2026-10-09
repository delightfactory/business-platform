'use client';
import { Message } from '@/components/ui';
import { Input } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { legalEntityFormAction, siteFormAction, type RecordActionState } from '../actions';

type Action = 'update' | 'default' | 'deactivate' | 'reactivate';
type Props = {
  tenantId: string; entityId: string; action: Action; siteId?: string;
  displayName?: string; legalName?: string; label: string;
};

export function RecordActionForm({ tenantId, entityId, siteId, action: recordAction, displayName = '', legalName = '', label }: Props) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const initial: RecordActionState = { displayName, legalName, reason: '', error: '', attempt: 0 };
  const [state, action, actionPending] = useActionState(siteId ? siteFormAction : legalEntityFormAction, initial);
  const isSite = Boolean(siteId);
  const prefix = `${isSite ? 'site' : 'entity'}-${recordAction}-${siteId ?? entityId}`;
  const reasonLabel = recordAction === 'deactivate' ? 'سبب التعطيل' : recordAction === 'reactivate' ? 'سبب إعادة التفعيل'
    : recordAction === 'default' ? 'سبب تغيير الاختيار الأساسي' : 'سبب التعديل';
  const showOffline0 = offline && !actionPending;
  return <form key={state.attempt} action={action} className="auth-form compact-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name={isSite ? 'siteId' : 'entityId'} value={siteId ?? entityId} />
    <input type="hidden" name="returnEntityId" value={entityId} />
    <input type="hidden" name="action" value={recordAction} />
    {recordAction === 'update' && <>
      <label htmlFor={`${prefix}-display-name`}>{isSite ? 'اسم الفرع أو الموقع' : 'اسم الجهة داخل المنصة'}</label>
      <Input id={`${prefix}-display-name`} name="displayName" defaultValue={state.displayName} required maxLength={160} />
      {!isSite && <>
        <label htmlFor={`${prefix}-legal-name`}>الاسم القانوني (اختياري)</label>
        <Input id={`${prefix}-legal-name`} name="legalName" defaultValue={state.legalName} maxLength={200} />
        <p className="field-hint">اسم هذه الجهة مستقل عن اسم الشركة الظاهر في مساحة العمل.</p>
      </>}
    </>}
    <label htmlFor={`${prefix}-reason`}>{reasonLabel}</label>
    <Input id={`${prefix}-reason`} name="reason" defaultValue={state.reason} required minLength={3} maxLength={500} />
    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    <SubmitButton className={recordAction === 'deactivate' ? 'danger-button' : 'secondary-button'} label={label}
      ariaLabel={isSite && displayName ? `${label}: ${displayName}` : undefined} pendingLabel="جارٍ الحفظ…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
