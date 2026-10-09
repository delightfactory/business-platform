'use client';
import { Message } from '@/components/ui';
import { Button } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useRef, useState, useSyncExternalStore, useTransition, type FormEvent, type ReactNode } from 'react';
import { onboardTenantAction, readOnboardingAttemptAction } from '@/app/operator/actions';
import { matchingOnboardingSnapshot, onboardingIntent, type OnboardingOutcome } from './intent';
import { OnboardingResult } from './OnboardingResult';

const subscribe = () => () => {};
const clientReady = () => true;
const serverReady = () => false;
type Phase = 'editing' | 'unknown' | 'retry' | 'saved';

const messages: Record<OnboardingOutcome['state'], string> = {
  saved: 'تم تأكيد إعداد الشركة.',
  invalid: 'تحقق من الأسماء والبريد وحدود المستخدمين والفروع. استخدم عددًا موجبًا أو اختر غير محدود.',
  admin: 'تحقق من وجود حساب المسؤول وتأكيد بريده وتفعيل الحساب، ثم صحح البيانات بنفس المرجع.',
  unknown: 'نتيجة الإعداد غير مؤكدة. احتفظ بهذه الصفحة وراجع المحاولة الأصلية قبل أي إرسال آخر.',
  unavailable: 'تعذر التحقق الآن. احتفظ بالبيانات وراجع المحاولة الأصلية إذا سبق إرسالها.',
  'actor-changed': 'المحاولة مرتبطة بالحساب الذي بدأها. ارجع إلى الحساب الأصلي ثم راجع النتيجة؛ لا تُرسلها من حساب آخر.',
  forbidden: 'لم تسمح صلاحيتك الحالية بإعداد الشركات. استعد الصلاحية للحساب الأصلي ثم راجع المحاولة.',
  conflict: 'مرجع المحاولة مرتبط ببيانات مختلفة. راجع النتيجة الأصلية؛ لا تبدأ مرجعًا جديدًا لتجاوز التعارض.',
  absent: 'لم تُرجع القراءة نتيجة محفوظة لهذا الحساب الآن. هذا لا يثبت أن الإعداد لم يحدث؛ يمكنك إعادة إرسال البيانات الأصلية نفسها فقط.',
};

