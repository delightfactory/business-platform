'use client';

import { Button, Disclosure, Field, Input, Message, Textarea } from '@/components/ui';
import { useActionState, useEffect, useId, useRef, useState, type ChangeEvent } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
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
  normalizeDelta,
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
  attempted: boolean;
};

function isDraft(value: unknown): value is Draft {
  if (!isObject(value) || value.version !== 1 || typeof value.savedAt !== 'number'
    || !Number.isFinite(value.savedAt)) return false;
  if (!isUuid(value.operationKey) || !isUuid(value.typeVersion) || typeof value.attempted !== 'boolean') return false;
  if (typeof value.typeVersionNumber !== 'number' || !Number.isInteger(value.typeVersionNumber)
    || value.typeVersionNumber < 1) return false;
  if (typeof value.delta !== 'string' || value.delta.length > 40
    || typeof value.reason !== 'string' || value.reason.length > MAX_REASON
    || typeof value.source !== 'string' || value.source.length > MAX_SOURCE_LENGTH) return false;
  return true;
}

function intentSignature(kind: PostingKind, version: string, amount: string, why: string, reference: string) {
  const normalized = normalizeDelta(amount, kind);
  return JSON.stringify([version, normalized.ok ? normalized.value : amount.trim(), why.trim(), reference.trim()]);
}

