'use client';

import { useReducer, useSyncExternalStore, type FormEvent } from 'react';

function deviceIsOffline() {
  return typeof navigator !== 'undefined' && navigator.onLine === false;
}

function subscribe(listener: () => void) {
  window.addEventListener('online', listener);
  window.addEventListener('offline', listener);
  return () => {
    window.removeEventListener('online', listener);
    window.removeEventListener('offline', listener);
  };
}

/** Opt in only at reviewed submission boundaries; an online signal is not service proof. */
export function useOfflineSubmission() {
  const offline = useSyncExternalStore(subscribe, deviceIsOffline, () => false);
  const [, refreshSignal] = useReducer((value: boolean) => !value, false);

  function blockOfflineSubmission(event?: FormEvent<HTMLFormElement>) {
    if (!deviceIsOffline()) return false;
    event?.preventDefault();
    // Re-read the snapshot even if submit raced the browser's connectivity event.
    refreshSignal();
    return true;
  }

  return { offline, blockOfflineSubmission };
}

export function OfflineSubmissionNotice({ id }: { id: string }) {
  return <p id={id} className="form-message" role="status">
    الجهاز يبلغ أن الاتصال منقطع. يمكنك مراجعة البيانات؛ أعد الاتصال ثم أرسل بنفسك.
  </p>;
}
