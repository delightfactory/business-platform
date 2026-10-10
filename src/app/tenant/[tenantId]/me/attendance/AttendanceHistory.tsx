import { channelReasonLabel, channelStateLabel, formatChannelInstant, type MobileSnapshot } from '@/lib/attendance-channel';
import { Disclosure, EmptyState, Icon, StatusBadge } from '@/components/ui';
import styles from './attendance.module.css';

export function AttendanceHistory({ history }: { history: MobileSnapshot['history'] }) {
  if (history.length === 0) return <EmptyState icon="clock" title="لا توجد تسجيلات بعد" description="تظهر محاولاتك هنا بعد تسجيل الحضور أو الانصراف." />;
  return <ol className={styles.history}>{history.map(item => <li key={item.id}>
    <div className={styles.recordIcon}><Icon name={item.direction === 'in' ? 'clock' : 'checkCheck'} /></div>
    <div className={styles.recordBody}>
      <div className={styles.recordHeading}><h3>{item.direction === 'in' ? 'حضور' : 'انصراف'}</h3><StatusBadge label={item.state === 'accepted' && item.review_required ? 'مسجلة وتحتاج مراجعة' : channelStateLabel(item.state)} tone={item.state === 'accepted' && !item.review_required ? 'ok' : item.state === 'rejected' ? 'bad' : 'warn'} /></div>
      <p><time dateTime={item.happened_at}>{formatChannelInstant(item.happened_at, item.timezone_name)}</time>{item.timezone_is_fallback && ' (UTC)'}</p>
      <p className={styles.site}>{item.site_name ?? 'موقع الحدث غير متاح'}</p>
      {item.reason && <p>{channelReasonLabel(item.reason)}</p>}
      {item.review_decision && <Disclosure summary={item.review_decision.decision === 'exclude' ? 'استُبعدت الحركة بقرار مراجعة لاحق' : 'قُبلت الحركة بعد مراجعة الموقع'}>
        <p>المراجع: {item.review_decision.actor_label}</p><p>{item.review_decision.reason}</p><p>{formatChannelInstant(item.review_decision.created_at, item.review_decision.timezone_name)}{item.review_decision.timezone_name === 'UTC' ? ' (UTC)' : ''}</p>
      </Disclosure>}
    </div>
  </li>)}</ol>;
}
