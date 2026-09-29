'use client';

import { useState, useTransition, type FormEvent, type ReactNode } from 'react';

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

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setError(null);
    startTransition(async () => {
      const result = await action(formData);
      if (result) setError(errorMessages[result] ?? 'تعذر إتمام الإجراء. راجع البيانات وحاول مجددًا.');
    });
  }

  return <form onSubmit={submit} className={className} aria-busy={pending}>
    {children}
    {error && <p className="form-message form-error" role="alert">{error}</p>}
    <button className={buttonClassName} type="submit" disabled={pending} aria-busy={pending}>
      {pending && <span className="button-spinner" aria-hidden="true" />}
      {pending ? pendingLabel : label}
    </button>
  </form>;
}
