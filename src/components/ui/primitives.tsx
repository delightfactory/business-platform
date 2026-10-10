import Link from 'next/link';
import { cloneElement, isValidElement, type ComponentProps, type ButtonHTMLAttributes, type HTMLAttributes, type InputHTMLAttributes, type ReactNode, type Ref, type SelectHTMLAttributes, type TextareaHTMLAttributes, type DetailsHTMLAttributes, type TableHTMLAttributes } from 'react';
import { Icon, type IconName } from './icon';

export type Tone = 'neutral' | 'ok' | 'warn' | 'bad' | 'info' | 'brand';
export type ButtonVariant = 'solid' | 'ghost' | 'danger';
export function buttonClassName(variant: ButtonVariant = 'solid', size: 'md' | 'lg' = 'md', className = '') { return `ui-button ui-button-${variant} ui-button-${size} ${className}`; }
export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: 'md' | 'lg'; pending?: boolean; pendingLabel?: string; icon?: IconName; ref?: Ref<HTMLButtonElement> };
export function Button({ variant, size, pending = false, pendingLabel, icon, disabled, children, className, type = 'button', ...props }: ButtonProps) {
  return <button type={type} className={buttonClassName(variant, size, className)} disabled={disabled || pending} aria-busy={pending || undefined} {...props}>{pending ? <Icon name="loader" className="ui-spin" size={18} /> : icon ? <Icon name={icon} size={18} /> : null}{pending && pendingLabel ? pendingLabel : children}</button>;
}
export function ButtonLink({ href, variant, size, icon, children, className, ...props }: Omit<ComponentProps<typeof Link>, 'href'> & { href: string; variant?: ButtonVariant; size?: 'md' | 'lg'; icon?: IconName }) { return <Link href={href} className={buttonClassName(variant, size, className)} {...props}>{icon && <Icon name={icon} size={18} />}{children}</Link>; }
export function IconButton({ icon, 'aria-label': label, className = '', ...props }: Omit<ButtonProps, 'children' | 'icon'> & { icon: IconName; 'aria-label': string }) { return <Button className={`ui-icon-button ${className}`} variant="ghost" aria-label={label} {...props}><Icon name={icon} /></Button>; }

export function Field({ id, label, hint, error, children, className = '', required }: { id: string; label: ReactNode; hint?: ReactNode; error?: ReactNode; children: ReactNode; className?: string; required?: boolean }) {
  const control = isValidElement<InputHTMLAttributes<HTMLInputElement>>(children) ? cloneElement(children, { id, 'aria-describedby': [children.props['aria-describedby'], hint ? `${id}-hint` : undefined, error ? `${id}-error` : undefined].filter(Boolean).join(' ') || undefined, 'aria-invalid': error ? true : children.props['aria-invalid'] }) : children;
  return <div className={`ui-field ${className}`}><label htmlFor={id}>{label}{required && <span aria-hidden="true" className="ui-required"> *</span>}</label>{control}{hint && <p id={`${id}-hint`} className="ui-field-hint">{hint}</p>}{error && <p id={`${id}-error`} className="ui-field-error" role="alert">{error}</p>}</div>;
}
type InputProps = InputHTMLAttributes<HTMLInputElement> & { error?: boolean; ref?: Ref<HTMLInputElement> };
export function Input({ className = '', error, ...props }: InputProps) { return <input className={`ui-input ${className}`} aria-invalid={error || props['aria-invalid']} {...props} />; }
export function Checkbox({ className = '', ...props }: Omit<InputProps, 'type'>) { return <input className={`ui-choice-input ${className}`} type="checkbox" {...props} />; }
export function Radio({ className = '', ...props }: Omit<InputProps, 'type'>) { return <input className={`ui-choice-input ${className}`} type="radio" {...props} />; }
export function FileInput({ className = '', ...props }: Omit<InputProps, 'type'>) { return <input className={`ui-file ${className}`} type="file" {...props} />; }
export function DateInput(props: Omit<InputProps, 'type'>) { return <Input {...props} type="date" />; }
export function TimeInput(props: Omit<InputProps, 'type'>) { return <Input {...props} type="time" />; }
export function Textarea({ className = '', ...props }: TextareaHTMLAttributes<HTMLTextAreaElement> & { ref?: Ref<HTMLTextAreaElement> }) { return <textarea className={`ui-input ui-textarea ${className}`} {...props} />; }
export function Select({ className = '', children, ...props }: SelectHTMLAttributes<HTMLSelectElement> & { ref?: Ref<HTMLSelectElement> }) { return <select className={`ui-input ui-select ${className}`} {...props}>{children}</select>; }

