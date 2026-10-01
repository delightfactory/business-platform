import { PageFrame } from '@/components/context-navigation';

export default function RecordLeaveLoading() {
  return <PageFrame footer="الموارد البشرية">
    <section className="work-card task-page">
      <p className="eyebrow">الموارد البشرية</p>
      <h1>جارٍ تحميل نموذج تسجيل الإجازة…</h1>
      <p className="form-message" role="status">نتحقق من صلاحيتك ونجهّز البحث عن الموظفين المتاحين.</p>
    </section>
  </PageFrame>;
}
