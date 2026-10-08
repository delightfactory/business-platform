'use client';

import { useFormStatus } from 'react-dom';

export function SubmitButton({ label, pendingLabel, className = 'primary-button', ariaLabel, ariaDescribedBy, disabled = false }: {
  label: string;
  pendingLabel?: string;
  className?: string;
  ariaLabel?: string;
  ariaDescribedBy?: string;
  disabled?: boolean;
}) {
  const { pending } = useFormStatus();
  return <button className={className} type="submit" disabled={pending || disabled} aria-busy={pending} aria-label={ariaLabel} aria-describedby={ariaDescribedBy}>
    {pending && <span className="button-spinner" aria-hidden="true" />}
    {pending ? pendingLabel ?? 'جارٍ التنفيذ…' : label}
  </button>;
}