export function Badge({ as: Tag = 'span', tone = 'neutral', children, className = '', ...props }: HTMLAttributes<HTMLElement> & { tone?: Tone; as?: 'span' | 'p' }) { return <Tag className={`ui-badge ui-tone-${tone} ${className}`} {...props}>{children}</Tag>; }
export function StatusBadge({ label, tone = 'neutral' }: { label: string; tone?: Tone }) { return <Badge tone={tone}><span className="ui-status-dot" aria-hidden="true" />{label}</Badge>; }
export function Avatar({ name, size = 40, status, className = '' }: { name: string; size?: 32 | 40 | 48 | 64; status?: Tone; className?: string }) { const initials = name.trim().split(/\s+/).slice(0, 2).map(part => part[0]).join(''); return <span className={`ui-avatar ui-avatar-${size} ${className}`} aria-label={name}>{initials}{status && <span className={`ui-avatar-status ui-dot-${status}`} aria-hidden="true" />}</span>; }
export function Card({ children, className = '', ...props }: HTMLAttributes<HTMLDivElement>) { return <div className={`ui-card ${className}`} {...props}>{children}</div>; }
/** Keep the original section/list semantics while sharing the visual surface. */
export function Panel({ as: Tag = 'section', children, className = '', ...props }: HTMLAttributes<HTMLElement> & { as?: 'section' | 'article' | 'div' }) {
  return <Tag className={`ui-panel ${className}`} {...props}>{children}</Tag>;
}
export function RecordCard({ as: Tag = 'li', children, className = '', ...props }: HTMLAttributes<HTMLElement> & { as?: 'li' | 'article' | 'div' | 'section' }) {
  return <Tag className={`ui-record ${className}`} {...props}>{children}</Tag>;
}
export function Message({ as: Tag = 'p', tone = 'info', children, className = '', ...props }: HTMLAttributes<HTMLElement> & { as?: 'p' | 'div'; tone?: Tone; ref?: Ref<HTMLParagraphElement> }) {
  return <Tag className={`ui-message ui-tone-${tone} ${className}`} {...props}>{children}</Tag>;
}
export function DataTable({ className = '', children, ...props }: TableHTMLAttributes<HTMLTableElement>) {
  return <table className={`ui-data-table ${className}`} {...props}>{children}</table>;
}
export function PageHeader({ title, description, action, eyebrow, id, className = '' }: { title: ReactNode; description?: ReactNode; action?: ReactNode; eyebrow?: ReactNode; id?: string; className?: string }) { return <header className={`ui-page-header ${className}`}><div>{eyebrow && <p className="ui-eyebrow">{eyebrow}</p>}<h1 id={id}>{title}</h1>{description && <p className="ui-page-description">{description}</p>}</div>{action && <div className="ui-page-actions">{action}</div>}</header>; }
export function Banner({ tone = 'info', title, children, action, className = '', ...props }: Omit<HTMLAttributes<HTMLDivElement>, 'title'> & { tone?: Tone; title?: ReactNode; action?: ReactNode }) { return <div className={`ui-banner ui-tone-${tone} ${className}`} {...props}><Icon name={tone === 'bad' || tone === 'warn' ? 'alert' : tone === 'ok' ? 'success' : 'info'} /><div>{title && <strong>{title}</strong>}{children && <div>{children}</div>}</div>{action && <div className="ui-banner-action">{action}</div>}</div>; }
export const Notice = Banner;
export function Disclosure({ summary, children, className = '', ...props }: DetailsHTMLAttributes<HTMLDetailsElement> & { summary: ReactNode }) { return <details className={`ui-disclosure ${className}`} {...props}><summary>{summary}<Icon name="chevronDown" size={18} /></summary><div className="ui-disclosure-content">{children}</div></details>; }
/** Optional explanation only; keep errors and decision-critical guidance visible. */
export function HelpNote({ label, children }: { label: string; children: ReactNode }) {
  return <Disclosure className="ui-help-note" summary={<span><Icon name="info" size={16} />{label}</span>}>{children}</Disclosure>;
}
export function EmptyState({ title, description, action, icon = 'file', className = '', ...props }: Omit<HTMLAttributes<HTMLDivElement>, 'title'> & { title: ReactNode; description?: ReactNode; action?: ReactNode; icon?: IconName }) { return <div className={`ui-empty ${className}`} {...props}><span className="ui-empty-icon"><Icon name={icon} size={28} /></span><h2>{title}</h2>{description && <p>{description}</p>}{action}</div>; }
export function Skeleton({ className = '', ...props }: HTMLAttributes<HTMLDivElement>) { return <div aria-hidden="true" className={`ui-skeleton ${className}`} {...props} />; }
export type KeyValueItem = { label: ReactNode; value: ReactNode; money?: boolean };
export function KeyValueStrip({ items }: { items: KeyValueItem[] }) { return <dl className="ui-key-values">{items.map((item, i) => <div key={i}><dt>{item.label}</dt><dd className={item.money ? 'ui-money' : ''}>{item.value}</dd></div>)}</dl>; }
export function FactList({ items }: { items: { text: ReactNode; tone?: Tone; icon?: IconName }[] }) { return <ul className="ui-facts">{items.map((item, i) => <li key={i}><Icon name={item.icon ?? (item.tone === 'warn' || item.tone === 'bad' ? 'alert' : 'check')} className={`ui-text-${item.tone ?? 'neutral'}`} size={18} /><span>{item.text}</span></li>)}</ul>; }
