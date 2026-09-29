import type { ReactNode } from 'react';
import { OperatorNavigation } from '@/components/context-navigation';

export default function OperatorLayout({ children }: { children: ReactNode }) {
  return <div className="operator-area"><OperatorNavigation current="home" />{children}</div>;
}
