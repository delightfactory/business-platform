'use client';

import { useFormStatus } from 'react-dom';
import { Button, type ButtonVariant } from './ui/primitives';

export function SubmitButton({ label, pendingLabel, className = 'primary-button', ariaLabel, ariaDescribedBy, disabled = false, variant: requestedVariant }: {
  label: string;
  pendingLabel?: string;
  className?: string;
  ariaLabel?: string;
  ariaDescribedBy?: string;
  disabled?: boolean;
  variant?: ButtonVariant;
}) {
  const { pending } = useFormStatus();
  const variant = requestedVariant ?? (className.includes('danger-button') ? 'danger' : className.includes('secondary-button') ? 'ghost' : 'solid');
  const surfaceClass = className.replace(/\b(primary-button|secondary-button|danger-button)\b/g, '').trim();
  return <Button className={surfaceClass} variant={variant} type="submit" disabled={pending || disabled} pending={pending} pendingLabel={pendingLabel ?? 'جارٍ التنفيذ…'} aria-busy={pending} aria-label={ariaLabel} aria-describedby={ariaDescribedBy}>{label}</Button>;
}
