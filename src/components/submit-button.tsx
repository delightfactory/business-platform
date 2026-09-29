'use client';

import { useFormStatus } from 'react-dom';

export function SubmitButton({ label, pendingLabel, className = 'primary-button' }: {
  label: string;
  pendingLabel?: string;
  className?: string;
}) {
  const { pending } = useFormStatus();
  return <button className={className} type="submit" disabled={pending} aria-busy={pending}>
    {pending && <span className="button-spinner" aria-hidden="true" />}
    {pending ? pendingLabel ?? 'جارٍ التنفيذ…' : label}
  </button>;
}
