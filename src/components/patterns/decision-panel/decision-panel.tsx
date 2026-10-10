import type { ReactNode } from 'react';
import { Avatar, Badge, FactList, KeyValueStrip, type KeyValueItem, type Tone } from '@/components/ui';
import styles from './decision-panel.module.css';

export function DecisionPanel({ title, person, kind, facts = [], values = [], children, tone = 'brand', id }: { title: ReactNode; person?: string; kind: string; facts?: { text: ReactNode; tone?: Tone }[]; values?: KeyValueItem[]; children: ReactNode; tone?: Tone; id?: string }) {
  return <section className={styles.panel} aria-labelledby={id}>
    <header className={styles.header}>{person && <Avatar name={person} size={48} />}<div><Badge tone={tone}>{kind}</Badge><h2 id={id}>{title}</h2></div></header>
    {values.length > 0 && <KeyValueStrip items={values} />}
    {facts.length > 0 && <div className={styles.facts}><h3>قبل أن تقرر</h3><FactList items={facts} /></div>}
    <div className={styles.body}>{children}</div>
  </section>;
}
