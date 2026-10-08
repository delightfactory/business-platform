'use client';

import type { ComponentProps } from 'react';
import { useOfflineSubmission } from './offline-submission';

/** Opt in only for a reviewed connection-dependent action; GET and sign-out keep their own contracts. */
export function OfflineForm({ onSubmit, ...props }: ComponentProps<'form'>) {
  const { blockOfflineSubmission } = useOfflineSubmission();
  return <form {...props} onSubmit={(event) => {
    if (blockOfflineSubmission(event)) return;
    onSubmit?.(event);
  }} />;
}
