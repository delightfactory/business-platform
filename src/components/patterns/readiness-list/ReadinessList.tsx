import { ButtonLink, StatusBadge } from '@/components/ui';
import styles from './readiness-list.module.css';

export type ReadinessItem = {
  title: string;
  state: 'done' | 'todo' | 'other-role' | 'unknown';
  detail: string;
  action?: { href: string; label: string };
  owner?: string;
  statusLabel?: string;
};
const states = {
  done: { label: 'مكتمل', tone: 'ok' },
  todo: { label: 'خطوتك التالية', tone: 'brand' },
  'other-role': { label: 'يحتاج دورًا آخر', tone: 'neutral' },
  unknown: { label: 'تعذر التحقق', tone: 'warn' },
} as const;

export function ReadinessList({ items }: { items: ReadinessItem[] }) {
  return <ul className={styles.list}>{items.map(item => <li key={item.title}>
    <div className={styles.copy}><div className={styles.heading}><h3>{item.title}</h3><StatusBadge {...states[item.state]} label={item.statusLabel ?? states[item.state].label} /></div>
      <p>{item.detail}</p>{item.owner && <small>المسؤول: {item.owner}</small>}</div>
    {item.action && <ButtonLink href={item.action.href} variant="ghost">{item.action.label}</ButtonLink>}
  </li>)}</ul>;
}
