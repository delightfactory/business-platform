'use client';

import { useId, type ComponentProps } from 'react';
import { useFormStatus } from 'react-dom';
import { SubmitButton } from './submit-button';
import { OfflineSubmissionNotice, useOfflineSubmission } from './offline-submission';

/** Pair only with a reviewed owning form's submit-time offline guard. */
export function OfflineSubmitButton(props: ComponentProps<typeof SubmitButton>) {
  const { offline } = useOfflineSubmission();
  const { pending } = useFormStatus();
  const hintId = useId();
  const showNotice = offline && !pending && !props.disabled;
  const describedBy = [props.ariaDescribedBy, showNotice ? hintId : undefined].filter(Boolean).join(' ') || undefined;
  return <>
    <SubmitButton {...props} disabled={offline || props.disabled} ariaDescribedBy={describedBy} />
    {showNotice && <OfflineSubmissionNotice id={hintId} purpose="continuation" />}
  </>;
}
