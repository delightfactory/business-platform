'use client';

import { useRef, useState, type ReactNode } from 'react';
import { Icon } from './icon';

/** Optional, on-demand guidance. Validation and decision-critical warnings stay visible. */
export function FieldHelp({ label, fieldId, title, children }: { label: string; fieldId: string; title: ReactNode; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const trigger = useRef<HTMLButtonElement>(null);
  return <div className="ui-field-help" onKeyDown={event => {
    if (event.key === 'Escape' && open) {
      event.preventDefault();
      event.stopPropagation();
      setOpen(false);
      trigger.current?.focus();
    }
  }}>
    <div className="ui-field-label-row"><label htmlFor={fieldId}>{title}</label><button ref={trigger} type="button" className="ui-field-help-trigger" aria-label={`مساعدة: ${label}`} aria-expanded={open} aria-controls={`${fieldId}-help`} onClick={() => setOpen(!open)}><Icon name="help" size={16} /></button></div>
    <div id={`${fieldId}-help`} className="ui-field-help-content" hidden={!open}>{children}</div>
  </div>;
}
