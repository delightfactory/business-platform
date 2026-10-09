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
  const isButton = /primary-button|secondary-button|danger-button|back-link|ui-button/.test(className ?? '');
  const variant = className?.includes('danger') ? 'danger' : className?.includes('primary') || className?.includes('solid') ? 'solid' : 'ghost';
  if (isButton) return <ButtonLink href={href} variant={variant} aria-label={ariaLabel}>
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
