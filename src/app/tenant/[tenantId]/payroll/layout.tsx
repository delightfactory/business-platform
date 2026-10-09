import type { ReactNode } from 'react';
import styles from './domain.module.css';

export default function PayrollLayout({ children }: { children: ReactNode }) {
  return <div className={styles.domain}>{children}</div>;
}
