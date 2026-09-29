'use client';

import { useActionState } from 'react';
import Link from 'next/link';
import { SubmitButton } from '@/components/submit-button';
import { createLegalEntityFormAction, type NewEntityState } from '../actions';

export function NewEntityForm({ tenantId }: { tenantId: string }) {
  const initial: NewEntityState = { displayName: '', legalName: '', reason: '', error: '', attempt: 0 };
  const [state, action] = useActionState(createLegalEntityFormAction, initial);
  return <form key={state.attempt} action={action} className="auth-form compact-form">
    <input type="hidden" name="tenantId" value={tenantId} />
    <label htmlFor="entity-display-name">اسم الجهة</label>
    <input id="entity-display-name" name="displayName" required maxLength={160} autoFocus defaultValue={state.displayName} />
    <label htmlFor="entity-legal-name">الاسم القانوني (اختياري)</label>
    <input id="entity-legal-name" name="legalName" maxLength={200} defaultValue={state.legalName} />
    <p className="field-hint">اسم الجهة مستقل عن اسم الشركة الظاهر للمستخدمين.</p>
    <label htmlFor="entity-create-reason">سبب الإضافة</label>
    <input id="entity-create-reason" name="reason" required minLength={3} maxLength={500} defaultValue={state.reason} />
    {state.error && <p className="form-message error-message" role="alert">{state.error}</p>}
    <div className="workspace-form-actions"><SubmitButton label="إضافة الجهة" pendingLabel="جارٍ الإضافة…" />
      <Link className="secondary-button" href={`/tenant/${tenantId}/entities-sites`}>إلغاء</Link></div>
  </form>;
}
