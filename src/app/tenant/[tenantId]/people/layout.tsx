import type { ReactNode } from 'react';
import styles from './domain.module.css';

export default function PeopleLayout({ children }: { children: ReactNode }) {
  return <div className={styles.domain}>{children}</div>;
}