export function PostBalanceForm({ tenantId, actorId, employeeId, employerId, kind, periodId, periodLabel,
  type, leaveTypeId, initialIntentKey, cancelHref, backHref }: {
  tenantId: string;
  actorId: string;
  employeeId: string;
  employerId: string;
  kind: PostingKind;
  periodId: string;
  periodLabel: string;
  type: PostingType | null;
  leaveTypeId: string;
  initialIntentKey: string;
  cancelHref: string;
  backHref: string;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHintId = useId();
  const [delta, setDelta] = useState('');
  const [reason, setReason] = useState('');
  const [source, setSource] = useState('');
  const [typeVersionOverride, setTypeVersionOverride] = useState<string | null>(null);
  const [typeVersionNumber, setTypeVersionNumber] = useState<number | null>(type?.typeVersion ?? null);
  const [hasRecoveredDraft, setHasRecoveredDraft] = useState(false);
  const [attempted, setAttempted] = useState(false);
  const [unrecognizedDraft, setUnrecognizedDraft] = useState(false);
  const [operationKey, setOperationKey] = useState(initialIntentKey);
  const [draftReady, setDraftReady] = useState(false);
  const [storageUnavailable, setStorageUnavailable] = useState(false);
  const storageKey = ['leave.hr.balance.post.v1', actorId, tenantId, employeeId, employerId, periodId,
    kind, leaveTypeId].join(':');
  const typeVersion = typeVersionOverride ?? type?.typeVersionId ?? '';
  const canStartNew = type?.canPost === true;
  const keysRef = useRef<Map<string, string> | null>(null);
  const attemptedKeys = useRef(new Set<string>());
  if (keysRef.current === null) {
    keysRef.current = new Map([[JSON.stringify([type?.typeVersionId ?? '', '', '', '']), initialIntentKey]]);
  }
  const [submitState, submitAction, submitting] = useActionState(postBalanceAction, EMPTY_POST_STATE);

  const staleVersion = typeVersionOverride !== null && typeVersionOverride !== type?.typeVersionId;
  const unresolved = attempted && (submitState.attempt === 0 || submitState.uncertain);
  const showOfflineNotice = offline && draftReady && !submitting && !unrecognizedDraft && (canStartNew || hasRecoveredDraft);

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
          setHasRecoveredDraft(draft.attempted);
          setAttempted(draft.attempted);
          if (draft.attempted) attemptedKeys.current.add(draft.operationKey);
          keysRef.current?.set(
            intentSignature(kind, draft.typeVersion, draft.delta, draft.reason, draft.source),
            draft.operationKey,
          );
        } else if (raw) { setUnrecognizedDraft(true); }
      } catch { setStorageUnavailable(true); setUnrecognizedDraft(true); }
      setDraftReady(true);
    });
    return () => cancelAnimationFrame(frame);
  }, [storageKey, kind]);

  useEffect(() => {
    if (!draftReady || unrecognizedDraft) return;
    let errorFrame: number | undefined;
    try {
      if (submitState.accountId) {
        sessionStorage.removeItem(storageKey);
        keysRef.current?.clear();
        attemptedKeys.current.clear();
      } else {
        sessionStorage.setItem(storageKey, JSON.stringify({
          version: 1, savedAt: Date.now(), operationKey, typeVersion, typeVersionNumber, delta, reason, source, attempted: unresolved,
        }));
      }
    } catch { errorFrame = requestAnimationFrame(() => setStorageUnavailable(true)); }
    return () => { if (errorFrame !== undefined) cancelAnimationFrame(errorFrame); };
  }, [draftReady, storageKey, operationKey, typeVersion, typeVersionNumber, delta, reason, source,
    submitState.accountId, attempted, unresolved, unrecognizedDraft]);

  // The intent key is random per distinct payload and never derived from content, so an
  // unresolved attempt keeps its key while any edit produces a genuinely new one.
  function updateIntent(nextVersion: string, nextDelta: string, nextReason: string, nextSource: string) {
    const payloadSignature = intentSignature(kind, nextVersion, nextDelta, nextReason, nextSource);
    const keys = keysRef.current!;
    let key = keys.get(payloadSignature);
    if (!key) {
      key = crypto.randomUUID();
      keys.set(payloadSignature, key);
    }
    setOperationKey(key);
    setAttempted(attemptedKeys.current.has(key));
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
      <h2>{submitState.replay ? 'تم التحقق: القيد مسجّل بالفعل' : 'تم تسجيل قيد الرصيد'}</h2>
      <p>{submitState.replay
        ? 'هذه نتيجة العملية السابقة المؤكدة؛ لم يُسجّل القيد مرة أخرى.'
        : 'أُضيف القيد إلى دفتر الحساب وحُدِّث رصيد الحساب كاملًا.'}</p>
      <Disclosure  summary={<>معرّفات القيد</>}>
        <p className="record-meta">معرّف الحساب: <bdi>{submitState.accountId}</bdi></p>
        <p className="record-meta">معرّف القيد في الدفتر: <bdi>{submitState.entryId}</bdi></p>
      </Disclosure>
      <div className="workspace-form-actions">
        <PendingLink className="ui-button ui-button-solid ui-button-md" href={ledgerHref(tenantId, submitState.accountId, {
          employee: employeeId, employer: employerId,
        })}>فتح سجل حساب هذا القيد</PendingLink>
        <PendingLink className="ui-button ui-button-ghost ui-button-md" href={backHref}>العودة إلى أرصدة الموظف</PendingLink>
        <Button variant="ghost" type="button"  onClick={() => window.location.reload()}>
          تحديث الأرصدة المعروضة
        </Button>
      </div>
    </div>;
  }

  return <div className={styles.formBlock}>
    <h2 className={styles.formTitle}>بيانات قيد الرصيد</h2>
    {unrecognizedDraft && <Message tone="bad"  role="alert">
      توجد مسودة محفوظة لا يمكن قراءتها بهذا الإصدار. لم تُمسح. راجع سجل الحساب قبل مسحها وبدء محاولة جديدة.
    </Message>}
    <form className="auth-form" action={submitAction} aria-busy={submitting} onSubmit={(event) => {
      if (blockOfflineSubmission(event)) return;
      setAttempted(true);
      attemptedKeys.current.add(operationKey);
      try { sessionStorage.setItem(storageKey, JSON.stringify({
        version: 1, savedAt: Date.now(), operationKey, typeVersion, typeVersionNumber, delta, reason, source, attempted: true,
      })); } catch { setStorageUnavailable(true); }
    }}>
      <fieldset key={submitState.attempt} disabled={!draftReady || submitting || unrecognizedDraft || (!canStartNew && !hasRecoveredDraft)}
        style={{ display: 'grid', gap: '.65rem', border: 0, padding: 0, margin: 0, minWidth: 0 }}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="employee" value={employeeId} />
        <input type="hidden" name="employer" value={employerId} />
        <input type="hidden" name="kind" value={kind} />
        <input type="hidden" name="period" value={periodId} />
        <input type="hidden" name="type" value={leaveTypeId} />
        <input type="hidden" name="typeVersion" value={typeVersion} />
        <input type="hidden" name="operationKey" value={operationKey} />
        <input type="hidden" name="recovering" value={unresolved ? 'true' : 'false'} />

        <Field id="balance-delta" label={<>عدد الأيام</>} required><Input id="balance-delta" name="delta" type="text" inputMode="decimal" maxLength={40}
          value={delta} onChange={handleDeltaChange} disabled={submitting} readOnly={!canStartNew || unresolved} required
          aria-describedby="balance-delta-hint" aria-invalid={submitState.error !== ''} /></Field>
        <p className="field-hint" id="balance-delta-hint">{postingKindSummary(kind)}</p>

        <Field id="balance-reason" label={<>سبب القيد</>} required><Textarea id="balance-reason" name="reason" value={reason} onChange={handleReasonChange}
          disabled={submitting} readOnly={!canStartNew || unresolved} required minLength={MIN_REASON} maxLength={MAX_REASON}
          aria-invalid={submitState.error !== ''} /></Field>
        <p className="field-hint">يُحفظ السبب في سجل القيد ولا يمكن تعديله لاحقًا.</p>

        <Field id="balance-source" label={<>مرجع التدقيق اليدوي</>} required><Input id="balance-source" name="source" type="text" value={source} onChange={handleSourceChange}
          disabled={submitting} readOnly={!canStartNew || unresolved} required minLength={MIN_SOURCE_LENGTH} maxLength={MAX_SOURCE_LENGTH}
          aria-invalid={submitState.error !== ''} /></Field>
        <p className="field-hint">مرجع داخلي تكتبه مثل رقم خطاب أو محضر. لا يُستخدم لاستخراج أي معرّف من النص.</p>

        {type && <p className="field-hint">النوع: {type.name} · رقم النوع <bdi>{type.code}</bdi>
          {periodLabel === '' ? '' : <> · الفترة: {periodLabel}</>}
          {' · '}نسخة السياسة {type.typeVersion} سارية من <bdi>{type.effectiveFrom}</bdi>
          {type.effectiveUntil ? <> إلى <bdi>{type.effectiveUntil}</bdi></> : ' دون تاريخ انتهاء'}
          {' · '}تاريخ الاستحقاق: <bdi>{type.policyDate}</bdi> · المصدر: {type.policySource}</p>}
        {!canStartNew && <Message tone="info"  role="status">
          لا يتاح إنشاء قيد جديد بهذا الاختيار. إذا وُجدت محاولة محفوظة، يمكنك إعادة إرسالها كما هي للتحقق من نتيجتها.
        </Message>}
        {staleVersion && <Message tone="info"  role="status">
          مسودتك المحفوظة مرتبطة بنسخة سياسة مختلفة عن المعروضة الآن
          {typeVersionNumber !== null ? ` (إصدار ${typeVersionNumber})` : ''}.
          سنحتفظ ببيانات المحاولة السابقة للتحقق من نتيجتها دون تكرار القيد.
        </Message>}

        {submitState.error && <Message tone="bad" key={submitState.attempt}  role="alert">
          {submitState.error}
        </Message>}
        {submitting && <p className="field-hint" role="status">جارٍ تسجيل القيد… لا تغلق الصفحة.</p>}

        <div className="workspace-form-actions">
          <SubmitButton label={hasRecoveredDraft || attempted ? 'التحقق من نتيجة العملية السابقة' : canStartNew ? 'تسجيل القيد' : 'إعادة المحاولة المحفوظة'} pendingLabel="جارٍ التحقق والحفظ…"
            disabled={offline} ariaDescribedBy={showOfflineNotice ? offlineHintId : undefined} />
          {submitting ? <span className="ui-button ui-button-ghost ui-button-md" aria-disabled="true">إلغاء</span>
            : <PendingLink className="ui-button ui-button-ghost ui-button-md" href={cancelHref}>إلغاء</PendingLink>}
        </div>
        {storageUnavailable && <p className="field-hint" role="status">
          حفظ المسودة بعد تحديث الصفحة غير متاح في هذا المتصفح. عند تعذر تأكيد النتيجة، أعد المحاولة من هذه
          الصفحة دون تحديثها مع الحفاظ على السبب والمرجع والقدر نفسها.
        </p>}
      </fieldset>
      {showOfflineNotice && <OfflineSubmissionNotice id={offlineHintId} purpose={hasRecoveredDraft || attempted ? 'recovery' : 'submission'} />}
    </form>
    {unresolved && <Message tone="info"  role="status">نتيجة العملية السابقة غير مؤكدة. احتفظنا ببياناتها؛ تحقق من نتيجتها قبل تسجيل قيد آخر.</Message>}
    {draftReady && !submitting && !unresolved && !unrecognizedDraft && <Disclosure  summary={<>بدء محاولة جديدة</>}>
      <p>راجع سجل الحساب أولًا إذا كانت نتيجة المحاولة السابقة غير مؤكدة. هذا الإجراء يمسح بيانات المسودة لتسجيل قيد آخر.</p>
      <Button variant="ghost" type="button"  onClick={() => {
        try { sessionStorage.removeItem(storageKey); } catch { setStorageUnavailable(true); }
        setUnrecognizedDraft(false); setHasRecoveredDraft(false); setAttempted(false); setTypeVersionOverride(null); setTypeVersionNumber(type?.typeVersion ?? null);
        setDelta(''); setReason(''); setSource(''); keysRef.current?.clear(); attemptedKeys.current.clear(); setOperationKey(crypto.randomUUID());
      }}>مسح المسودة وبدء محاولة جديدة</Button>
    </Disclosure>}
  </div>;
}
