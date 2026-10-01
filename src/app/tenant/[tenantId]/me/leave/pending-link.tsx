'use client';

import Link, { useLinkStatus } from 'next/link';
import type { ReactNode } from 'react';

export function PendingLink({ href, className, children, ariaLabel }: {
  href: string;
  className?: string;
  children: ReactNode;
  ariaLabel?: string;
}) {
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
