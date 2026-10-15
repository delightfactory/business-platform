'use client';

import type { ButtonHTMLAttributes } from 'react';
import { Icon } from './icon';
import './switch.css';

type SwitchProps = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'onChange' | 'aria-checked' | 'role' | 'children'> & {
  checked: boolean;
  pending?: boolean;
  label: string;
  onCheckedChange: (checked: boolean) => void;
};

// Controlled by confirmed server state; this control never changes state optimistically.
export function Switch({ checked, pending = false, label, onCheckedChange, disabled, className = '', onClick, ...props }: SwitchProps) {
  return <button {...props} type="button" role="switch" aria-checked={checked} aria-label={label}
    aria-busy={pending || undefined} disabled={disabled || pending} className={`ui-switch ${className}`}
    onClick={event => { onClick?.(event); if (!event.defaultPrevented) onCheckedChange(!checked); }}>
    <span className="ui-switch-track" aria-hidden="true"><span className="ui-switch-thumb">
      {pending ? <Icon name="loader" size={14} className="ui-spin" /> : checked ? <Icon name="check" size={13} /> : null}
    </span></span>
  </button>;
}
