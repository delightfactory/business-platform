import type { CSSProperties, ReactNode } from 'react';
import styles from './workspace-navigation.module.css';

export function AppShell({ children, navigation, mode, brand, style }: {
  children: ReactNode; navigation: ReactNode; mode: 'tenant' | 'operator'; brand?: string; style?: CSSProperties;
}) {
  return <div className={`${mode}-area workspace-frame ${styles.frame}`} data-workspace={mode} data-brand={brand} style={style}>
    {navigation}
    <div className={`workspace-content ${styles.content}`} id="workspace-content" tabIndex={-1}>{children}</div>
  </div>;
}
