import Link from 'next/link';
import type { ReleaseStatus } from './comparisons/IssuanceStatus';

export function StatutoryStageBar({ head, status, unavailable = false }: { head?: string; status: ReleaseStatus | null; unavailable?: boolean }) {
  const current = !status || status.blockers.includes('numeric_rules_missing') ? 0 : status.issued_pack || status.ready ? 2 : 1;
  const stages = [
    { label: 'المسودة', href: head ? `/operator/statutory?head=${head}` : '/operator/statutory' },
    { label: 'المقارنات', href: head ? `/operator/statutory/comparisons?head=${head}` : null },
    { label: 'الإصدار للضريبة والتأمين', href: head ? `/operator/statutory/comparisons?head=${head}#statutory-issuance` : null },
  ];
  return <section className="statutory-stages" aria-label="مراحل مراجعة القواعد">
    <ol>{stages.map((stage, index) => <li key={stage.label} aria-current={!unavailable && index === current ? 'step' : undefined}>
      <span aria-hidden="true">{index + 1}</span>{stage.href ? <Link href={stage.href}>{stage.label}</Link> : <span>{stage.label}</span>}
      {index === 2 && status?.issued_pack && <small>صدرت هذه النسخة</small>}
    </li>)}</ol>
    <p>{unavailable ? 'حالة الإصدار غير مؤكدة؛ أعد القراءة قبل المتابعة. ' : ''}الإصدار لا يجعل القواعد مؤهلة للحساب المالي.</p>
  </section>;
}
