import type { ReactNode } from 'react';
import { OperatorNavigation } from '@/components/context-navigation';

export default function OperatorLayout({ children }: { children: ReactNode }) {
  return <div className="operator-area workspace-frame" data-workspace="operator">
    <OperatorNavigation />
    <div className="workspace-content">{children}</div>
  </div>;
}
