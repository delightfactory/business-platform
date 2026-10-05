import { PageFrame } from '@/components/context-navigation';

export default function LeaveRequestReviewLoading() {
  return <PageFrame footer="الموارد البشرية">
    <section className="work-card task-page">
      <p className="eyebrow">مراجعة طلب إجازة</p>
      <h1>جارٍ تحميل الطلب…</h1>
      <p className="form-message" role="status">نجلب بيانات الطلب وأيامه وسجل طلبات الإلغاء.</p>
    </section>
  </PageFrame>;
}
