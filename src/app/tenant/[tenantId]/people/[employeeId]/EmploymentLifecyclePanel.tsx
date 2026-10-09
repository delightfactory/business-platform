'use client';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { endEmploymentAction, rehireEmployeeAction, type LifecycleState, type RehireState } from '../employment-lifecycle-actions';

type EmploymentItem = {
  id: string; employer: string; start_date: string; end_date: string | null;
  status: 'active' | 'ended'; pay_basis: 'monthly' | 'daily';
};
type LifecycleEvent = { event: 'employment.ended' | 'employment.rehired'; created_at: string;
  details: { after?: { end_date?: string } } };
export type EmploymentHistory = { items: EmploymentItem[]; events: LifecycleEvent[]; events_truncated: boolean };
type Employer = { id: string; name: string };
type Site = { id: string; name: string; employer_id: string };
type Department = { id: string; name: string };
type Job = { id: string; name: string; department_id: string | null };
export type RehireOptions = { employers: Employer[]; sites: Site[]; departments: Department[]; jobs: Job[] };

export function EmploymentLifecyclePanel({ tenantId, employeeId, employmentId, employmentStatus,
  employmentStartDate, workforceStatus, previousEndDate, canManage, today, history, historyError, rehireOptions, optionsError }: {
  tenantId: string; employeeId: string; employmentId: string | null; employmentStatus: string | null;
  employmentStartDate: string | null; workforceStatus: string; previousEndDate: string | null; canManage: boolean; today: string;
  history: EmploymentHistory | null; historyError: boolean; rehireOptions: RehireOptions | null; optionsError: boolean;
}) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const offlineHint1 = useId();
  const endInitial: LifecycleState = { tenantId, employeeId, employmentId: employmentId ?? '', endDate: today, error: '', attempt: 0 };
  const rehireInitial: RehireState = { tenantId, employeeId,
    employerId: rehireOptions?.employers[0]?.id ?? '',
    siteId: rehireOptions?.sites.find((site) => site.employer_id === rehireOptions.employers[0]?.id)?.id ?? '',
    departmentId: '', jobId: '', startDate: maxDate(today, nextDate(previousEndDate)),
    payBasis: 'monthly', amount: '', payrollEligible: true, error: '', attempt: 0 };
  const [endState, endAction, endActionPending] = useActionState(endEmploymentAction, endInitial);
  const [rehireState, rehireAction, rehireActionPending] = useActionState(rehireEmployeeAction, rehireInitial);
  const canEnd = canManage && Boolean(employmentId) && employmentStatus === 'active' && workforceStatus !== 'ended'
    && Boolean(employmentStartDate && employmentStartDate <= today);
  const canRehire = canManage && workforceStatus === 'ended';

  const showOffline1 = offline && !rehireActionPending;
  const showOffline0 = offline && !endActionPending;
  return <section className="workspace-records-panel assignment-history-panel" aria-labelledby="employment-history-heading">
    <h2 id="employment-history-heading">سجل علاقات العمل</h2>
    {historyError && <p className="form-message error-message" role="alert">تعذر تحميل سجل علاقات العمل. حدّث الصفحة أو تحقق من صلاحية عرض ملف الموظف.</p>}
    {!historyError && history?.items && history.items.length > 1 && <ol className="assignment-history-list">
      {history.items.slice(1).map((item) => <li key={item.id} className="assignment-history-item">
        <div className="assignment-history-heading"><strong>{item.status === 'ended' ? 'علاقة عمل سابقة' : 'علاقة عمل جديدة'}</strong>
          <span className={`entity-status ${item.status === 'ended' ? 'is-inactive' : 'is-active'}`}>{item.status === 'ended' ? 'منتهية' : 'نشطة'}</span></div>
        <dl className="snapshot-grid"><div><dt>جهة التوظيف</dt><dd>{item.employer}</dd></div>
          <div><dt>من</dt><dd><bdi>{item.start_date}</bdi></dd></div>
          {item.end_date && <div><dt>آخر يوم</dt><dd><bdi>{item.end_date}</bdi></dd></div>}
          <div><dt>أساس الأجر</dt><dd>{item.pay_basis === 'daily' ? 'يومي' : 'شهري'}</dd></div></dl>
      </li>)}
    </ol>}
    {history?.items.length === 1 && <p className="record-meta">هذه أول علاقة عمل مسجلة للموظف.</p>}
    {!historyError && history?.events.map((event, index) => <p className="record-meta" key={`${event.event}-${event.created_at}-${index}`}>
      {event.event === 'employment.ended' ? 'انتهت علاقة عمل بتاريخ ' : 'سُجلت إعادة توظيف في '}
      <bdi>{event.event === 'employment.ended' && event.details.after?.end_date
        ? event.details.after.end_date
        : new Date(event.created_at).toLocaleDateString(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo' })}</bdi>
    </p>)}
    {history?.events_truncated && <p className="record-meta">يعرض السجل أحدث 100 إجراء.</p>}
    {canEnd && <details className="compensation-change-details">
      <summary>إنهاء علاقة العمل</summary>
      <form key={endState.attempt} action={endAction} className="compensation-change-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="employeeId" value={employeeId} />
        <input type="hidden" name="employmentId" value={employmentId ?? ''} />
        <label htmlFor="employment-end-date">آخر يوم عمل</label><input id="employment-end-date" name="endDate" type="date" required
          min={employmentStartDate ?? today} max={today} defaultValue={endState.endDate} />
        <section className="employment-end-notes" aria-label="تنبيهات قبل إنهاء علاقة العمل">
          <h3>حدود هذا الإجراء</h3>
          <ul>
            <li>يمكن اختيار اليوم أو تاريخ سابق؛ لا يدعم الإنهاء بتاريخ مستقبلي.</li>
            <li>قد يرفض النظام التاريخ السابق إذا وُجد تكليف أو تغيير أجر لاحق يحتاج إلى إعادة ترتيب.</li>
            <li>تظل سجلات العمل والأجر محفوظة حتى آخر يوم، وتُلغى التغييرات المستقبلية غير النافذة.</li>
          </ul>
          <h3>مراجعات مطلوبة</h3>
          <p>لا يحسب النظام تسوية Payroll أو رصيد الإجازات أو التمويل، ولا يصحح فترة Payroll مقفلة تلقائيًا. راجع Payroll للتسوية النهائية أو تصحيح الفترة عند تسجيل تاريخ سابق، ونسّق الإجازات والتمويل مع مسؤوليها.</p>
        </section>
        <label className="checkbox-field"><input name="acknowledgeHandoff" type="checkbox" required />
          <span>أؤكد أنني راجعت هذه الآثار ونسّقت مع المسؤولين، وأفهم أن التاريخ السابق قد يتطلب تصحيحًا يدويًا لدى Payroll.</span></label>
        {endState.error && <p className="form-message error-message" role="alert">{endState.error}</p>}
        <div className="workspace-form-actions"><SubmitButton label="إنهاء علاقة العمل" pendingLabel="جارٍ إنهاء العلاقة…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/></div>
      {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>
    </details>}
    {canManage && employmentStatus === 'active' && employmentStartDate && employmentStartDate > today
      && <p className="form-message">لا يمكن إنهاء علاقة العمل قبل تاريخ بدايتها <bdi>{employmentStartDate}</bdi>.</p>}
    {canRehire && <details className="compensation-change-details">
      <summary>إعادة توظيف هذا الموظف</summary>
      {optionsError && <p className="form-message error-message" role="alert">تعذر تحميل جهات التوظيف والاختيارات النشطة. حدّث الصفحة قبل المتابعة.</p>}
      {!optionsError && !rehireOptions && <p className="form-message error-message" role="alert">خيارات إعادة التوظيف غير متاحة حاليًا.</p>}
      {!optionsError && rehireOptions && <form key={rehireState.attempt} action={rehireAction} className="compensation-change-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
        <p className="field-hint">سيُنشأ سجل توظيف جديد للموظف نفسه، مع تكليف وأجر ابتدائيين. تبقى العلاقة السابقة وسجلاتها كما هي.</p>
        <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
        <label htmlFor="rehire-employer">جهة التوظيف</label><select id="rehire-employer" name="employerId" required defaultValue={rehireState.employerId}>
          <option value="">اختر جهة التوظيف</option>{rehireOptions.employers.map((employer) => <option key={employer.id} value={employer.id}>{employer.name}</option>)}
        </select>
        <label htmlFor="rehire-site">الفرع</label><select id="rehire-site" name="siteId" required defaultValue={rehireState.siteId}>
          <option value="">اختر الفرع</option>{rehireOptions.sites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
        </select>
        <label htmlFor="rehire-department">القسم (اختياري)</label><select id="rehire-department" name="departmentId" defaultValue={rehireState.departmentId}>
          <option value="">دون تحديد قسم</option>{rehireOptions.departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}
        </select>
        <label htmlFor="rehire-job">الوظيفة (اختياري)</label><select id="rehire-job" name="jobId" defaultValue={rehireState.jobId}>
          <option value="">دون تحديد وظيفة</option>{rehireOptions.jobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}
        </select>
        <label htmlFor="rehire-start-date">تاريخ بداية العلاقة الجديدة</label><input id="rehire-start-date" name="startDate" type="date" required
          min={maxDate(today, nextDate(previousEndDate))} defaultValue={rehireState.startDate} />
        <label htmlFor="rehire-pay-basis">أساس الأجر</label><select id="rehire-pay-basis" name="payBasis" defaultValue={rehireState.payBasis}>
          <option value="monthly">راتب شهري</option><option value="daily">أجر يومي</option></select>
        <label htmlFor="rehire-amount">الأجر الأساسي الابتدائي (جنيه مصري)</label><input id="rehire-amount" name="amount" type="number" min="0" max="999999999999.99" step="0.01" required defaultValue={rehireState.amount} />
        <label className="checkbox-field"><input name="payrollEligible" type="checkbox" defaultChecked={rehireState.payrollEligible} /><span>مشمول في Payroll</span></label>
        <div className="form-message">تتطلب مستحقات الفترة السابقة تسوية مستقلة. راجع Payroll للتسوية النهائية أو التسوية اليدوية المعتمدة، ونسّق الإجازات والتمويل مع مسؤوليها.</div>
        {rehireState.error && <p className="form-message error-message" role="alert">{rehireState.error}</p>}
        <div className="workspace-form-actions"><SubmitButton label="إنشاء علاقة العمل الجديدة" pendingLabel="جارٍ تسجيل إعادة التوظيف…"  ariaDescribedBy={showOffline1 ? offlineHint1 : undefined} disabled={offline}/></div>
      {showOffline1 && <OfflineSubmissionNotice id={offlineHint1} purpose="continuation" />}</form>}
    </details>}
  </section>;
}

function nextDate(date: string | null) {
  if (!date) return '';
  const parsed = new Date(`${date}T00:00:00Z`);
  parsed.setUTCDate(parsed.getUTCDate() + 1);
  return parsed.toISOString().slice(0, 10);
}

function maxDate(first: string, second: string) { return first > second ? first : second; }
