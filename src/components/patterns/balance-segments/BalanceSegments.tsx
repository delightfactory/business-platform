import styles from './balance-segments.module.css';

export function BalanceSegments({ days }: { days: number }) {
  if (days <= 0 || !Number.isFinite(days)) return null;
  const visible = Math.min(30, Math.ceil(days));
  return <div className={styles.balance}>
    <div className={styles.segments} aria-hidden="true">
      {Array.from({ length: visible }, (_, index) => <span key={index} style={index === visible - 1 && days < visible ? { background: `linear-gradient(to top, var(--brand) ${(days - index) * 100}%, var(--surface-3) ${(days - index) * 100}%)` } : undefined} />)}
    </div>
    <p className={styles.caption}>كل قطعة تمثل يومًا من الرصيد المسجّل{days > 30 ? ' · عرض أول 30 يومًا' : ''}.</p>
  </div>;
}
