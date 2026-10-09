'use client';
import { Button } from '@/components/ui';
import { Message } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useRef, useState, useSyncExternalStore, useTransition, type FormEvent, type ReactNode } from 'react';
import { unstable_rethrow } from 'next/navigation';

const subscribe = () => () => {};
const clientReady = () => true;
const serverReady = () => false;

type Props = {
  action: (formData: FormData) => Promise<string | void>;
  children: ReactNode;
  errorMessages: Record<string, string>;
  label: string;
  pendingLabel?: string;
  className?: string;
  buttonClassName?: string;
};

export function OperatorActionForm({ action, children, errorMessages, label, pendingLabel = 'جارٍ الحفظ…', className = 'auth-form', buttonClassName = 'primary-button' }: Props) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHint0 = useId();
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const ready = useSyncExternalStore(subscribe, clientReady, serverReady);
  const inFlight = useRef(false);

  function submit(event: FormEvent<HTMLFormElement>) {
  if (blockOfflineSubmission(event)) return;
    event.preventDefault();
    if (!ready || pending || inFlight.current) return;
    inFlight.current = true;
    const formData = new FormData(event.currentTarget);
    setError(null);
    startTransition(async () => {
      try {
        const result = await action(formData);
        if (result) setError(Object.hasOwn(errorMessages, result) ? errorMessages[result] : 'تعذر إتمام الإجراء. راجع البيانات وحاول مجددًا.');
      } catch (caught) {
        unstable_rethrow(caught);
        setError('نتيجة الإجراء غير مؤكدة. راجع الحالة الحالية قبل إجراء آخر.');
      } finally { inFlight.current = false; }
    });
  }

  const showOffline0 = offline && ready && !pending;
 return <form method="post" onSubmit={submit} className={className} aria-busy={pending}>
    {!ready && <p className="field-hint" role="status">الحفظ غير جاهز بعد. إذا استمر ذلك، فعّل JavaScript وأعد تحميل الصفحة.</p>}
    <noscript><p className="field-hint">الحفظ يتطلب تفعيل JavaScript؛ يمكنك مراجعة الحالة الحالية دون حفظ.</p></noscript>
    <fieldset className="operator-action-fields" disabled={!ready || pending} aria-label={label}>
    {children}
    {error && <Message tone="bad"  role="alert">{error}</Message>}
    <Button variant={buttonClassName.includes("danger") ? "danger" : buttonClassName.includes("secondary") ? "ghost" : "solid"} className={buttonClassName.replace(/\b(primary-button|secondary-button|danger-button)\b/g, "").trim()} type="submit" disabled={offline || (!ready || pending)} aria-busy={pending} aria-describedby={showOffline0 ? offlineHint0 : undefined}>
      {pending && <span className="button-spinner" aria-hidden="true" />}
      {pending ? pendingLabel : label}
    </Button>
    </fieldset>
  {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>;
}
