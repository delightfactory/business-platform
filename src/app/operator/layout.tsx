import type { ReactNode } from 'react';
import { OperatorNavigation } from '@/components/context-navigation';
import { AppShell } from '@/components/shell/app-shell';

export default function OperatorLayout({ children }: { children: ReactNode }) {
  return <AppShell mode="operator" navigation={<OperatorNavigation />}>{children}</AppShell>;
}
