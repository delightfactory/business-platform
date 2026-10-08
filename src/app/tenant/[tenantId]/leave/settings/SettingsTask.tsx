'use client';

import { useId, type ReactNode } from 'react';

export function SettingsTask({ label, className = 'task-disclosure', children }: {
  label: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  const hintId = useId();
  return <details className={className} onToggle={(event) => {
    const disclosure = event.currentTarget;
    if (!disclosure.open && disclosure.querySelector('form[aria-busy="true"]')) disclosure.open = true;
  }}>
    <summary className="secondary-button" aria-describedby={hintId} onClick={(event) => {
      if (event.currentTarget.parentElement?.querySelector('form[aria-busy="true"]')) event.preventDefault();
    }}>{label}</summary>
    <p id={hintId} className="field-hint">يمكن إغلاق هذا القسم مع الاحتفاظ بالمدخلات. أثناء الحفظ يظل مفتوحًا حتى تظهر النتيجة.</p>
    {children}
  </details>;
}
