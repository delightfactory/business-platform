'use client';
import { Button, Message, Textarea, Field } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState, useRef, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { commitClassificationAction, renewClassificationReview } from './classification-actions';
import type { ClassificationReview } from './classification';

export function ClassificationReviewForm({ tenantId, instanceId, review: initialReview }: {
  tenantId: string; instanceId: string; review: ClassificationReview;
}) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHint0 = useId();
  const [review, setReview] = useState(initialReview);
  const [reason, setReason] = useState('');
  const [state, action, pending] = useActionState(commitClassificationAction, { message: '', needsReview: false });
  const [reviewRenewed, setReviewRenewed] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [reviewMessage, setReviewMessage] = useState('');
  const [intent, setIntent] = useState(() => ({ signature: `${initialReview.plan_hash}:`, key: crypto.randomUUID() }));
  const keys = useRef(new Map([[intent.signature, intent.key]]));
  const stale = state.needsReview && !reviewRenewed;

  function changeReason(value: string) {
    setReason(value);
    const signature = `${review.plan_hash}:${value.trim()}`;
    const key = keys.current.get(signature) ?? crypto.randomUUID();
    keys.current.set(signature, key);
    setIntent({ signature, key });
  }

  async function renewReview() {
  if (blockOfflineSubmission()) return;
    setRefreshing(true);
    try {
      const result = await renewClassificationReview(tenantId, instanceId);
      setReviewMessage(result.message);
      if (result.review) {
        const signature = `${result.review.plan_hash}:${reason.trim()}`;
        const key = keys.current.get(signature) ?? crypto.randomUUID();
        keys.current.set(signature, key);
        setIntent({ signature, key });
        setReview(result.review); setReviewRenewed(true);
      }
    } catch { setReviewMessage('تعذر الاتصال. السبب محفوظ؛ أعد محاولة المراجعة.'); }
    finally { setRefreshing(false); }
  }

  const result = review.classification;
  const correction = review.expected_fact_id !== null;
  const showOffline0 = offline && !pending && !refreshing;
 return <form action={action} onSubmit={(event) => { if (blockOfflineSubmission(event)) return; setReviewRenewed(false); }} className="attendance-form attendance-approve-form">
    <input type="hidden" name="tenantId" value={tenantId} />
    <input type="hidden" name="instanceId" value={instanceId} />
    <input type="hidden" name="review" value={JSON.stringify(review)} />
    <input type="hidden" name="operationKey" value={intent.key} />
    <p className="attendance-full-field">{result.kind === 'leave_covered' ? 'اليوم مغطى بإجازة معتمدة، ولا يُحسب غيابًا.'
      : result.absence_units === 0.5 ? 'نصف يوم إجازة معتمد، والنصف المتبقي غياب بلا تسجيلات حضور.' : 'يوم غياب بلا تسجيلات حضور فعالة.'}</p>
    <p className="record-meta attendance-full-field">إجازة معتمدة: {result.leave_units} يوم · غياب: {result.absence_units} يوم</p>
    {result.diagnostics.includes('observed_work_during_excused') && <Message tone="info" className=" attendance-full-field">توجد تسجيلات عمل خلال الإجازة. ستبقى محفوظة: {result.observations.worked_minutes ?? '—'} دقيقة عمل.</Message>}
    <Field  id="classification-reason" label={<>{correction ? 'سبب تصحيح نتيجة اليوم' : 'سبب اعتماد نتيجة اليوم'}
      </>}><Textarea id="classification-reason" name="reason" value={reason} onChange={(event) => changeReason(event.target.value)}
        minLength={3} maxLength={500} required disabled={pending || refreshing} /></Field>
    {(reviewMessage || (state.message && !reviewRenewed)) && <Message tone="bad" className="  attendance-full-field" role="alert">{reviewMessage || state.message}</Message>}
    {stale ? <Button variant="solid" type="button"  disabled={offline || (pending || refreshing)} onClick={renewReview} aria-describedby={showOffline0 ? offlineHint0 : undefined}>{refreshing ? 'جارٍ مراجعة النتيجة...' : 'إعادة مراجعة النتيجة مع حفظ السبب'}</Button>
      : <SubmitButton  pendingLabel="جارٍ الاعتماد..." label={correction ? 'اعتماد التصحيح وحفظ النتيجة السابقة' : 'اعتماد نتيجة اليوم'}  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>}
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
