import Link from 'next/link';
import { cloneElement, isValidElement, type AnchorHTMLAttributes, type ButtonHTMLAttributes, type HTMLAttributes, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes, type TextareaHTMLAttributes, type DetailsHTMLAttributes } from 'react';
import { Icon, type IconName } from './icon';

export type Tone = 'neutral' | 'ok' | 'warn' | 'bad' | 'info' | 'brand';
export type ButtonVariant = 'solid' | 'ghost' | 'danger';
export function buttonClassName(variant: ButtonVariant = 'solid', size: 'md' | 'lg' = 'md', className = '') { return `ui-button ui-button-${variant} ui-button-${size} ${className}`; }
export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: 'md' | 'lg'; pending?: boolean; pendingLabel?: string; icon?: IconName };
export function Button({ variant, size, pending = false, pendingLabel, icon, disabled, children, className, type = 'button', ...props }: ButtonProps) {
  return <button type={type} className={buttonClassName(variant, size, className)} disabled={disabled || pending} aria-busy={pending || undefined} {...props}>{pending ? <Icon name="loader" className="ui-spin" size={18} /> : icon ? <Icon name={icon} size={18} /> : null}{pending && pendingLabel ? pendingLabel : children}</button>;
}
export function ButtonLink({ href, variant, size, icon, children, className, ...props }: AnchorHTMLAttributes<HTMLAnchorElement> & { href: string; variant?: ButtonVariant; size?: 'md' | 'lg'; icon?: IconName }) { return <Link href={href} className={buttonClassName(variant, size, className)} {...props}>{icon && <Icon name={icon} size={18} />}{children}</Link>; }
export function IconButton({ icon, 'aria-label': label, className = '', ...props }: Omit<ButtonProps, 'children' | 'icon'> & { icon: IconName; 'aria-label': string }) { return <Button className={`ui-icon-button ${className}`} variant="ghost" aria-label={label} {...props}><Icon name={icon} /></Button>; }

export function Field({ id, label, hint, error, children, className = '', required }: { id: string; label: ReactNode; hint?: ReactNode; error?: ReactNode; children: ReactNode; className?: string; required?: boolean }) {
  const control = isValidElement<InputHTMLAttributes<HTMLInputElement>>(children) ? cloneElement(children, { id, 'aria-describedby': [children.props['aria-describedby'], hint ? `${id}-hint` : undefined, error ? `${id}-error` : undefined].filter(Boolean).join(' ') || undefined, 'aria-invalid': error ? true : children.props['aria-invalid'] }) : children;
  return <div className={`ui-field ${className}`}><label htmlFor={id}>{label}{required && <span aria-hidden="true" className="ui-required"> *</span>}</label>{control}{hint && <p id={`${id}-hint`} className="ui-field-hint">{hint}</p>}{error && <p id={`${id}-error`} className="ui-field-error" role="alert">{error}</p>}</div>;
}
type InputProps = InputHTMLAttributes<HTMLInputElement> & { error?: boolean };
export function Input({ className = '', error, ...props }: InputProps) { return <input className={`ui-input ${className}`} aria-invalid={error || props['aria-invalid']} {...props} />; }
export function DateInput(props: Omit<InputProps, 'type'>) { return <Input {...props} type="date" />; }
export function TimeInput(props: Omit<InputProps, 'type'>) { return <Input {...props} type="time" />; }
export function Textarea({ className = '', ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) { return <textarea className={`ui-input ui-textarea ${className}`} {...props} />; }
export function Select({ className = '', children, ...props }: SelectHTMLAttributes<HTMLSelectElement>) { return <select className={`ui-input ui-select ${className}`} {...props}>{children}</select>; }

export function Badge({ tone = 'neutral', children, className = '', ...props }: HTMLAttributes<HTMLSpanElement> & { tone?: Tone }) { return <span className={`ui-badge ui-tone-${tone} ${className}`} {...props}>{children}</span>; }
export function StatusBadge({ label, tone = 'neutral' }: { label: string; tone?: Tone }) { return <Badge tone={tone}><span className="ui-status-dot" aria-hidden="true" />{label}</Badge>; }
export function Avatar({ name, size = 40, status, className = '' }: { name: string; size?: 32 | 40 | 48 | 64; status?: Tone; className?: string }) { const initials = name.trim().split(/\s+/).slice(0, 2).map(part => part[0]).join(''); return <span className={`ui-avatar ui-avatar-${size} ${className}`} aria-label={name}>{initials}{status && <span className={`ui-avatar-status ui-dot-${status}`} aria-hidden="true" />}</span>; }
export function Card({ children, className = '', ...props }: HTMLAttributes<HTMLDivElement>) { return <div className={`ui-card ${className}`} {...props}>{children}</div>; }
export function PageHeader({ title, description, action, eyebrow }: { title: ReactNode; description?: ReactNode; action?: ReactNode; eyebrow?: ReactNode }) { return <header className="ui-page-header"><div>{eyebrow && <p className="ui-eyebrow">{eyebrow}</p>}<h1>{title}</h1>{description && <p className="ui-page-description">{description}</p>}</div>{action && <div className="ui-page-actions">{action}</div>}</header>; }
export function Banner({ tone = 'info', title, children, action, className = '', ...props }: Omit<HTMLAttributes<HTMLDivElement>, 'title'> & { tone?: Tone; title?: ReactNode; action?: ReactNode }) { return <div className={`ui-banner ui-tone-${tone} ${className}`} {...props}><Icon name={tone === 'bad' || tone === 'warn' ? 'alert' : tone === 'ok' ? 'success' : 'info'} /><div>{title && <strong>{title}</strong>}{children && <div>{children}</div>}</div>{action && <div className="ui-banner-action">{action}</div>}</div>; }
export const Notice = Banner;
export function Disclosure({ summary, children, className = '', ...props }: DetailsHTMLAttributes<HTMLDetailsElement> & { summary: ReactNode }) { return <details className={`ui-disclosure ${className}`} {...props}><summary>{summary}<Icon name="chevronDown" size={18} /></summary><div className="ui-disclosure-content">{children}</div></details>; }
export function EmptyState({ title, description, action, icon = 'file' }: { title: ReactNode; description?: ReactNode; action?: ReactNode; icon?: IconName }) { return <div className="ui-empty"><span className="ui-empty-icon"><Icon name={icon} size={28} /></span><h2>{title}</h2>{description && <p>{description}</p>}{action}</div>; }
export function Skeleton({ className = '', ...props }: HTMLAttributes<HTMLDivElement>) { return <div aria-hidden="true" className={`ui-skeleton ${className}`} {...props} />; }
export type KeyValueItem = { label: ReactNode; value: ReactNode; money?: boolean };
export function KeyValueStrip({ items }: { items: KeyValueItem[] }) { return <dl className="ui-key-values">{items.map((item, i) => <div key={i}><dt>{item.label}</dt><dd className={item.money ? 'ui-money' : ''}>{item.value}</dd></div>)}</dl>; }
export function FactList({ items }: { items: { text: ReactNode; tone?: Tone; icon?: IconName }[] }) { return <ul className="ui-facts">{items.map((item, i) => <li key={i}><Icon name={item.icon ?? (item.tone === 'warn' || item.tone === 'bad' ? 'alert' : 'check')} className={`ui-text-${item.tone ?? 'neutral'}`} size={18} /><span>{item.text}</span></li>)}</ul>; }
