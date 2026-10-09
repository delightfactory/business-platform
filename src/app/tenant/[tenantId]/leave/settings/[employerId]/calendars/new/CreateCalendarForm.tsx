'use client';

import { Disclosure, Field, Input, Message } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { useActionState } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { createCalendarAction } from '../../../actions';
import { CalendarRuleFields } from '../../../CalendarRuleFields';
import {
  EMPTY_CALENDAR_FORM,
  MAX_CODE_LENGTH,
  MAX_NAME_LENGTH,
  MAX_REASON_LENGTH,
  MAX_SOURCE_LENGTH,
  MIN_REASON_LENGTH,
} from '../../../rules';
import styles from '../../../settings.module.css';

export function CreateCalendarForm({ tenantId, employerId, initialCode }: {
  tenantId: string;
  employerId: string;
  initialCode: string;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [state, action, pending] = useActionState(createCalendarAction,
    { ...EMPTY_CALENDAR_FORM, code: initialCode });
  const overviewPath = `/tenant/${tenantId}/leave/settings/${employerId}`;

  const showOfflineNotice = offline && !pending;

  return <form key={state.attempt} action={action} className="auth-form" aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="employerId" value={employerId} />

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="calendar-name" label={<>اسم التقويم</>} required><Input id="calendar-name" name="name" required maxLength={MAX_NAME_LENGTH}
          defaultValue={state.name} disabled={pending} /></Field>
        <span className="field-hint">مثال: تقويم المكتب الرئيسي.</span>
      </div>
      <div className={styles.field}>
        <Field id="calendar-from" label={<>بداية سريان التقويم</>} required><Input id="calendar-from" name="effectiveFrom" type="date" required
          defaultValue={state.effectiveFrom} disabled={pending} /></Field>
        <span className="field-hint">أول يوم يُحتسب داخل التقويم.</span>
      </div>
      <div className={styles.field}>
        <Field id="calendar-until" label={<>نهاية السريان (اختياري)</>}><Input id="calendar-until" name="effectiveUntil" type="date"
          defaultValue={state.effectiveUntil} disabled={pending} /></Field>
        <span className="field-hint">أول يوم خارج سريان التقويم، ولا يُحتسب ضمنه. اتركه فارغًا ليظل التقويم مفتوحًا حتى إصدار لاحق.</span>
      </div>
    </div>

    <Disclosure  summary={<>خيارات متقدمة: الرمز</>}>
      <div className={styles.field}>
        <Field id="calendar-code" label={<>رمز التقويم</>} required><Input id="calendar-code" name="code" required maxLength={MAX_CODE_LENGTH} autoComplete="off"
          defaultValue={state.code} disabled={pending} /></Field>
        <span className="field-hint">
          يُملأ تلقائيًا. عدّله فقط إن كانت شركتك تستخدم رمزًا محددًا؛ الحد {MAX_CODE_LENGTH} حرفًا.
        </span>
      </div>
    </Disclosure>

    <CalendarRuleFields idPrefix="calendar-create" restDays={state.restDays}
      holidays={state.holidays} disabled={pending} />

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="calendar-source" label={<>مصدر التعديل</>} required><Input id="calendar-source" name="source" required maxLength={MAX_SOURCE_LENGTH}
          defaultValue={state.source} disabled={pending} placeholder="مثال: تقويم الشركة المعتمد" /></Field>
        <span className="field-hint">يظهر مع كل إصدار في سجل التغييرات.</span>
      </div>
      <div className={styles.field}>
        <Field id="calendar-reason" label={<>سبب الإنشاء</>} required><Input id="calendar-reason" name="reason" required minLength={MIN_REASON_LENGTH}
          maxLength={MAX_REASON_LENGTH} defaultValue={state.reason} disabled={pending} /></Field>
        <span className="field-hint">يُحفظ في سجل التغييرات ولا يمكن تعديله لاحقًا.</span>
      </div>
    </div>

    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    {pending && <p className="field-hint" role="status">جارٍ إنشاء التقويم…</p>}

    <div className="workspace-form-actions">
      <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label="إنشاء التقويم" pendingLabel="جارٍ الإنشاء…" />
      <Link className="secondary-button" href={overviewPath}>العودة إلى الإعدادات</Link>
    </div>
    {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
  </form>;
}
