'use client';

import { Field, Input, Message, Select } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { useActionState, useState } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { createYearPeriodAction } from '../../../actions';
import {
  EMPTY_YEAR_PERIOD_FORM,
  MAX_LABEL_LENGTH,
  MAX_REASON_LENGTH,
  MIN_REASON_LENGTH,
} from '../../../rules';
import styles from '../../../settings.module.css';

export function CreateYearPeriodForm({ tenantId, employerId, calendars }: {
  tenantId: string;
  employerId: string;
  calendars: { id: string; name: string; coverageText: string }[];
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [state, action, pending] = useActionState(createYearPeriodAction, EMPTY_YEAR_PERIOD_FORM);
  const [selected, setSelected] = useState(state.calendarId || calendars[0]?.id || '');
  const overviewPath = `/tenant/${tenantId}/leave/settings/${employerId}`;
  const coverage = calendars.find((calendar) => calendar.id === selected);

  const showOfflineNotice = offline && !pending && calendars.length > 0;

  return <form key={state.attempt} action={action} className="auth-form" aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="employerId" value={employerId} />

    <div className={styles.field}>
      <Field id="period-calendar" label={<>تقويم فترة الإجازة</>} required><Select id="period-calendar" name="calendarId" value={selected} required disabled={pending}
        onChange={(event) => setSelected(event.target.value)}>
        {calendars.map((calendar) => <option key={calendar.id} value={calendar.id}>{calendar.name}</option>)}
      </Select></Field>
      <span className="field-hint">
        {coverage
          ? `تغطية التقويم: ${coverage.coverageText}. يجب أن تقع فترة الإجازة كاملة داخل هذه التغطية.`
          : 'اختر تقويمًا يحمل إصدارات مغطية.'}
      </span>
    </div>

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="period-starts" label={<>بداية الفترة</>} required><Input id="period-starts" name="startsOn" type="date" required
          defaultValue={state.startsOn} disabled={pending} /></Field>
        <span className="field-hint">أول يوم مشمول داخل الفترة.</span>
      </div>
      <div className={styles.field}>
        <Field id="period-ends" label={<>نهاية الفترة</>} required><Input id="period-ends" name="endsOn" type="date" required
          defaultValue={state.endsOn} disabled={pending} /></Field>
        <span className="field-hint">آخر يوم مشمول في سنة الرصيد.</span>
      </div>
    </div>

    <div className={styles.field}>
      <Field id="period-label" label={<>اسم الفترة</>} required><Input id="period-label" name="label" required maxLength={MAX_LABEL_LENGTH}
        defaultValue={state.label} disabled={pending} placeholder="مثال: إجازات 2027" /></Field>
    </div>

    <div className={styles.field}>
      <Field id="period-reason" label={<>سبب الإنشاء</>} required><Input id="period-reason" name="reason" required minLength={MIN_REASON_LENGTH}
        maxLength={MAX_REASON_LENGTH} defaultValue={state.reason} disabled={pending} /></Field>
      <span className="field-hint">يُحفظ في سجل التغييرات ولا يمكن تعديله لاحقًا.</span>
    </div>

    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    {pending && <p className="field-hint" role="status">جارٍ إنشاء الفترة…</p>}

    <div className="workspace-form-actions">
      <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label="إنشاء الفترة" pendingLabel="جارٍ الإنشاء…" />
      <Link className="secondary-button" href={overviewPath}>العودة إلى الإعدادات</Link>
    </div>
    <p className="field-hint">اختر فترة يغطيها التقويم ولا تتداخل مع سنة رصيد محفوظة.</p>
    {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
  </form>;
}
