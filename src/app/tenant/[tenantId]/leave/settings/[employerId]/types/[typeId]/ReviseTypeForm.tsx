'use client';

import { SettingsLink as Link } from '../../../SettingsLink';
import { useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { reviseTypeAction } from '../../../actions';
import {
  MAX_REASON_LENGTH,
  MAX_SOURCE_LENGTH,
  MIN_REASON_LENGTH,
  type ReviseTypeState,
} from '../../../rules';
import styles from '../../../settings.module.css';

export function ReviseTypeForm({ tenantId, employerId, typeId, detailPath, initial }: {
  tenantId: string;
  employerId: string;
  typeId: string;
  detailPath: string;
  initial: ReviseTypeState;
}) {
  const [state, action, pending] = useActionState(reviseTypeAction, initial);

  return <form key={state.attempt} action={action} className="auth-form" aria-busy={pending}>
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="employerId" value={employerId} />
    <input type="hidden" name="typeId" value={typeId} />

    <div className={styles.field}>
      <label htmlFor="type-revise-from">بداية سريان الإصدار الجديد</label>
      <input id="type-revise-from" name="effectiveFrom" type="date" required
        defaultValue={state.effectiveFrom} disabled={pending} />
      <span className="field-hint">يجب أن يكون بعد تاريخ اليوم بتوقيت القاهرة؛ الإصدار الحالي يبقى ساريًا حتى ذلك الحين.</span>
    </div>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>الأثر على الأجر</legend>
      <div className={styles.optionGrid}>
        <label className={styles.option}>
          <input type="radio" name="payEffect" value="paid" defaultChecked={state.payEffect === 'paid'} />
          <span>الإجازة بأجر</span>
        </label>
        <label className={styles.option}>
          <input type="radio" name="payEffect" value="unpaid" defaultChecked={state.payEffect === 'unpaid'} />
          <span>الإجازة بدون أجر</span>
        </label>
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>خصم الرصيد</legend>
      <div className={styles.optionGrid}>
        <label className={styles.option}>
          <input type="radio" name="balanceMode" value="tracked" defaultChecked={state.balanceMode === 'tracked'} />
          <span>تُخصم أيامها من الرصيد</span>
        </label>
        <label className={styles.option}>
          <input type="radio" name="balanceMode" value="untracked" defaultChecked={state.balanceMode === 'untracked'} />
          <span>لا تُخصم من الرصيد</span>
        </label>
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>احتساب الأيام</legend>
      <p className={styles.optionGroupHint}>يحدد ما إذا كانت الأيام المحتسبة تراعي تقويم الشركة أم أيامًا تقويمية متتالية.</p>
      <div className={styles.optionGrid}>
        <label className={styles.option}>
          <input type="radio" name="dayCountBasis" value="working_days"
            defaultChecked={state.dayCountBasis === 'working_days'} />
          <span>أيام العمل في التقويم (تستثني الراحة والعطلات)</span>
        </label>
        <label className={styles.option}>
          <input type="radio" name="dayCountBasis" value="calendar_days"
            defaultChecked={state.dayCountBasis === 'calendar_days'} />
          <span>أيام تقويمية متتالية</span>
        </label>
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={pending}>
      <legend>النصف يوم</legend>
      <label className={styles.option}>
        <input type="checkbox" name="halfDay" value="true" defaultChecked={state.halfDay} />
        <span>يُسمح بطلب نصف يوم من هذا النوع</span>
      </label>
    </fieldset>

    <div className={styles.formGrid}>
      <div className={styles.field}>
        <label htmlFor="type-revise-source">مصدر التعديل</label>
        <input id="type-revise-source" name="source" required maxLength={MAX_SOURCE_LENGTH}
          defaultValue={state.source} disabled={pending} placeholder="مثال: مراجعة سياسة الإجازات" />
        <span className="field-hint">يظهر مع الإصدار الجديد في سجل التغييرات.</span>
      </div>
      <div className={styles.field}>
        <label htmlFor="type-revise-reason">سبب التعديل</label>
        <input id="type-revise-reason" name="reason" required minLength={MIN_REASON_LENGTH}
          maxLength={MAX_REASON_LENGTH} defaultValue={state.reason} disabled={pending} />
        <span className="field-hint">يُحفظ في سجل التغييرات ولا يمكن تعديله لاحقًا.</span>
      </div>
    </div>

    {state.error && <p className="form-message form-error" role="alert">{state.error}</p>}
    {pending && <p className="field-hint" role="status">جارٍ حفظ الإصدار الجديد… لا تغلق الصفحة.</p>}

    <div className="workspace-form-actions">
      <SubmitButton label="حفظ الإصدار الجديد" pendingLabel="جارٍ الحفظ…" />
      <Link className="secondary-button" href={detailPath}>العودة إلى الإعدادات</Link>
    </div>
    <p className="field-hint">يُنشأ إصدار جديد فقط من تاريخ السريان الذي تختاره، والإصدار الحالي يبقى ساريًا حتى ذلك التاريخ. عند أي تعارض حُفظت بياناتك — حدّث الصفحة لعرض أحدث الإعدادات ثم عدّل وأعد الحفظ.</p>
  </form>;
}
