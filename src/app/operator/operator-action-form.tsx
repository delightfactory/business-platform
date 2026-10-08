'use client';

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
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const ready = useSyncExternalStore(subscribe, clientReady, serverReady);
  const inFlight = useRef(false);

  function submit(event: FormEvent<HTMLFormElement>) {
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

  return <form method="post" onSubmit={submit} className={className} aria-busy={pending}>
    {!ready && <p className="field-hint" role="status">الحفظ غير جاهز بعد. إذا استمر ذلك، فعّل JavaScript وأعد تحميل الصفحة.</p>}
    <noscript><p className="field-hint">الحفظ يتطلب تفعيل JavaScript؛ يمكنك مراجعة الحالة الحالية دون حفظ.</p></noscript>
    <fieldset className="operator-action-fields" disabled={!ready || pending} aria-label={label}>
    {children}
    {error && <p className="form-message form-error" role="alert">{error}</p>}
    <button className={buttonClassName} type="submit" disabled={!ready || pending} aria-busy={pending}>
      {pending && <span className="button-spinner" aria-hidden="true" />}
      {pending ? pendingLabel : label}
    </button>
    </fieldset>
  </form>;
}
