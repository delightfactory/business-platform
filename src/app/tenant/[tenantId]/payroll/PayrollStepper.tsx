import styles from './payroll.module.css';
import { Icon, type IconName, Disclosure } from '@/components/ui';
import { payrollStageDescriptions, type StageWork } from './stage-facts';

const stageIcons: IconName[] = ['calendar', 'clock', 'file', 'wallet', 'shield', 'checkCheck'];
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

export function PayrollStepper({ currentStage, historical = false, work = null }: { currentStage: number | null; historical?: boolean; work?: StageWork | null }) {
  const current = currentStage === null ? null : stages[currentStage];
  const descriptions = payrollStageDescriptions(work);
  const list = <ol className={styles.progressList}>{stages.map((stage, index) => <li key={stage} aria-current={currentStage === index ? 'step' : undefined}><span className={styles.stageIcon}><Icon name={stageIcons[index]} size={18} /></span><span className={styles.stageName}>{stage}{currentStage === index && <small>الحالية</small>}</span><p className="field-hint">{descriptions[index]}</p></li>)}</ol>;
  return <section className={styles.progress} aria-label="مراحل الرواتب">
    <p className={styles.progressCurrent}>{current ? `المرحلة الحالية: ${current}` : historical ? 'المسير مستبدل ومحفوظ في التاريخ؛ راجع المسير البديل.' : 'لا يمكن تحديد المرحلة الحالية من البيانات المتاحة؛ تابع مراجعة الرواتب.'}</p>
    <p className="field-hint">حالة المصادر تخص الحساب المحفوظ. التغطية التشغيلية والتأهيل المالي والاعتماد والصرف حالات منفصلة.</p>
    <div className={styles.progressDesktop}>{list}</div>
    <Disclosure summary={<>عرض مراحل الرواتب</>} className={styles.progressDetails}>

      {list}
    </Disclosure>
    {currentStage === 5 && <p className="field-hint">حالة الصرف المسجل معروضة أدناه حسب صلاحيتك؛ وجود مسير نهائي لا يعني أنه صُرف.</p>}
  </section>;
}
