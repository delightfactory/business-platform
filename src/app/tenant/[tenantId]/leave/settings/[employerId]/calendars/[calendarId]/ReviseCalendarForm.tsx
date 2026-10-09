'use client';

import { Field, Input, Message } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { useActionState } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { reviseCalendarAction } from '../../../actions';
import { CalendarRuleFields } from '../../../CalendarRuleFields';
import {
  MAX_REASON_LENGTH,
  MAX_SOURCE_LENGTH,
  MIN_REASON_LENGTH,
  type ReviseCalendarState,
} from '../../../rules';
import styles from '../../../settings.module.css';

export function ReviseCalendarForm({ tenantId, employerId, calendarId, detailPath, initial }: {
  tenantId: string;
  employerId: string;
  calendarId: string;
  detailPath: string;
  initial: ReviseCalendarState;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [state, action, pending] = useActionState(reviseCalendarAction, initial);

  const showOfflineNotice = offline && !pending;

  return <form key={state.attempt} action={action} className="auth-form" aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="employerId" value={employerId} />
    <input type="hidden" name="calendarId" value={calendarId} />

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="calendar-revise-from" label={<>بداية سريان الإصدار الجديد</>} required><Input id="calendar-revise-from" name="effectiveFrom" type="date" required
          defaultValue={state.effectiveFrom} disabled={pending} /></Field>
        <span className="field-hint">يجب أن يكون بعد تاريخ اليوم بتوقيت القاهرة؛ الإصدار الحالي يبقى ساريًا حتى ذلك الحين.</span>
      </div>
      <div className={styles.field}>
        <Field id="calendar-revise-until" label={<>نهاية السريان (اختياري)</>}><Input id="calendar-revise-until" name="effectiveUntil" type="date"
          defaultValue={state.effectiveUntil} disabled={pending} /></Field>
        <span className="field-hint">أول يوم خارج سريان الإصدار الجديد، ولا يُحتسب ضمنه. اتركه فارغًا ليظل مفتوحًا.</span>
      </div>
    </div>

    <CalendarRuleFields idPrefix="calendar-revise" restDays={state.restDays}
      holidays={state.holidays} disabled={pending} />

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="calendar-revise-source" label={<>مصدر التعديل</>} required><Input id="calendar-revise-source" name="source" required maxLength={MAX_SOURCE_LENGTH}
          defaultValue={state.source} disabled={pending} placeholder="مثال: تحديث تقويم 2027" /></Field>
        <span className="field-hint">يظهر مع الإصدار الجديد في سجل التغييرات.</span>
      </div>
      <div className={styles.field}>
        <Field id="calendar-revise-reason" label={<>سبب التعديل</>} required><Input id="calendar-revise-reason" name="reason" required minLength={MIN_REASON_LENGTH}
          maxLength={MAX_REASON_LENGTH} defaultValue={state.reason} disabled={pending} /></Field>
        <span className="field-hint">يُحفظ في سجل التغييرات ولا يمكن تعديله لاحقًا.</span>
      </div>
    </div>

    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    {pending && <p className="field-hint" role="status">جارٍ حفظ الإصدار الجديد… لا تغلق الصفحة.</p>}

    <div className="workspace-form-actions">
      <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label="حفظ الإصدار الجديد" pendingLabel="جارٍ الحفظ…" />
      <Link className="secondary-button" href={detailPath}>العودة إلى الإعدادات</Link>
    </div>
    <p className="field-hint">يُنشأ إصدار جديد فقط من تاريخ السريان الذي تختاره؛ الإصدارات السابقة وتغطيتها تبقى كما هي. عند أي تعارض حُفظت بياناتك في النموذج — حدّث الصفحة لعرض أحدث الإعدادات ثم عدّل وأعد الحفظ.</p>
    {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
  </form>;
}
