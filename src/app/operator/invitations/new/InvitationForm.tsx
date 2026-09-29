'use client';

import Link from 'next/link';
import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { createInvitationAction, type InvitationFormState } from '../actions';

const errors = {
  invalid: 'تحقق من البريد وبيانات الشركة وحدود الاستخدام، ثم حاول مجددًا.',
  setup: 'خدمة الدعوات غير متاحة حاليًا. احتفظنا ببياناتك؛ حاول لاحقًا.',
  forbidden: 'تعذر تسجيل الدعوة. راجع بياناتك وصلاحيتك، ثم حاول مجددًا. احتفظنا بمفتاح الطلب لتكون إعادة المحاولة آمنة.',
};

export function InvitationForm({ requestKey }: { requestKey: string }) {
  const initial: InvitationFormState = {
    error: null,
    attempt: 0,
    values: {
      idempotencyKey: requestKey,
      tenantName: '',
      entityName: '',
      siteName: 'المقر الرئيسي',
      targetEmail: '',
      seatsMode: 'limited',
      seatsLimit: '10',
      sitesMode: 'limited',
      sitesLimit: '10',
    },
  };
  const [state, formAction] = useActionState(createInvitationAction, initial);
  const values = state.values;

  return <section className="workspace-form-panel" aria-label="بيانات دعوة المسؤول الأول">
    {state.error && <p className="form-message form-error" role="alert">{errors[state.error]}</p>}
    <form key={state.attempt} className="auth-form onboarding-form" action={formAction}>
      <input type="hidden" name="idempotencyKey" value={values.idempotencyKey} />
      <h2>الشركة</h2>
      <label htmlFor="tenantName">اسم الشركة</label>
      <input id="tenantName" name="tenantName" defaultValue={values.tenantName} required maxLength={160} autoFocus />
      <label htmlFor="entityName">اسم الجهة القانونية (اختياري)</label>
      <input id="entityName" name="entityName" defaultValue={values.entityName} maxLength={160} placeholder="يُستخدم اسم الشركة إذا تُرك فارغًا" />
      <label htmlFor="siteName">اسم الفرع الرئيسي</label>
      <input id="siteName" name="siteName" defaultValue={values.siteName} required maxLength={160} />
      <h2>المسؤول الأول</h2>
      <label htmlFor="targetEmail">البريد الإلكتروني</label>
      <input id="targetEmail" name="targetEmail" type="email" autoComplete="email" defaultValue={values.targetEmail} required maxLength={254} />
      <h2>حدود الاستخدام الأولية</h2>
      <LimitFields kind="seats" label="المستخدمون" mode={values.seatsMode} limit={values.seatsLimit} />
      <LimitFields kind="sites" label="الفروع" mode={values.sitesMode} limit={values.sitesLimit} />
      <div className="workspace-form-actions"><SubmitButton label="إرسال الدعوة" pendingLabel="جارٍ الإرسال…" />
        <Link className="secondary-button" href="/operator/invitations">إلغاء</Link></div>
    </form>
  </section>;
}

function LimitFields({ kind, label, mode, limit }: {
  kind: 'seats' | 'sites'; label: string; mode: 'limited' | 'unlimited'; limit: string;
}) {
  const [selectedMode, setSelectedMode] = useState(mode);
  return <fieldset className="limit-fields">
    <legend>{label}</legend>
    <label htmlFor={`${kind}Mode`}>نوع الحد</label>
    <select id={`${kind}Mode`} name={`${kind}Mode`} value={selectedMode}
      onChange={(event) => setSelectedMode(event.currentTarget.value as 'limited' | 'unlimited')}>
      <option value="limited">عدد محدد</option><option value="unlimited">غير محدود</option>
    </select>
    {selectedMode === 'limited' && <>
      <label htmlFor={`${kind}Limit`}>الحد الأقصى {kind === 'seats' ? 'للمستخدمين' : 'للفروع'}</label>
      <input id={`${kind}Limit`} name={`${kind}Limit`} type="number" min="1" step="1" defaultValue={limit} required />
    </>}
  </fieldset>;
}
