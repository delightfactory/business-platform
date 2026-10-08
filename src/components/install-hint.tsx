'use client';

import { useState, useSyncExternalStore } from 'react';

const DISMISSED = 'bp-install-hint-dismissed';
let installedHere = false;

function eligible() {
  if (installedHere || window.matchMedia('(display-mode: standalone)').matches
    || (navigator as Navigator & { standalone?: boolean }).standalone === true) return false;
  try { return localStorage.getItem(DISMISSED) !== '1'; } catch { return true; }
}

function subscribe(listener: () => void) {
  const media = window.matchMedia('(display-mode: standalone)');
  const onInstalled = () => { installedHere = true; listener(); };
  const onStorage = (event: StorageEvent) => { if (event.key === DISMISSED) listener(); };
  media.addEventListener('change', listener);
  window.addEventListener('appinstalled', onInstalled);
  window.addEventListener('storage', onStorage);
  return () => {
    media.removeEventListener('change', listener);
    window.removeEventListener('appinstalled', onInstalled);
    window.removeEventListener('storage', onStorage);
  };
}

export function InstallHint() {
  const visible = useSyncExternalStore(subscribe, eligible, () => false);
  const [dismissed, setDismissed] = useState(false);
  if (!visible || dismissed) return null;

  function dismiss() {
    setDismissed(true);
    try { localStorage.setItem(DISMISSED, '1'); } catch { /* Current-mount dismissal remains available. */ }
  }

  return <section className="workspace-records-panel install-hint" aria-labelledby="install-hint-title">
    <h2 id="install-hint-title">افتح المنصة من شاشة جهازك</h2>
    <p>من قائمة المتصفح اختر «تثبيت التطبيق» أو «إضافة إلى الشاشة الرئيسية».</p>
    <p>على <bdi>iPhone</bdi> أو <bdi>iPad</bdi>: افتح المنصة في <bdi>Safari</bdi>، ثم اختر «مشاركة» و«إضافة إلى الشاشة الرئيسية».</p>
    <p className="field-hint">التثبيت يضيف اختصارًا للمنصة؛ عرض البيانات وحفظ العمليات يحتاجان اتصالًا. إذا لم يظهر خيار التثبيت، تابع استخدام المنصة من المتصفح.</p>
    <button type="button" className="secondary-button" onClick={dismiss}>فهمت</button>
  </section>;
}