export function OnboardingForm({ actorId, requestKey, children }: { actorId: string; requestKey: string; children: ReactNode }) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHint0 = useId();
 const offlineRecoveryHint = useId();
  const [scope] = useState(() => ({ actorId, requestKey }));
  const captured = useRef<FormData | null>(null);
  const inFlight = useRef(false);
  const ready = useSyncExternalStore(subscribe, clientReady, serverReady);
  const [pending, startTransition] = useTransition();
  const [phase, setPhase] = useState<Phase>('editing');
  const [outcome, setOutcome] = useState<OnboardingOutcome | null>(null);
  const [hasAttempt, setHasAttempt] = useState(false);
  const actorChanged = actorId.toLowerCase() !== scope.actorId.toLowerCase();
  const frozen = phase !== 'editing' || actorChanged || outcome?.state === 'actor-changed' || outcome?.state === 'forbidden' || outcome?.state === 'conflict';

  function dispatch(operation: 'save' | 'read' | 'retry', form?: HTMLFormElement) {
  if (blockOfflineSubmission()) return;
    if (!ready || pending || inFlight.current || phase === 'saved') return;
    if (operation === 'save') {
      if (frozen || !form) return;
      const payload = new FormData(form);
      payload.set('idempotencyKey', scope.requestKey);
      if (!onboardingIntent(payload)) { setOutcome({ state: 'invalid', mutationDispatched: false }); return; }
      captured.current = payload; setHasAttempt(true);
    } else if (!captured.current || (operation === 'retry' && (phase !== 'retry' || actorChanged))) return;
    const original = captured.current;
    if (!original) return;
    // Never rebuild replay from disabled fields, changed props, or edited DOM.
    const payload = new FormData();
    original.forEach((value, key) => payload.append(key, value));
    const priorFrozen = frozen;
    inFlight.current = true;
    startTransition(async () => {
      try {
        const result = operation === 'read'
          ? await readOnboardingAttemptAction(scope.actorId, payload)
          : await onboardTenantAction(scope.actorId, payload);
        const intent = onboardingIntent(original);
        if (result.state === 'saved') {
          if (intent && matchingOnboardingSnapshot(result.snapshot, intent)) {
            setOutcome(result); setPhase('saved'); captured.current = null; setHasAttempt(false);
          } else { setOutcome({ state: 'unknown', mutationDispatched: true }); setPhase('unknown'); }
        } else if (operation === 'read') {
          setOutcome(result); setPhase(result.state === 'absent' ? 'retry' : 'unknown');
        } else if ((result.state === 'invalid' || result.state === 'admin') && (result.mutationDispatched || !priorFrozen)) {
          setOutcome(result); setPhase('editing'); captured.current = null; setHasAttempt(false);
        } else if (!result.mutationDispatched && !priorFrozen) {
          setOutcome(result); setPhase('editing');
        } else { setOutcome(result); setPhase('unknown'); }
      } catch {
        // The client cannot infer whether an interrupted action reached the server.
        setOutcome({ state: 'unknown', mutationDispatched: true }); setPhase('unknown');
      } finally { inFlight.current = false; }
    });
  }

  function submit(event: FormEvent<HTMLFormElement>) {
  if (blockOfflineSubmission(event)) return; event.preventDefault(); dispatch('save', event.currentTarget); }

  if (phase === 'saved' && outcome?.snapshot) return <OnboardingResult result={outcome.snapshot} />;
  const showOffline0 = offline && ready && !pending && !frozen;
 const showOfflineRecovery = offline && ready && !pending && frozen && hasAttempt;
 return <div>
    <form method="post" className="auth-form onboarding-form" onSubmit={submit} aria-busy={pending}>
      {!ready && <p className="field-hint" role="status">الحفظ غير جاهز بعد. يتطلب الإرسال تفعيل JavaScript.</p>}
      <noscript><p className="field-hint">يمكنك مراجعة الحالة الحالية دون حفظ؛ الإرسال يتطلب تفعيل JavaScript.</p></noscript>
      <fieldset className="operator-action-fields" disabled={!ready || pending || frozen} aria-label="إنشاء الشركة">
        <input type="hidden" name="idempotencyKey" value={scope.requestKey} />
        {children}
        {!frozen && <Button variant="solid" type="submit"  disabled={offline || (!ready || pending)} aria-describedby={showOffline0 ? offlineHint0 : undefined}>{pending ? 'جارٍ إنشاء الشركة…' : 'إنشاء الشركة'}</Button>}
      </fieldset>
    {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>
    {actorChanged && <Message tone="bad"  role="alert">{messages['actor-changed']}</Message>}
    {outcome && <Message tone="info"  role={outcome.state === 'absent' ? 'status' : 'alert'}>{messages[outcome.state]}</Message>}
    {pending && <Message tone="info" role="status" >جارٍ التحقق من المحاولة…</Message>}
    {frozen && hasAttempt && <div className="topbar-actions">
      {phase === 'retry' && !actorChanged && <Button variant="solid" type="button"  disabled={offline || (!ready || pending)} onClick={() => dispatch('retry')} aria-describedby={showOfflineRecovery ? offlineRecoveryHint : undefined}>إعادة إرسال البيانات الأصلية</Button>}
      <Button variant="ghost" type="button" className={phase === 'retry' && !actorChanged ? 'secondary-button' : 'primary-button'} disabled={offline || (!ready || pending)} onClick={() => dispatch('read')} aria-describedby={showOfflineRecovery ? offlineRecoveryHint : undefined}>مراجعة نتيجة المحاولة</Button>
    </div>}
    {showOfflineRecovery && <OfflineSubmissionNotice id={offlineRecoveryHint} purpose="recovery" />}
    {frozen && <p className="field-hint">البيانات الأصلية محفوظة في هذه الصفحة فقط. لا تغلقها أو تعيد تحميلها قبل حسم النتيجة؛ لا تُحفظ بيانات المحاولة على الجهاز.</p>}
  </div>;
}
