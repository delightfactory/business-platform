'use client';

import { useActionState, useState, type ChangeEvent } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { halfDayPartLabel } from '../rules';
import { PendingLink } from '../pending-link';
import { recordLeaveAction } from './actions';
import {
  EMPTY_RECORD_STATE,
  MAX_REASON_LENGTH,
  MIN_REASON_LENGTH,
  dayCount,
  halfDayAllowedOn,
  halfDayContextNotice,
  type EmployeeOption,
  type HalfDayContext,
  type HalfDayPart,
  type LeaveTypeOption,
} from './rules';
import styles from '../review.module.css';

export function RecordLeaveForm({ tenantId, q, employee, startDate, endDate, types, halfDayContext, halfDayError, cancelHref }: {
  tenantId: string;
  q: string;
  employee: EmployeeOption;
  startDate: string;
  endDate: string;
  types: LeaveTypeOption[];
  halfDayContext: HalfDayContext | null;
  halfDayError: string | null;
  cancelHref: string;
}) {
  const [leaveTypeId, setLeaveTypeId] = useState('');
  const [halfDay, setHalfDay] = useState(false);
  const [halfDayPart, setHalfDayPart] = useState<HalfDayPart | ''>('');
  const [reason, setReason] = useState('');
  const [submitState, submitAction, submitting] = useActionState(recordLeaveAction, EMPTY_RECORD_STATE);

  const singleDate = startDate === endDate;
  const selectedType = types.find((type) => type.id === leaveTypeId) ?? null;
  const halfDayAvailable = singleDate && selectedType !== null && halfDayAllowedOn(selectedType, startDate);
  const partChoices = halfDayContext !== null && halfDayContext.state === 'mapped_options'
    && halfDayContext.scheduleKind === 'fixed';
  const halfDayBlocked = singleDate && (halfDayError !== null || halfDayContext === null);
  const notice = halfDay && halfDayContext !== null ? halfDayContextNotice(halfDayContext) : '';
  const noticeTone = halfDayContext !== null && halfDayContext.state === 'review_required';

  function handleTypeChange(event: ChangeEvent<HTMLSelectElement>) {
    setLeaveTypeId(event.target.value);
    setHalfDay(false);
    setHalfDayPart('');
  }

  function handleHalfDayChange(event: ChangeEvent<HTMLInputElement>) {
    const checked = event.target.checked;
    setHalfDay(checked);
    setHalfDayPart(checked && partChoices ? 'first' : '');
  }

  function handlePartChange(event: ChangeEvent<HTMLSelectElement>) {
    const value = event.target.value;
    setHalfDayPart(value === 'first' || value === 'second' ? value : '');
  }

  return <div className={styles.formBlock}>
    <h2 className={styles.formTitle}>بيانات طلب الإجازة</h2>
    <form className="auth-form" action={submitAction} aria-busy={submitting}>
      <input type="hidden" name="tenantId" value={tenantId} />
      <input type="hidden" name="q" value={q} />
      <input type="hidden" name="employee" value={employee.employeeId} />
      <input type="hidden" name="employment" value={employee.employmentId} />
      <input type="hidden" name="startDate" value={startDate} />
      <input type="hidden" name="endDate" value={endDate} />
      <input type="hidden" name="halfDay" value={halfDay ? 'true' : 'false'} />
      <input type="hidden" name="halfDayPart" value={halfDayPart} />

      <label htmlFor="leave-type">نوع الإجازة</label>
      <select id="leave-type" value={leaveTypeId} onChange={handleTypeChange} disabled={submitting} required>
        <option value="" disabled>اختر نوع الإجازة</option>
        {types.map((type) => <option key={type.id} value={type.id}>{type.name}</option>)}
      </select>
      <p className="field-hint">الفترة المختارة: <bdi>{startDate}</bdi> إلى <bdi>{endDate}</bdi>
        {' · '}{dayCount(startDate, endDate)} يومًا. أيام الإجازة المحتسبة تحددها سياسة نوع الإجازة وتقويم الجهة.</p>

      {halfDayBlocked
        ? <p className="form-message" role="status">
          تسجيل نصف يوم غير متاح لهذا التاريخ الآن؛ يُسجَّل الطلب كيوم كامل.
        </p>
        : singleDate && selectedType === null
          ? <p className="field-hint" role="status">اختر نوع الإجازة لعرض خيار نصف يوم إن كان متاحًا في هذا اليوم.</p>
          : singleDate && !halfDayAvailable
            ? <p className="field-hint" role="status">نوع الإجازة المحدد لا يسمح بنصف يوم في هذا التاريخ.</p>
            : !singleDate
              ? <p className="field-hint" role="status">تسجيل نصف يوم متاح عندما يكون تاريخ البداية والنهاية متطابقين.</p>
              : null}
      {singleDate && !halfDayBlocked && halfDayAvailable && <label className="check-option">
        <input type="checkbox" checked={halfDay} onChange={handleHalfDayChange} disabled={submitting} />
        <span>نصف يوم — يُحتسب وفق سياسة نوع الإجازة في هذا اليوم</span>
      </label>}
      {halfDay && partChoices && <>
        <label htmlFor="leave-half-day-part">جزء نصف اليوم</label>
        <select id="leave-half-day-part" value={halfDayPart} onChange={handlePartChange} disabled={submitting}>
          <option value="first">{halfDayPartLabel('first')}</option>
          <option value="second">{halfDayPartLabel('second')}</option>
        </select>
        <p className="field-hint">اختر الجزء الذي يشمله نصف يوم حسب دوام الموظف في هذا اليوم.</p>
      </>}
      {notice && <p className={noticeTone ? 'form-message' : 'field-hint'} role="status">{notice}</p>}

      <label htmlFor="leave-reason">سبب الإجازة</label>
      <textarea id="leave-reason" value={reason} onChange={(event) => setReason(event.target.value)}
        disabled={submitting} required minLength={MIN_REASON_LENGTH} maxLength={MAX_REASON_LENGTH}
        aria-invalid={Boolean(submitState.error)} />
      {submitState.error && <p key={submitState.attempt} className="form-message form-error" role="alert">
        {submitState.error}
      </p>}
      {submitting && <p className="field-hint" role="status">جارٍ تسجيل الطلب… لا تغلق الصفحة.</p>}

      <div className="workspace-form-actions">
        <SubmitButton label="تسجيل الطلب" pendingLabel="جارٍ التسجيل…" />
        <PendingLink className="secondary-button" href={cancelHref}>إلغاء</PendingLink>
      </div>
      <p className="field-hint">يُسجَّل الطلب بحالة «مُقدَّم وبانتظار القرار»، ولا يُحجز أي رصيد من رصيد الموظف قبل الاعتماد.</p>
    </form>
  </div>;
}
