import { PageFrame } from '@/components/context-navigation';

export default function LeaveReviewQueueLoading() {
  return <PageFrame footer="الموارد البشرية">
    <section className="work-card task-page">
      <p className="eyebrow">الموارد البشرية</p>
      <h1>جارٍ تحميل طلبات الإجازة…</h1>
      <p className="form-message" role="status">نجلب الطلبات المقدمة وطلبات إلغاء الاعتماد بانتظار القرار.</p>
    </section>
  </PageFrame>;
}
