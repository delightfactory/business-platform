'use client';

import { useState, useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { cancelWorkAssignmentAction, correctInitialWorkAssignmentAction, scheduleWorkAssignmentAction, type AssignmentFormState } from '../work-assignment-actions';

type Named = { id: string; name: string };
type Manager = Named & { start_date: string };
type Site = Named;
type Department = Named;
type Job = Named & { department_id: string | null };
export type AssignmentRow = {
  id: string; site: string | null; site_id: string; department: string | null; department_id: string | null;
  job: string | null; job_id: string | null; manager: string | null; manager_employee_id: string | null;
  valid_from: string; valid_until: string | null; status: 'current' | 'past' | 'scheduled' | 'initial_scheduled';
};
export type AssignmentHistory = { items: AssignmentRow[]; truncated: boolean };
export type TransferOptions = {
  sites: Site[]; departments: Department[]; jobs: Job[]; managers: Manager[];
  sites_truncated: boolean; departments_truncated: boolean; jobs_truncated: boolean; managers_truncated: boolean;
};

export function WorkAssignmentPanel({ tenantId, employeeId, employmentId, employmentStartDate, employmentActive,
  history, historyError, options, optionsError, canManage, initialDate }: {
  tenantId: string; employeeId: string; employmentId: string | null; employmentStartDate: string | null;
  employmentActive: boolean; history: AssignmentHistory | null; historyError: boolean;
  options: TransferOptions | null; optionsError: boolean; canManage: boolean; initialDate: string;
}) {
  const currentAssignment = history?.items.find((assignment) => assignment.status === 'current') ?? null;
  const currentSiteId = options?.sites.some((site) => site.id === currentAssignment?.site_id)
    ? currentAssignment?.site_id ?? '' : options?.sites[0]?.id ?? '';
  const minimumTransferDate = currentAssignment && currentAssignment.valid_from >= initialDate
    ? addOneDay(currentAssignment.valid_from) : initialDate;
  const openInitial: AssignmentFormState = { tenantId, employmentId: employmentId ?? '', employeeId,
    siteId: currentSiteId,
    departmentId: options?.departments.some((department) => department.id === currentAssignment?.department_id)
      ? currentAssignment?.department_id ?? '' : '',
    jobId: options?.jobs.some((job) => job.id === currentAssignment?.job_id) ? currentAssignment?.job_id ?? '' : '',
    managerId: options?.managers.some((manager) => manager.id === currentAssignment?.manager_employee_id)
      ? currentAssignment?.manager_employee_id ?? '' : '',
    effectiveDate: minimumTransferDate, error: '', attempt: 0 };
  const [formState, formAction] = useActionState(scheduleWorkAssignmentAction, openInitial);
  const [correctionState, correctionAction] = useActionState(correctInitialWorkAssignmentAction, openInitial);
  const [effectiveDateChoice, setEffectiveDateChoice] = useState(formState.effectiveDate);
  const [departmentChoice, setDepartmentChoice] = useState<string | null>(null);
  const departmentId = departmentChoice ?? formState.departmentId;
  const visibleJobs = (options?.jobs ?? []).filter((job) => !job.department_id || job.department_id === departmentId);
  const hasPending = history?.items.some((assignment) => assignment.status === 'scheduled') === true;
  const mayTransfer = canManage && employmentActive && Boolean(currentAssignment) && !hasPending && !historyError;
  const mayCorrectInitial = canManage && employmentActive && Boolean(employmentId)
    && employmentStartDate === initialDate && currentAssignment?.valid_from === initialDate && !hasPending && !historyError;
  const currentChoiceMissing = Boolean(options && currentAssignment && (
    !options.sites.some((site) => site.id === currentAssignment.site_id)
      || (currentAssignment.department_id && !options.departments.some((department) => department.id === currentAssignment.department_id))
      || (currentAssignment.job_id && !options.jobs.some((job) => job.id === currentAssignment.job_id))
      || (currentAssignment.manager_employee_id && !options.managers.some((manager) => manager.id === currentAssignment.manager_employee_id))
  ));

  return <section className="workspace-records-panel assignment-history-panel" aria-labelledby="assignment-history-heading">
    <h2 id="assignment-history-heading">سجل تكليفات العمل</h2>
    <p className="record-meta">تظهر هنا الفروع والأقسام والوظائف التي ارتبطت بعلاقة العمل مع تواريخ سريانها.</p>
    {historyError ? <p className="form-message error-message" role="alert">تعذر تحميل سجل تكليفات العمل. حدّث الصفحة أو تحقق من صلاحية العرض.</p>
      : history?.items.length ? <ol className="assignment-history-list">
        {history.items.map((assignment) => <li key={assignment.id} className="assignment-history-item">
          <div className="assignment-history-heading">
            <strong>{assignment.status === 'initial_scheduled' ? 'سياق العمل عند بدء العلاقة'
              : assignment.status === 'scheduled' ? 'نقل مقرر' : assignment.status === 'current' ? 'السياق الحالي' : 'سياق سابق'}</strong>
            <span className={`entity-status ${assignment.status === 'past' ? 'is-inactive' : 'is-active'}`}>
              {assignment.status === 'initial_scheduled' ? 'يبدأ مع العمل'
                : assignment.status === 'scheduled' ? 'يبدأ لاحقًا' : assignment.status === 'current' ? 'سارٍ الآن' : 'انتهى'}</span>
          </div>
          <dl className="snapshot-grid">
            <div><dt>الفرع</dt><dd>{assignment.site ?? 'غير محدد'}</dd></div>
            {assignment.department && <div><dt>القسم</dt><dd>{assignment.department}</dd></div>}
            {assignment.job && <div><dt>الوظيفة</dt><dd>{assignment.job}</dd></div>}
            {assignment.manager && <div><dt>المدير المباشر</dt><dd>{assignment.manager}</dd></div>}
            <div><dt>يبدأ في</dt><dd><bdi>{assignment.valid_from}</bdi></dd></div>
            {assignment.valid_until && <div><dt>ينتهي السياق قبل</dt><dd><bdi>{assignment.valid_until}</bdi></dd></div>}
          </dl>
          {canManage && assignment.status === 'scheduled' && employmentId && <form action={cancelWorkAssignmentAction} className="assignment-cancel-form">
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="employeeId" value={employeeId} />
            <input type="hidden" name="employmentId" value={employmentId} />
            <input type="hidden" name="assignmentId" value={assignment.id} />
            <SubmitButton label="إلغاء النقل المقرر" pendingLabel="جارٍ الإلغاء…" />
          </form>}
        </li>)}
      </ol> : <p className="empty-state">لا توجد تعيينات عمل مسجلة.</p>}
    {history?.truncated && <p className="record-meta">يعرض هذا الملف أحدث 100 تغيير.</p>}
    {canManage && !employmentId && <p className="form-message">لا توجد علاقة توظيف يمكن تغيير سياق عملها.</p>}
    {canManage && employmentId && !employmentActive && <p className="form-message">لا يمكن تغيير سياق العمل بعد انتهاء علاقة التوظيف.</p>}
    {canManage && employmentId && employmentActive && !currentAssignment && history?.items.some((assignment) => assignment.status === 'initial_scheduled')
      && <p className="form-message">سياق العمل أعلاه مقرر عند بداية العلاقة؛ لا يمكن نقل الموظف قبل بدء العمل.</p>}
    {canManage && employmentId && employmentActive && !currentAssignment
      && !history?.items.some((assignment) => assignment.status === 'initial_scheduled')
      && <p className="form-message">لا يوجد سياق عمل سارٍ يمكن نقل الموظف منه.</p>}
    {canManage && hasPending && <p className="form-message">يوجد نقل مقرر بالفعل. ألغِه من سجل العمل قبل إضافة تغيير آخر.</p>}
    {mayTransfer && <details className="assignment-transfer-details">
      <summary>تغيير الفرع أو القسم أو الوظيفة</summary>
      {optionsError || !options ? <p className="form-message error-message" role="alert">تعذر تحميل الاختيارات المتاحة. حدّث الصفحة أو تحقق من صلاحية إدارة سياق العمل.</p>
        : options.sites.length === 0 ? <p className="empty-state">لا يوجد فرع نشط تابع لجهة توظيف الموظف.</p>
          : <form key={formState.attempt} action={formAction} className="assignment-transfer-form">
            <p className="field-hint">ابدأ من بيانات التكليف الحالي؛ غيّر الحقول التي تحتاج إلى تحديث فقط.</p>
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="employmentId" value={employmentId ?? ''} />
            <input type="hidden" name="employeeId" value={employeeId} />
            <label htmlFor="assignment-site">الفرع</label>
            <select id="assignment-site" name="siteId" required defaultValue={formState.siteId || options.sites[0]?.id}>
              {options.sites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
            </select>
            <label htmlFor="assignment-department">القسم</label>
            <select id="assignment-department" name="departmentId" value={departmentId}
              onChange={(event) => setDepartmentChoice(event.target.value)}>
              <option value="">دون تحديد</option>
              {options.departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}
            </select>
            <label htmlFor="assignment-job">الوظيفة</label>
            <select key={`${formState.attempt}-${departmentId}`} id="assignment-job" name="jobId"
              defaultValue={visibleJobs.some((job) => job.id === formState.jobId) ? formState.jobId : ''}>
              <option value="">دون تحديد</option>
              {visibleJobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}
            </select>
            <label htmlFor="assignment-manager">المدير المباشر (اختياري)</label>
            <select id="assignment-manager" name="managerId" defaultValue={formState.managerId}>
              <option value="">دون تحديد</option>
              {options.managers.filter((manager) => manager.start_date <= effectiveDateChoice).map((manager) =>
                <option key={manager.id} value={manager.id}>{manager.name}{manager.start_date > initialDate ? ` (يبدأ ${manager.start_date})` : ''}</option>)}
            </select>
            <label htmlFor="assignment-effective-date">تاريخ سريان التغيير</label>
            <input id="assignment-effective-date" name="effectiveDate" type="date" required min={minimumTransferDate}
              value={effectiveDateChoice} onChange={(event) => setEffectiveDateChoice(event.target.value)} />
            {(options.sites_truncated || options.departments_truncated || options.jobs_truncated || options.managers_truncated)
              && <p className="field-hint">نعرض حتى 1000 اختيار لكل قائمة. راجع دليل الشركة إذا لم يظهر السجل المطلوب.</p>}
            {currentChoiceMissing && <p className="field-hint">بعض بيانات التكليف الحالي لم تعد ضمن الاختيارات النشطة؛ اختر بديلًا مناسبًا قبل الحفظ.</p>}
            {formState.error && <p className="form-message error-message" role="alert">{formState.error}</p>}
            <p className="field-hint">يبدأ السياق الجديد في التاريخ المحدد، وينتهي السياق الحالي عند بداية ذلك اليوم.</p>
            <div className="workspace-form-actions"><SubmitButton label="حفظ تغيير العمل" pendingLabel="جارٍ حفظ التغيير…" /></div>
          </form>}
    </details>}
    {mayCorrectInitial && <details className="assignment-transfer-details">
      <summary>تصحيح بيانات العمل اليوم</summary>
      {optionsError || !options ? <p className="form-message error-message" role="alert">تعذر تحميل الاختيارات المتاحة. حدّث الصفحة أو تحقق من صلاحية إدارة سياق العمل.</p>
        : options.sites.length === 0 ? <p className="empty-state">لا يوجد فرع نشط تابع لجهة توظيف الموظف.</p>
          : <form key={correctionState.attempt} action={correctionAction} className="assignment-transfer-form">
            <p className="field-hint">يُتاح هذا التصحيح في يوم بداية العمل فقط، ويحفظ سجلًا قبل التعديل وبعده.</p>
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="employmentId" value={employmentId ?? ''} />
            <input type="hidden" name="employeeId" value={employeeId} />
            <label htmlFor="correction-site">الفرع</label>
            <select id="correction-site" name="siteId" required defaultValue={correctionState.siteId || options.sites[0]?.id}>
              {options.sites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
            </select>
            <label htmlFor="correction-department">القسم</label>
            <select id="correction-department" name="departmentId" defaultValue={correctionState.departmentId}>
              <option value="">دون تحديد</option>
              {options.departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}
            </select>
            <label htmlFor="correction-job">الوظيفة</label>
            <select id="correction-job" name="jobId" defaultValue={correctionState.jobId}>
              <option value="">دون تحديد</option>
              {options.jobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}
            </select>
            <label htmlFor="correction-manager">المدير المباشر (اختياري)</label>
            <select id="correction-manager" name="managerId" defaultValue={correctionState.managerId}>
              <option value="">دون تحديد</option>
              {options.managers.filter((manager) => manager.start_date <= initialDate).map((manager) =>
                <option key={manager.id} value={manager.id}>{manager.name}</option>)}
            </select>
            {correctionState.error && <p className="form-message error-message" role="alert">{correctionState.error}</p>}
            <div className="workspace-form-actions"><SubmitButton label="حفظ تصحيح بيانات العمل" pendingLabel="جارٍ حفظ التصحيح…" /></div>
          </form>}
    </details>}
  </section>;
}

function addOneDay(value: string) {
  const date = new Date(`${value}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}
