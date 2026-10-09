import { ButtonLink, Icon } from '@/components/ui';
import { BalanceSegments } from '@/components/patterns/balance-segments/BalanceSegments';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { isDate, isObject, isUuid } from './form-rules';
import { formatDays } from './states';
import styles from './leave.module.css';

export async function BalancePreview({ tenantId }: { tenantId: string }) {
  const client = await getWorkspaceClient();
  if (!client) return null;
  let response;
  try {
    response = await client.rpc('leave_my_balances', { p_tenant: tenantId, p_limit: 10, p_offset: 0 });
  } catch { return <BalanceReadFailure tenantId={tenantId}/>; }
  if (response.error || !isObject(response.data) || !Array.isArray(response.data.items)
    || typeof response.data.has_more !== 'boolean') return <BalanceReadFailure tenantId={tenantId}/>;
  const items: { id: string; name: string; period: string; days: number }[] = [];
  for (const item of response.data.items) {
    if (!isObject(item) || !isUuid(item.leave_type_id) || !isUuid(item.period_id)
      || typeof item.type_name !== 'string' || typeof item.period_label !== 'string'
      || typeof item.starts_on !== 'string' || !isDate(item.starts_on)
      || typeof item.balance_days !== 'number' || !Number.isFinite(item.balance_days)) return <BalanceReadFailure tenantId={tenantId}/>;
    items.push({ id: `${item.leave_type_id}-${item.period_id}`, name: item.type_name, period: item.period_label, days: item.balance_days });
  }
  return <section className={`ui-card ${styles.dailyBalance}`}>
    <div className={styles.dailyBalanceHeading}><h2><Icon name="calendar" size={18}/>رصيد إجازاتي</h2><ButtonLink variant="ghost" href={`/tenant/${tenantId}/me/leave`}>كل الأرصدة</ButtonLink></div>
    {items.length === 0 ? <p className="field-hint">لا توجد أرصدة مسجّلة بعد.</p> : items.slice(0, 3).map(item => <div className={styles.dailyBalanceItem} key={item.id}>
      <div className={styles.dailyBalanceHeading}><div><strong>{item.name}</strong><p className="field-hint">{item.period}</p></div><span className={styles.balanceValue}>{formatDays(item.days)} <small>يوم</small></span></div>
      <BalanceSegments days={item.days}/>
    </div>)}
    {(items.length > 3 || response.data.has_more) && <p className="field-hint">معاينة أول 3 أرصدة. التفاصيل والأرصدة الأخرى في إجازاتي.</p>}
    <p className="field-hint">الطلبات المعلقة لا تحجز رصيدًا قبل الاعتماد.</p>
  </section>;
}

function BalanceReadFailure({ tenantId }: { tenantId: string }) {
  return <section className={`ui-card ${styles.dailyBalance}`}><h2>رصيد إجازاتي</h2><p className="field-hint">تعذر التحقق من الرصيد الآن.</p><ButtonLink variant="ghost" href={`/tenant/${tenantId}/me/leave`}>فتح الأرصدة</ButtonLink></section>;
}
