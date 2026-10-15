'use client';

import { useRef, type ReactNode } from 'react';
import { Icon } from './icon';

/** Optional, on-demand guidance. Validation and decision-critical warnings stay visible. */
export function FieldHelp({ label, children }: { label: string; children: ReactNode }) {
  const details = useRef<HTMLDetailsElement>(null);
  return <details ref={details} className="ui-field-help" onKeyDown={event => {
    if (event.key === 'Escape' && details.current?.open) {
      event.preventDefault();
      event.stopPropagation();
      details.current.open = false;
      details.current.querySelector('summary')?.focus();
    }
  }}>
    <summary aria-label={`مساعدة: ${label}`}><Icon name="help" size={16} /></summary>
    <div className="ui-field-help-content">{children}</div>
  </details>;
}
