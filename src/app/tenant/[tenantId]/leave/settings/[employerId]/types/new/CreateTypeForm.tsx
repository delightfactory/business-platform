'use client';

import { Checkbox, Disclosure, Field, Input, Message, Radio } from '@/components/ui';
import { SettingsLink as Link } from '../../../SettingsLink';
import { useActionState } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { createTypeAction } from '../../../actions';
import {
  EMPTY_CREATE_TYPE_FORM,
  MAX_CODE_LENGTH,
  MAX_NAME_LENGTH,
  MAX_REASON_LENGTH,
  MAX_SOURCE_LENGTH,
  MIN_REASON_LENGTH,
} from '../../../rules';
import styles from '../../../settings.module.css';

export function CreateTypeForm({ tenantId, employerId, initialCode }: {
  tenantId: string;
  employerId: string;
  initialCode: string;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [state, action, pending] = useActionState(createTypeAction,
    { ...EMPTY_CREATE_TYPE_FORM, code: initialCode });
  const overviewPath = `/tenant/${tenantId}/leave/settings/${employerId}`;

  const showOfflineNotice = offline && !pending;

  return <form key={state.attempt} action={action} className="auth-form" aria-busy={pending} onSubmit={(event) => { blockOfflineSubmission(event); }}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="employerId" value={employerId} />

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="type-name" label={<>اسم النوع</>} required><Input id="type-name" name="name" required maxLength={MAX_NAME_LENGTH}
          defaultValue={state.name} disabled={pending} placeholder="مثال: إجازة سنوية" /></Field>
        <span className="field-hint">الاسم الذي يظهر للموظفين عند طلب الإجازة.</span>
      </div>
      <div className={styles.field}>
        <Field id="type-from" label={<>بداية سريان النوع</>} required><Input id="type-from" name="effectiveFrom" type="date" required
          defaultValue={state.effectiveFrom} disabled={pending} /></Field>
        <span className="field-hint">أول تاريخ يُطبَّق فيه هذا النوع وإعداداته.</span>
      </div>
    </div>

    <Disclosure  summary={<>خيارات متقدمة: الرمز</>}>
      <div className={styles.field}>
        <Field id="type-code" label={<>رمز النوع</>} required><Input id="type-code" name="code" required maxLength={MAX_CODE_LENGTH} autoComplete="off"
          defaultValue={state.code} disabled={pending} /></Field>
        <span className="field-hint">
          يُملأ تلقائيًا. عدّله فقط إن كانت شركتك تستخدم رمزًا محددًا؛ الحد {MAX_CODE_LENGTH} حرفًا.
        </span>
      </div>
    </Disclosure>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>الأثر على الأجر</legend>
      <div className={styles.optionGrid}>
        <label className={styles.option}>
          <Radio  name="payEffect" value="paid" defaultChecked={state.payEffect === 'paid'} />
          <span>الإجازة بأجر</span>
        </label>
        <label className={styles.option}>
          <Radio  name="payEffect" value="unpaid" defaultChecked={state.payEffect === 'unpaid'} />
          <span>الإجازة بدون أجر</span>
        </label>
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>خصم الرصيد</legend>
      <div className={styles.optionGrid}>
        <label className={styles.option}>
          <Radio  name="balanceMode" value="tracked" defaultChecked={state.balanceMode === 'tracked'} />
          <span>تُخصم أيامها من الرصيد</span>
        </label>
        <label className={styles.option}>
          <Radio  name="balanceMode" value="untracked" defaultChecked={state.balanceMode === 'untracked'} />
          <span>لا تُخصم من الرصيد</span>
        </label>
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>احتساب الأيام</legend>
      <p className={styles.optionGroupHint}>يحدد ما إذا كانت الأيام المحتسبة تراعي تقويم الشركة أم أيامًا تقويمية متتالية.</p>
      <div className={styles.optionGrid}>
        <label className={styles.option}>
          <Radio  name="dayCountBasis" value="working_days"
            defaultChecked={state.dayCountBasis === 'working_days'} />
          <span>أيام العمل في التقويم (تستثني الراحة والعطلات)</span>
        </label>
        <label className={styles.option}>
          <Radio  name="dayCountBasis" value="calendar_days"
            defaultChecked={state.dayCountBasis === 'calendar_days'} />
          <span>أيام تقويمية متتالية</span>
        </label>
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>النصف يوم</legend>
      <label className={styles.option}>
        <Checkbox  name="halfDay" value="true" defaultChecked={state.halfDay} />
        <span>يُسمح بطلب نصف يوم من هذا النوع</span>
      </label>
    </fieldset>

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <Field id="type-source" label={<>مصدر التعديل</>} required><Input id="type-source" name="source" required maxLength={MAX_SOURCE_LENGTH}
          defaultValue={state.source} disabled={pending} placeholder="مثال: سياسة الإجازات 2027" /></Field>
        <span className="field-hint">يظهر مع كل إصدار في سجل التغييرات.</span>
      </div>
      <div className={styles.field}>
        <Field id="type-reason" label={<>سبب الإنشاء</>} required><Input id="type-reason" name="reason" required minLength={MIN_REASON_LENGTH}
          maxLength={MAX_REASON_LENGTH} defaultValue={state.reason} disabled={pending} /></Field>
        <span className="field-hint">يُحفظ في سجل التغييرات ولا يمكن تعديله لاحقًا.</span>
      </div>
    </div>

    {state.error && <Message tone="bad"  role="alert">{state.error}</Message>}
    {pending && <p className="field-hint" role="status">جارٍ إنشاء نوع الإجازة…</p>}

    <div className="workspace-form-actions">
      <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label="إنشاء النوع" pendingLabel="جارٍ الإنشاء…" />
      <Link className="secondary-button" href={overviewPath}>العودة إلى الإعدادات</Link>
    </div>
    {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
  </form>;
}
