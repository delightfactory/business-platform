'use client';

import { Field, Input, Message } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { useActionState, useRef, useState } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { setTypeActiveAction } from '../../../actions';
import { EMPTY_ACTIVATION_FORM, MAX_REASON_LENGTH, MIN_REASON_LENGTH } from '../../../rules';
import styles from '../../../settings.module.css';

export function TypeActivationForm({ tenantId, employerId, typeId, targetActive, initialKey, detailPath }: {
  tenantId: string;
  employerId: string;
  typeId: string;
  targetActive: boolean;
  initialKey: string;
  detailPath: string;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [state, action, pending] = useActionState(setTypeActiveAction, EMPTY_ACTIVATION_FORM);
  const [reason, setReason] = useState(state.reason);
  const [operationKey, setOperationKey] = useState(initialKey);
  const keysRef = useRef<Map<string, string> | null>(null);
  if (keysRef.current === null) keysRef.current = new Map([[signature(state.reason), initialKey]]);

  function signature(value: string): string {
    return `${typeId}|${targetActive}|${value.trim()}`;
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
    const fresh = crypto.randomUUID();
    keys.set(key, fresh);
    setOperationKey(fresh);
  }

  const showOfflineNotice = offline && !pending;

  return <form key={state.attempt} action={action} className="auth-form" aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="employerId" value={employerId} />
    <input type="hidden" name="typeId" value={typeId} />
    <input type="hidden" name="isActive" value={String(targetActive)} />
    <input type="hidden" name="operationKey" value={operationKey} />

    <div className={styles.field}>
      <Field id="activation-reason" label={<>{targetActive ? 'سبب التفعيل' : 'سبب الإيقاف'}</>} required><Input id="activation-reason" name="reason" required minLength={MIN_REASON_LENGTH}
        maxLength={MAX_REASON_LENGTH} value={reason} onChange={(event) => handleReasonChange(event.target.value)}
        disabled={pending} /></Field>
      <span className="field-hint">يُحفظ في سجل التغييرات ولا يمكن تعديله لاحقًا.</span>
    </div>

    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    {pending && <p className="field-hint" role="status">جارٍ حفظ التغيير… لا تغلق الصفحة.</p>}

    <div className="workspace-form-actions">
      <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label={targetActive ? 'تفعيل النوع' : 'إيقاف استخدام النوع'}
        pendingLabel="جارٍ الحفظ…" className={targetActive ? 'primary-button' : 'danger-button'} />
      <Link className="secondary-button" href={detailPath}>العودة إلى الإعدادات</Link>
    </div>
    <p className="field-hint">
      {targetActive
        ? 'يُفعَّل النوع للاستخدام الجديد. إن كانت الحالة كما هي بالفعل فلن يتغير شيء.'
        : 'يُوقَف النوع عن الطلبات الجديدة؛ تبقى إصداراته وسجلاته محفوظة، ويمكن إعادة التفعيل لاحقًا. إن كانت الحالة كما هي بالفعل فلن يتغير شيء.'}
      {' '}المفتاح ثابت لكل (سبب وهدف) محددين، فتُعاد محاولة فاشلة بالنتيجة نفسها دون تكرار.
    </p>
    {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
  </form>;
}
