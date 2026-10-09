'use client';

import { useId, type ReactNode } from 'react';
import { Icon } from '@/components/ui';
import styles from '../people-management.module.css';

export function PolicyTask({ label, className, children }: { label: string; className?: string; children: ReactNode }) {
  const hintId = useId();
  return <details className={`ui-disclosure ${className ?? ''}`} onToggle={(event) => {
    const disclosure = event.currentTarget;
    if (!disclosure.open && disclosure.querySelector('form[aria-busy="true"]')) disclosure.open = true;
  }}>
    <summary className={styles.taskSummary} aria-describedby={hintId} onClick={(event) => {
      if (event.currentTarget.parentElement?.querySelector('form[aria-busy="true"]')) event.preventDefault();
    }}>{label}<Icon name="chevronDown" size={18} /></summary>
    <p id={hintId} className="field-hint">يمكن إغلاق هذا القسم مع الاحتفاظ بالمدخلات. أثناء الحفظ يظل مفتوحًا حتى تظهر النتيجة.</p>
    {children}
  </details>;
}
