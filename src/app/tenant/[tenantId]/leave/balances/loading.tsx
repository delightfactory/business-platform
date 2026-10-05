import { PageFrame } from '@/components/context-navigation';

export default function LeaveBalancesLoading() {
  return <PageFrame footer="الموارد البشرية">
    <section className="work-card task-page">
      <p className="eyebrow">الموارد البشرية</p>
      <h1>جارٍ تحميل أرصدة الإجازات…</h1>
      <p className="form-message" role="status">نتحقق من صلاحيتك ونجهّز البحث عن الموظفين وحسابات الأرصدة.</p>
    </section>
  </PageFrame>;
}
