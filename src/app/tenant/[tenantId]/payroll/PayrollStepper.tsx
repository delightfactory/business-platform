import styles from './payroll.module.css';

const stages = ['الدورة والفترة', 'الحضور والإجازات', 'المدخلات والموانع', 'الحساب والمراجعة', 'الاعتماد والتثبيت', 'الصرف والقسائم'];

export function payrollCurrentStage(work: { run: { status: string } | null; final_output_id: string | null; stale_reasons: string[] } | null): number | null {
  if (!work) return 0;
  if (!work.run || work.run.status === 'cancelled') return 2;
  if (work.run.status === 'superseded') return null;
  if (work.run.status === 'locked') return work.final_output_id ? 5 : null;
  if (work.stale_reasons.length) return 3;
  if (work.run.status === 'approved') return 4;
  if (['draft', 'review'].includes(work.run.status)) return 3;
  return null;
}

export function PayrollStepper({ currentStage, historical = false }: { currentStage: number | null; historical?: boolean }) {
  const current = currentStage === null ? null : stages[currentStage];
  const list = <ol className={styles.progressList}>{stages.map((stage, index) => <li key={stage} aria-current={currentStage === index ? 'step' : undefined}>{stage}{currentStage === index && <span> · الحالية</span>}</li>)}</ol>;
  return <section className={styles.progress} aria-label="مراحل الرواتب">
    <p className={styles.progressCurrent}>{current ? `المرحلة الحالية: ${current}` : historical ? 'المسير مستبدل ومحفوظ في التاريخ؛ راجع المسير البديل.' : 'لا يمكن تحديد المرحلة الحالية من البيانات المتاحة؛ تابع مراجعة الرواتب.'}</p>
    <p className="field-hint">هذا الدليل يوضح موضع المسير، ولا يثبت اكتمال المراحل السابقة أو التأهيل المالي.</p>
    <div className={styles.progressDesktop}>{list}</div>
    <details className={styles.progressDetails}>
      <summary>عرض مراحل الرواتب</summary>
      {list}
    </details>
    {currentStage === 5 && <p className="field-hint">حالة الصرف تُراجع في شاشة الدفعات حسب صلاحياتك؛ وجود مسير نهائي لا يعني أنه صُرف.</p>}
  </section>;
}
