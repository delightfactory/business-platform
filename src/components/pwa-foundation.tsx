'use client';

import { useEffect, useSyncExternalStore } from 'react';

function subscribe(listener: () => void) {
  window.addEventListener('online', listener);
  window.addEventListener('offline', listener);
  return () => {
    window.removeEventListener('online', listener);
    window.removeEventListener('offline', listener);
  };
}

export function PwaFoundation() {
  const online = useSyncExternalStore(subscribe, () => navigator.onLine, () => true);
  useEffect(() => {
    if (process.env.NODE_ENV !== 'production' || !window.isSecureContext || !('serviceWorker' in navigator)) return;
    void navigator.serviceWorker.register('/sw.js', { scope: '/', updateViaCache: 'none' }).catch(() => {
      // Installation is optional; failure never changes business forms or retries their operations.
    });
  }, []);
  return online ? null : <aside className="pwa-offline-notice" role="status">
    الجهاز يبلغ أن الاتصال منقطع. قد لا تصل عمليات الإرسال؛ تحقق من نتيجة أي عملية لم تتأكد قبل تكرارها.
  </aside>;
}
