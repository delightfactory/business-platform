'use client';

import Link, { useLinkStatus } from 'next/link';
import type { ReactNode } from 'react';
import { ButtonLink } from '@/components/ui';

export function SettingsLink({ href, className, children, ariaLabel }: {
  href: string;
  className?: string;
  children: ReactNode;
  ariaLabel?: string;
}) {
  const classes = (className ?? '').split(/\s+/).filter(Boolean);
  const controls = new Set(['primary-button', 'secondary-button', 'danger-button', 'back-link', 'ui-button', 'ui-button-solid', 'ui-button-ghost', 'ui-button-danger', 'ui-button-md', 'ui-button-lg']);
  const isButton = classes.some(token => controls.has(token));
  const variant = classes.some(token => token === 'danger-button' || token === 'ui-button-danger') ? 'danger'
    : classes.some(token => token === 'primary-button' || token === 'ui-button-solid') ? 'solid' : 'ghost';
  const customClasses = classes.filter(token => !controls.has(token)).join(' ');
  if (isButton) return <ButtonLink href={href} variant={variant} size={classes.includes('ui-button-lg') ? 'lg' : 'md'} className={customClasses} aria-label={ariaLabel}>
    <PendingMarker />{children}
  </ButtonLink>;
  return <Link href={href} className={className} aria-label={ariaLabel}>
    <PendingMarker />
    {children}
  </Link>;
}

function PendingMarker() {
  const { pending } = useLinkStatus();
  if (!pending) return null;
  return <span className="button-spinner" role="status" aria-label="جارٍ التحميل" />;
}
