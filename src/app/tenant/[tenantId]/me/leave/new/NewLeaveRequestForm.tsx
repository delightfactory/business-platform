'use client';

import { Message, Button, Checkbox } from '@/components/ui';
import { useActionState, useId, useRef, useState, useTransition, type ChangeEvent, type FormEvent } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { DateInput, Disclosure, Select, Textarea } from '@/components/ui';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { loadLeaveRequestOptionsAction, submitLeaveRequestAction } from '../actions';
import {
  EMPTY_LEAVE_FIELDS,
  dayCount,
  halfDayAllowedOn,
  leaveFieldsSignature,
  rangeErrorText,
  type LeaveFields,
  type LeaveOptionsState,
} from '../form-rules';
import { newOperationKey } from '../operation-key';
import { PendingLink } from '../pending-link';
import styles from '../leave.module.css';

export function NewLeaveRequestForm({ tenantId, idempotencyKey }: { tenantId: string; idempotencyKey: string }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [fields, setFields] = useState<LeaveFields>(EMPTY_LEAVE_FIELDS);
  const fieldsRef = useRef<LeaveFields>(EMPTY_LEAVE_FIELDS);
  const [options, setOptions] = useState<LeaveOptionsState | null>(null);
  const [optionsError, setOptionsError] = useState('');
  const [operationKey, setOperationKey] = useState(idempotencyKey);
  const keyRef = useRef({ key: idempotencyKey, signature: leaveFieldsSignature(EMPTY_LEAVE_FIELDS) });
  const loadSequenceRef = useRef(0);
  const [loadingOptions, startOptionsLoad] = useTransition();
  const [submitState, submitAction, submitting] = useActionState(submitLeaveRequestAction, { error: '', attempt: 0 });

  const frozen = loadingOptions || submitting;
  const rangeError = rangeErrorText(fields.startDate, fields.endDate);
  const showOfflineNotice = offline && !frozen && !rangeError && Boolean(options?.types.length)
    && options?.startDate === fields.startDate && options?.endDate === fields.endDate;
  const selectedType = options?.types.find((type) => type.id === fields.leaveTypeId) ?? null;
  const halfDayAvailable = Boolean(options && selectedType && options.startDate === options.endDate
    && halfDayAllowedOn(selectedType, options.startDate));

  function applyFields(next: LeaveFields) {
    fieldsRef.current = next;
    setFields(next);
    const signature = leaveFieldsSignature(next);
    if (signature === keyRef.current.signature) return;
    const key = newOperationKey();
    keyRef.current = { key, signature };
    setOperationKey(key);
  }

  function clearOptions() {
    setOptionsError('');
    loadSequenceRef.current += 1;
  }

  function handleStartDateChange(event: ChangeEvent<HTMLInputElement>) {
    const startDate = event.target.value;
    const current = fieldsRef.current;
    const endDate = !current.endDate || (startDate && startDate > current.endDate) ? startDate : current.endDate;
    applyFields({ ...current, startDate, endDate });
    clearOptions();
  }

  function handleEndDateChange(event: ChangeEvent<HTMLInputElement>) {
    const current = fieldsRef.current;
    applyFields({ ...current, endDate: event.target.value });
    clearOptions();
  }

  function handleTypeChange(event: ChangeEvent<HTMLSelectElement>) {
    applyFields({ ...fieldsRef.current, leaveTypeId: event.target.value, halfDay: false });
  }

  function handleHalfDayChange(event: ChangeEvent<HTMLInputElement>) {
    applyFields({ ...fieldsRef.current, halfDay: event.target.checked });
  }

  function handleReasonChange(event: ChangeEvent<HTMLTextAreaElement>) {
    applyFields({ ...fieldsRef.current, reason: event.target.value });
  }

  function loadOptions(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault();
    if (rangeError || frozen) return;
    const requested = fieldsRef.current;
    const sequence = ++loadSequenceRef.current;
    const formData = new FormData();
    formData.set('tenantId', tenantId);
    formData.set('startDate', requested.startDate);
    formData.set('endDate', requested.endDate);
    startOptionsLoad(async () => {
      let result: LeaveOptionsState;
      try {
        result = await loadLeaveRequestOptionsAction(formData);
      } catch {
        if (sequence !== loadSequenceRef.current) return;
        const current = fieldsRef.current;
        if (current.startDate !== requested.startDate || current.endDate !== requested.endDate) return;
        setOptionsError('تعذر تحميل أنواع الإجازة الآن. احتفظنا بالبيانات التي أدخلتها؛ أعد تحميل الأنواع للمتابعة.');
        return;
      }
      if (sequence !== loadSequenceRef.current) return;
      const current = fieldsRef.current;
      if (current.startDate !== requested.startDate || current.endDate !== requested.endDate) return;
      if (result.error) {
        setOptionsError(result.error);
        return;
      }
      const keepTypeId = current.leaveTypeId !== ''
        && result.types.some((type) => type.id === current.leaveTypeId);
      const nextTypeId = keepTypeId ? current.leaveTypeId
        : result.types.length === 1 ? result.types[0].id : '';
      const nextType = result.types.find((type) => type.id === nextTypeId) ?? null;
      const nextHalfDay = keepTypeId && current.halfDay && nextType !== null
        && result.startDate === result.endDate && halfDayAllowedOn(nextType, result.startDate);
      applyFields({ ...current, leaveTypeId: nextTypeId, halfDay: nextHalfDay });
      setOptions(result);
      setOptionsError(current.leaveTypeId && !keepTypeId ? 'نوع الإجازة السابق غير متاح للتواريخ الجديدة. اختر نوعًا آخر.' : '');
    });
  }

  return <>
    <div className={styles.formBlock}>
      <h2 className={styles.formTitle}>تواريخ الإجازة</h2>
      <form className="auth-form" onSubmit={loadOptions} aria-busy={loadingOptions}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <div className={styles.dateFields}>
        <div className={styles.formField}>
        <label htmlFor="leave-start-date">تاريخ البداية</label>
        <DateInput id="leave-start-date" name="startDate" required value={fields.startDate}
          onChange={handleStartDateChange} onBlur={() => loadOptions()} disabled={frozen} aria-invalid={Boolean(rangeError)} />
        </div>
        <div className={styles.formField}>
        <label htmlFor="leave-end-date">تاريخ النهاية</label>
        <DateInput id="leave-end-date" name="endDate" required value={fields.endDate}
          onChange={handleEndDateChange} onBlur={() => loadOptions()} disabled={frozen} aria-invalid={Boolean(rangeError)} />
        </div>
        </div>
        <p className="field-hint">اختر التواريخ أولًا؛ تُحمَّل بعدها أنواع الإجازة المتاحة في هذه الفترة.</p>
        {rangeError && <Message tone="bad"  role="alert">{rangeError}</Message>}
        {optionsError && <Message tone="bad"  role="alert">{optionsError}</Message>}
        {loadingOptions && <p className="field-hint" role="status">جارٍ تحميل أنواع الإجازة المتاحة…</p>}
        {optionsError && <div className="workspace-form-actions">
          <Button variant="ghost"  type="submit" disabled={frozen || Boolean(rangeError)}
            aria-busy={loadingOptions}>
            {loadingOptions && <span className="button-spinner" aria-hidden="true" />}
            {loadingOptions ? 'جارٍ تحميل الأنواع…' : 'إعادة تحميل الأنواع'}
          </Button>
        </div>}
      </form>
    </div>

    {options && <div className={styles.formBlock}>
      <h2 className={styles.formTitle}>بيانات الطلب</h2>
      <form className="auth-form" action={submitAction} aria-busy={submitting}
        onSubmit={(event) => { blockOfflineSubmission(event); }}>
        <fieldset disabled={frozen || Boolean(rangeError) || options.startDate !== fields.startDate || options.endDate !== fields.endDate}
          className={styles.requestFields}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="startDate" value={options.startDate} />
        <input type="hidden" name="endDate" value={options.endDate} />
        <input type="hidden" name="halfDay" value={fields.halfDay ? 'true' : 'false'} />
        <input type="hidden" name="idempotencyKey" value={operationKey} />
        {options.types.length === 0
          ? <Message tone="info"  role="status">لا توجد أنواع إجازة متاحة في هذه الفترة. جرّب تواريخًا أخرى أو تواصل مع إدارة الموارد البشرية.</Message>
          : <>
            <label htmlFor="leave-type">نوع الإجازة</label>
            <Select id="leave-type" name="leaveTypeId" required value={fields.leaveTypeId}
              onChange={handleTypeChange} disabled={submitting}>
              <option value="" disabled>اختر نوع الإجازة</option>
              {options.types.map((type) => <option key={type.id} value={type.id}>{type.name}</option>)}
            </Select>
            <Disclosure summary="الفترة وطريقة احتساب الأيام"><p className="field-hint">الفترة المختارة: <bdi>{options.startDate}</bdi> إلى <bdi>{options.endDate}</bdi>
              {' · '}{dayCount(options.startDate, options.endDate)} يومًا متتاليًا (مدة تقويمية بين التاريخين،
              وليست كمية إجازة مخصومة). أيام الإجازة المحتسبة تحددها سياسة نوع الإجازة.</p></Disclosure>
            {halfDayAvailable && <label className="check-option">
              <Checkbox  checked={fields.halfDay} onChange={handleHalfDayChange} disabled={submitting} />
              <span>نصف يوم — يُحتسب وفق سياسة نوع الإجازة في هذا اليوم</span>
            </label>}
            <label htmlFor="leave-reason">سبب الإجازة</label>
            <Textarea id="leave-reason" name="reason" required minLength={3} maxLength={500}
              value={fields.reason} onChange={handleReasonChange} disabled={submitting}
              aria-invalid={Boolean(submitState.error)} aria-describedby="leave-reason-hint" />
            <p id="leave-reason-hint" className="field-hint">اكتب السبب في 3 إلى 500 حرف ليُراجعه فريق الموارد البشرية.</p>
            {submitState.error && <Message tone="bad" key={submitState.attempt}  role="alert">{submitState.error}</Message>}
            {submitting && <p className="field-hint" role="status">جارٍ إرسال الطلب… لا تغلق الصفحة.</p>}
            <div className="workspace-form-actions">
              <SubmitButton label="إرسال طلب الإجازة" pendingLabel="جارٍ الإرسال…" disabled={offline}
                ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} />
              {submitting ? <span className={`secondary-button ${styles.disabledAction}`} aria-disabled="true">إلغاء</span>
                : <PendingLink className="secondary-button" href={`/tenant/${tenantId}/me/leave`}>إلغاء</PendingLink>}
            </div>
            <p className="field-hint">يُرسَل الطلب بحالة «مُقدَّم وبانتظار القرار»، ولا يُحجز أي رصيد قبل الاعتماد.</p>
          </>}
        </fieldset>
        {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} />}
      </form>
    </div>}
  </>;
}
