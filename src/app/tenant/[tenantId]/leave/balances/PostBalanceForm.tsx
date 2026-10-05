'use client';

import { useActionState, useEffect, useRef, useState, type ChangeEvent } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { isObject, isUuid } from '../rules';
import { PendingLink } from '../pending-link';
import { postBalanceAction } from './actions';
import {
  EMPTY_POST_STATE,
  MAX_REASON,
  MAX_SOURCE_LENGTH,
  MIN_REASON,
  MIN_SOURCE_LENGTH,
  ledgerHref,
  postingKindSummary,
  type PostingKind,
  type PostingType,
} from './rules';
import styles from '../review.module.css';

type Draft = {
  version: 1;
  savedAt: number;
  operationKey: string;
  typeVersion: string;
  typeVersionNumber: number;
  delta: string;
  reason: string;
  source: string;
};

function isDraft(value: unknown): value is Draft {
  if (!isObject(value) || value.version !== 1 || typeof value.savedAt !== 'number'
    || !Number.isFinite(value.savedAt) || Date.now() < value.savedAt) return false;
  if (!isUuid(value.operationKey) || !isUuid(value.typeVersion)) return false;
  if (typeof value.typeVersionNumber !== 'number' || !Number.isInteger(value.typeVersionNumber)
    || value.typeVersionNumber < 1) return false;
  if (typeof value.delta !== 'string' || value.delta.length > 40
    || typeof value.reason !== 'string' || value.reason.length > MAX_REASON
    || typeof value.source !== 'string' || value.source.length > MAX_SOURCE_LENGTH) return false;
  return true;
}

