import { PageFrame } from '@/components/context-navigation';

export default function LeaveBalanceLedgerLoading() {
  return <PageFrame footer="الموارد البشرية">
    <section className="work-card task-page">
      <p className="eyebrow">الموارد البشرية</p>
      <h1>جارٍ تحميل سجل حساب الرصيد…</h1>
      <p className="form-message" role="status">نتحقق من صلاحيتك ونجلب أحدث قيود الحساب كاملة.</p>
    </section>
  </PageFrame>;
}
