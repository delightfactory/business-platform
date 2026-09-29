'use client';

import { useFormStatus } from 'react-dom';

export function SubmitButton({ label, pendingLabel, className = 'primary-button', ariaLabel }: {
  label: string;
  pendingLabel?: string;
  className?: string;
  ariaLabel?: string;
}) {
  const { pending } = useFormStatus();
  return <button className={className} type="submit" disabled={pending} aria-busy={pending} aria-label={ariaLabel}>
    {pending && <span className="button-spinner" aria-hidden="true" />}
    {pending ? pendingLabel ?? 'جارٍ التنفيذ…' : label}
  </button>;
}