export function PostBalanceForm({ tenantId, actorId, employeeId, employerId, kind, periodId, periodLabel,
  type, initialIntentKey, cancelHref, backHref }: {
  tenantId: string;
  actorId: string;
  employeeId: string;
  employerId: string;
  kind: PostingKind;
  periodId: string;
  periodLabel: string;
  type: PostingType;
  initialIntentKey: string;
  cancelHref: string;
  backHref: string;
}) {
  const [delta, setDelta] = useState('');
  const [reason, setReason] = useState('');
  const [source, setSource] = useState('');
  const [typeVersionOverride, setTypeVersionOverride] = useState<string | null>(null);
  const [typeVersionNumber, setTypeVersionNumber] = useState<number | null>(null);
  const [operationKey, setOperationKey] = useState(initialIntentKey);
  const [draftReady, setDraftReady] = useState(false);
  const [storageUnavailable, setStorageUnavailable] = useState(false);
  const storageKey = ['leave.hr.balance.post.v1', actorId, tenantId, employeeId, employerId, periodId,
    kind, type.leaveTypeId].join(':');
  const typeVersion = typeVersionOverride ?? type.typeVersionId;
  const keysRef = useRef<Map<string, string> | null>(null);
  if (keysRef.current === null) {
    keysRef.current = new Map([[JSON.stringify([type.typeVersionId, '', '', '']), initialIntentKey]]);
  }
  const [submitState, submitAction, submitting] = useActionState(postBalanceAction, EMPTY_POST_STATE);

  const staleVersion = typeVersionOverride !== null && typeVersionOverride !== type.typeVersionId;

  useEffect(() => {
    const frame = requestAnimationFrame(() => {
      try {
        const raw = sessionStorage.getItem(storageKey);
        const draft: unknown = raw ? JSON.parse(raw) : null;
        if (isDraft(draft)) {
          setTypeVersionOverride(draft.typeVersion);
          setTypeVersionNumber(draft.typeVersionNumber);
          setDelta(draft.delta);
          setReason(draft.reason);
          setSource(draft.source);
          setOperationKey(draft.operationKey);
          keysRef.current?.set(
            JSON.stringify([draft.typeVersion, draft.delta.trim(), draft.reason.trim(), draft.source.trim()]),
            draft.operationKey,
          );
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
      if (submitState.accountId) {
        sessionStorage.removeItem(storageKey);
        keysRef.current?.clear();
      } else {
        sessionStorage.setItem(storageKey, JSON.stringify({
          version: 1, savedAt: Date.now(), operationKey, typeVersion, typeVersionNumber, delta, reason, source,
        }));
      }
    } catch { errorFrame = requestAnimationFrame(() => setStorageUnavailable(true)); }
    return () => { if (errorFrame !== undefined) cancelAnimationFrame(errorFrame); };
  }, [draftReady, storageKey, operationKey, typeVersion, typeVersionNumber, delta, reason, source,
    submitState.accountId]);

  // The intent key is random per distinct payload and never derived from content, so an
  // unresolved attempt keeps its key while any edit produces a genuinely new one.
  function updateIntent(nextVersion: string, nextDelta: string, nextReason: string, nextSource: string) {
    const signature = JSON.stringify([nextVersion, nextDelta.trim(), nextReason.trim(), nextSource.trim()]);
    const keys = keysRef.current!;
    let key = keys.get(signature);
    if (!key) {
      key = crypto.randomUUID();
      keys.set(signature, key);
    }
    setOperationKey(key);
  }

  function handleDeltaChange(event: ChangeEvent<HTMLInputElement>) {
    setDelta(event.target.value);
    updateIntent(typeVersion, event.target.value, reason, source);
  }

  function handleReasonChange(event: ChangeEvent<HTMLTextAreaElement>) {
    setReason(event.target.value);
    updateIntent(typeVersion, delta, event.target.value, source);
  }

  function handleSourceChange(event: ChangeEvent<HTMLInputElement>) {
    setSource(event.target.value);
    updateIntent(typeVersion, delta, reason, event.target.value);
  }

  if (submitState.accountId) {
    return <div className="success-panel" role="status">
      <h2>{submitState.replay ? 'القيد مسجّل مسبقًا بنفس المفتاح' : 'تم تسجيل قيد الرصيد'}</h2>
      <p>{submitState.replay
        ? 'نُفّذ هذا القيد سابقًا بالمفتاح والبيانات نفسها، فعُرضت النتيجة المؤكدة دون تسجيل قيد ثانٍ.'
        : 'أُضيف القيد إلى دفتر الحساب وحُدِّث رصيد الحساب كاملًا.'}</p>
      <details className="task-disclosure">
        <summary className="secondary-button">معرّفات القيد</summary>
        <p className="record-meta">معرّف الحساب: <bdi>{submitState.accountId}</bdi></p>
        <p className="record-meta">معرّف القيد في الدفتر: <bdi>{submitState.entryId}</bdi></p>
      </details>
      <div className="workspace-form-actions">
        <PendingLink className="primary-button" href={ledgerHref(tenantId, submitState.accountId, {
          employee: employeeId, employer: employerId,
        })}>فتح سجل حساب هذا القيد</PendingLink>
        <PendingLink className="secondary-button" href={backHref}>العودة إلى أرصدة الموظف</PendingLink>
        <button type="button" className="secondary-button" onClick={() => window.location.reload()}>
          تحديث الأرصدة المعروضة
        </button>
      </div>
    </div>;
  }

  return <div className={styles.formBlock}>
    <h2 className={styles.formTitle}>بيانات قيد الرصيد</h2>
    <form className="auth-form" action={submitAction} aria-busy={submitting}>
      <fieldset key={submitState.attempt} disabled={!draftReady || submitting}
        style={{ display: 'grid', gap: '.65rem', border: 0, padding: 0, margin: 0, minWidth: 0 }}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="employee" value={employeeId} />
        <input type="hidden" name="employer" value={employerId} />
        <input type="hidden" name="kind" value={kind} />
        <input type="hidden" name="period" value={periodId} />
        <input type="hidden" name="type" value={type.leaveTypeId} />
        <input type="hidden" name="typeVersion" value={typeVersion} />
        <input type="hidden" name="operationKey" value={operationKey} />

        <label htmlFor="balance-delta">عدد الأيام</label>
        <input id="balance-delta" name="delta" type="text" inputMode="decimal" maxLength={40}
          value={delta} onChange={handleDeltaChange} disabled={submitting} required
          aria-describedby="balance-delta-hint" aria-invalid={submitState.error !== ''} />
        <p className="field-hint" id="balance-delta-hint">{postingKindSummary(kind)}</p>

        <label htmlFor="balance-reason">سبب القيد</label>
        <textarea id="balance-reason" name="reason" value={reason} onChange={handleReasonChange}
          disabled={submitting} required minLength={MIN_REASON} maxLength={MAX_REASON}
          aria-invalid={submitState.error !== ''} />
        <p className="field-hint">يُحفظ السبب في سجل القيد ولا يمكن تعديله لاحقًا.</p>

        <label htmlFor="balance-source">مرجع التدقيق اليدوي</label>
        <input id="balance-source" name="source" type="text" value={source} onChange={handleSourceChange}
          disabled={submitting} required minLength={MIN_SOURCE_LENGTH} maxLength={MAX_SOURCE_LENGTH}
          aria-invalid={submitState.error !== ''} />
        <p className="field-hint">مرجع داخلي تكتبه مثل رقم خطاب أو محضر. لا يُستخدم لاستخراج أي معرّف من النص.</p>

        <p className="field-hint">النوع: {type.name} · رقم النوع <bdi>{type.code}</bdi>
          {periodLabel === '' ? '' : <> · الفترة: {periodLabel}</>}
          {' · '}النسخة السياسية {type.typeVersion} سارية من <bdi>{type.effectiveFrom}</bdi>
          {type.effectiveUntil ? <> إلى <bdi>{type.effectiveUntil}</bdi></> : ' دون تاريخ انتهاء'}
          {' · '}تاريخ الاستحقاق: <bdi>{type.policyDate}</bdi> · المصدر: {type.policySource}</p>
        {staleVersion && <p className="form-message" role="status">
          مسودتك المحفوظة مرتبطة بنسخة سياسة مختلفة عن المعروضة الآن
          {typeVersionNumber !== null ? ` (إصدار ${typeVersionNumber})` : ''}.
          سيُرسَل معرّف النسخة المحفوظة كما هو، والأمر هو المرجع في التحقق من التكرار قبل التحقق من النسخة الحالية.
        </p>}

        {submitState.error && <p key={submitState.attempt} className="form-message form-error" role="alert">
          {submitState.error}
        </p>}
        {submitting && <p className="field-hint" role="status">جارٍ تسجيل القيد… لا تغلق الصفحة.</p>}

        <div className="workspace-form-actions">
          <SubmitButton label="تسجيل القيد" pendingLabel="جارٍ التسجيل…" />
          {submitting ? <span className="secondary-button" aria-disabled="true">إلغاء</span>
            : <PendingLink className="secondary-button" href={cancelHref}>إلغاء</PendingLink>}
        </div>
        {storageUnavailable && <p className="field-hint" role="status">
          حفظ المسودة بعد تحديث الصفحة غير متاح في هذا المتصفح. عند تعذر تأكيد النتيجة، أعد المحاولة من هذه
          الصفحة دون تحديثها مع الحفاظ على السبب والمرجع والقدر نفسها.
        </p>}
      </fieldset>
    </form>
  </div>;
}
