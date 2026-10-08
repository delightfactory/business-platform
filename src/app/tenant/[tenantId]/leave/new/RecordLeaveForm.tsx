'use client';

import { useActionState, useEffect, useRef, useState, type ChangeEvent } from 'react';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import { SubmitButton } from '@/components/submit-button';
import { detailHref, halfDayPartLabel, isObject, isUuid } from '../rules';
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

export function RecordLeaveForm({ tenantId, actorId, q, employee, startDate, endDate, types, halfDayContext, halfDayError, cancelHref, initialIntentKey }: {
  tenantId: string;
  actorId: string;
  q: string;
  employee: EmployeeOption;
  startDate: string;
  endDate: string;
  types: LeaveTypeOption[];
  halfDayContext: HalfDayContext | null;
  halfDayError: string | null;
  cancelHref: string;
  initialIntentKey: string;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [leaveTypeId, setLeaveTypeId] = useState('');
  const [halfDay, setHalfDay] = useState(false);
  const [halfDayPart, setHalfDayPart] = useState<HalfDayPart | ''>('');
  const [reason, setReason] = useState('');
  const [operationKey, setOperationKey] = useState(initialIntentKey);
  const [draftReady, setDraftReady] = useState(false);
  const [storageUnavailable, setStorageUnavailable] = useState(false);
  const storageKey = ['leave.hr.record.v1', actorId, tenantId, employee.employmentId, startDate, endDate].join(':');
  const keysRef = useRef<Map<string, string> | null>(null);
  if (keysRef.current === null) keysRef.current = new Map([[JSON.stringify(['', false, '', '']), initialIntentKey]]);
  const [submitState, submitAction, submitting] = useActionState(recordLeaveAction, EMPTY_RECORD_STATE);

  const singleDate = startDate === endDate;
  const selectedType = types.find((type) => type.id === leaveTypeId) ?? null;
  const halfDayAvailable = singleDate && selectedType !== null && halfDayAllowedOn(selectedType, startDate);
  const partChoices = halfDayContext !== null && halfDayContext.state === 'mapped_options'
    && halfDayContext.scheduleKind === 'fixed';
  const halfDayBlocked = singleDate && (halfDayError !== null || halfDayContext === null);
  const notice = halfDay && halfDayContext !== null ? halfDayContextNotice(halfDayContext) : '';
  const noticeTone = halfDayContext !== null && halfDayContext.state === 'review_required';

  useEffect(() => {
    const frame = requestAnimationFrame(() => {
    try {
      const raw = sessionStorage.getItem(storageKey);
      const draft: unknown = raw ? JSON.parse(raw) : null;
      if (isObject(draft) && draft.version === 1 && typeof draft.savedAt === 'number'
        && Number.isFinite(draft.savedAt) && Date.now() >= draft.savedAt
        && isUuid(draft.operationKey) && (draft.leaveTypeId === '' || isUuid(draft.leaveTypeId))
        && typeof draft.halfDay === 'boolean' && typeof draft.halfDayPart === 'string'
        && ['', 'first', 'second'].includes(draft.halfDayPart)
        && typeof draft.reason === 'string' && draft.reason.length <= MAX_REASON_LENGTH) {
        const part = draft.halfDayPart as HalfDayPart | '';
        setLeaveTypeId(draft.leaveTypeId as string);
        setHalfDay(draft.halfDay);
        setHalfDayPart(part);
        setReason(draft.reason);
        setOperationKey(draft.operationKey);
        keysRef.current?.set(JSON.stringify([draft.leaveTypeId, draft.halfDay, part, draft.reason.trim()]), draft.operationKey);
      }
    } catch { setStorageUnavailable(true); }
    setDraftReady(true);
    });
    return () => cancelAnimationFrame(frame);
  }, [storageKey]);

  useEffect(() => {
    if (!draftReady) return;
    let errorFrame: number | undefined;
    try {
      if (submitState.requestId) sessionStorage.removeItem(storageKey);
      else sessionStorage.setItem(storageKey, JSON.stringify({ version: 1, savedAt: Date.now(),
        leaveTypeId, halfDay, halfDayPart, reason, operationKey }));
    } catch { errorFrame = requestAnimationFrame(() => setStorageUnavailable(true)); }
    return () => { if (errorFrame !== undefined) cancelAnimationFrame(errorFrame); };
  }, [draftReady, storageKey, leaveTypeId, halfDay, halfDayPart, reason, operationKey, submitState.requestId]);

  function updateIntent(type: string, half: boolean, part: string, text: string) {
    const signature = JSON.stringify([type, half, part, text.trim()]);
    const keys = keysRef.current!;
    let key = keys.get(signature);
    if (!key) {
      key = crypto.randomUUID();
      keys.set(signature, key);
    }
    setOperationKey(key);
  }

  function handleTypeChange(event: ChangeEvent<HTMLSelectElement>) {
    setLeaveTypeId(event.target.value);
    setHalfDay(false);
    setHalfDayPart('');
    updateIntent(event.target.value, false, '', reason);
  }

  function handleHalfDayChange(event: ChangeEvent<HTMLInputElement>) {
    const checked = event.target.checked;
    setHalfDay(checked);
    setHalfDayPart(checked && partChoices ? 'first' : '');
    updateIntent(leaveTypeId, checked, checked && partChoices ? 'first' : '', reason);
  }

  function handlePartChange(event: ChangeEvent<HTMLSelectElement>) {
    const value = event.target.value;
    setHalfDayPart(value === 'first' || value === 'second' ? value : '');
    updateIntent(leaveTypeId, halfDay, value === 'first' || value === 'second' ? value : '', reason);
  }

  if (submitState.requestId) return <div className="success-panel" role="status">
    <h2>تم تسجيل طلب الإجازة</h2>
    <p>افتح الطلب لمراجعة حالته الحالية. الاعتماد خطوة منفصلة بصلاحية اعتماد الإجازات.</p>
    <div className="workspace-form-actions">
      <PendingLink className="primary-button" href={detailHref(tenantId, submitState.requestId)}>فتح الطلب</PendingLink>
      <button type="button" className="secondary-button" onClick={() => window.location.reload()}>تسجيل طلب آخر</button>
    </div>
  </div>;

  const showOfflineNotice = offline && !submitting && draftReady && types.length > 0;

  return <div className={styles.formBlock}>
    <h2 className={styles.formTitle}>بيانات طلب الإجازة</h2>
    <form className="auth-form" action={submitAction} aria-busy={submitting} onSubmit={(event) => { blockOfflineSubmission(event); }}>
      <fieldset key={submitState.attempt} disabled={!draftReady || submitting} style={{ display: 'grid', gap: '.65rem', border: 0, padding: 0, margin: 0, minWidth: 0 }}>
      <input type="hidden" name="tenantId" value={tenantId} />
      <input type="hidden" name="q" value={q} />
      <input type="hidden" name="employee" value={employee.employeeId} />
      <input type="hidden" name="employment" value={employee.employmentId} />
      <input type="hidden" name="startDate" value={startDate} />
      <input type="hidden" name="endDate" value={endDate} />
      <input type="hidden" name="halfDay" value={halfDay ? 'true' : 'false'} />
      <input type="hidden" name="halfDayPart" value={halfDayPart} />
      <input type="hidden" name="operationKey" value={operationKey} />

      <label htmlFor="leave-type">نوع الإجازة</label>
      <select id="leave-type" name="leaveTypeId" value={leaveTypeId} onChange={handleTypeChange} disabled={submitting} required>
        <option value="" disabled>اختر نوع الإجازة</option>
        {leaveTypeId && !selectedType && <option value={leaveTypeId}>النوع المحفوظ لم يعد ضمن الخيارات المتاحة</option>}
        {types.map((type) => <option key={type.id} value={type.id}>{type.name}</option>)}
      </select>
      <p className="field-hint">الفترة المختارة: <bdi>{startDate}</bdi> إلى <bdi>{endDate}</bdi>
        {' · '}{dayCount(startDate, endDate)} يومًا. أيام الإجازة المحتسبة تحددها سياسة نوع الإجازة وتقويم الجهة.</p>

      {halfDayBlocked
        ? <p className="form-message" role="status">
          تعذر تحميل إعدادات نصف اليوم لهذا التاريخ. أعد تحميل الخيارات قبل تسجيل إجازة مدتها نصف يوم.
          <button type="button" className="secondary-button" onClick={() => window.location.reload()}>إعادة تحميل الخيارات</button>
        </p>
        : singleDate && selectedType === null
          ? <p className="field-hint" role="status">اختر نوع الإجازة لعرض خيار نصف يوم إن كان متاحًا في هذا اليوم.</p>
          : singleDate && !halfDayAvailable
            ? <p className="field-hint" role="status">نوع الإجازة المحدد لا يسمح بنصف يوم في هذا التاريخ.</p>
            : !singleDate
              ? <p className="field-hint" role="status">تسجيل نصف يوم متاح عندما يكون تاريخ البداية والنهاية متطابقين.</p>
              : null}
      {singleDate && (halfDay || (!halfDayBlocked && halfDayAvailable)) && <label className="check-option">
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
      <textarea id="leave-reason" name="reason" value={reason} onChange={(event) => {
        setReason(event.target.value);
        updateIntent(leaveTypeId, halfDay, halfDayPart, event.target.value);
      }}
        disabled={submitting} required minLength={MIN_REASON_LENGTH} maxLength={MAX_REASON_LENGTH}
        aria-invalid={Boolean(submitState.error)} />
      {submitState.error && <p key={submitState.attempt} className="form-message form-error" role="alert">
        {submitState.error}
      </p>}
      {submitting && <p className="field-hint" role="status">جارٍ تسجيل الطلب… لا تغلق الصفحة.</p>}

      <div className="workspace-form-actions">
        <SubmitButton disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} label="تسجيل الطلب" pendingLabel="جارٍ التسجيل…" />
        {submitting ? <span className="secondary-button" aria-disabled="true">إلغاء</span>
          : <PendingLink className="secondary-button" href={cancelHref}>إلغاء</PendingLink>}
      </div>
      <p className="field-hint">يُسجَّل الطلب بحالة «مُقدَّم وبانتظار القرار»، ولا يُحجز أي رصيد من رصيد الموظف قبل الاعتماد.</p>
      {storageUnavailable && <p className="field-hint" role="status">حفظ المسودة بعد تحديث الصفحة غير متاح في هذا المتصفح. عند تعذر تأكيد النتيجة، أعد المحاولة من هذه الصفحة دون تحديثها.</p>}
      </fieldset>
      {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose="continuation" />}
    </form>
  </div>;
}
