'use client';

import { Badge, Disclosure, Field, Input, Message, Panel, RecordCard, Select } from '@/components/ui';
import { useState, useActionState } from 'react';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import { useOfflineSubmission } from '@/components/offline-submission';
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
  const { blockOfflineSubmission } = useOfflineSubmission();
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

  return <Panel className="assignment-history-panel" aria-labelledby="assignment-history-heading">
    <h2 id="assignment-history-heading">سجل تغييرات بيانات العمل</h2>
    <p className="record-meta">تظهر هنا الفروع والأقسام والوظائف التي ارتبطت بعلاقة العمل مع تواريخ سريانها.</p>
    {historyError ? <Message tone="bad"  role="alert">تعذر تحميل سجل تغييرات بيانات العمل. حدّث الصفحة أو تحقق من صلاحية العرض.</Message>
      : history?.items.length ? <ol className="assignment-history-list">
        {history.items.map((assignment) => <RecordCard key={assignment.id} className="assignment-history-item">
          <div className="assignment-history-heading">
            <strong>{assignment.status === 'initial_scheduled' ? 'بيانات العمل عند بدء التوظيف'
              : assignment.status === 'scheduled' ? 'نقل مقرر' : assignment.status === 'current' ? 'بيانات العمل الحالية' : 'بيانات عمل سابقة'}</strong>
            <Badge className={`entity-status ${assignment.status === 'past' ? 'is-inactive' : 'is-active'}`}>
              {assignment.status === 'initial_scheduled' ? 'يبدأ مع العمل'
                : assignment.status === 'scheduled' ? 'يبدأ لاحقًا' : assignment.status === 'current' ? 'سارٍ الآن' : 'انتهى'}</Badge>
          </div>
          <dl className="snapshot-grid">
            <div><dt>الفرع</dt><dd>{assignment.site ?? 'غير محدد'}</dd></div>
            {assignment.department && <div><dt>القسم</dt><dd>{assignment.department}</dd></div>}
            {assignment.job && <div><dt>الوظيفة</dt><dd>{assignment.job}</dd></div>}
            {assignment.manager && <div><dt>المدير المباشر</dt><dd>{assignment.manager}</dd></div>}
            <div><dt>يبدأ في</dt><dd><bdi>{assignment.valid_from}</bdi></dd></div>
            {assignment.valid_until && <div><dt>تنتهي هذه البيانات قبل</dt><dd><bdi>{assignment.valid_until}</bdi></dd></div>}
          </dl>
          {canManage && assignment.status === 'scheduled' && employmentId && <form action={cancelWorkAssignmentAction} className="assignment-cancel-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="employeeId" value={employeeId} />
            <input type="hidden" name="employmentId" value={employmentId} />
            <input type="hidden" name="assignmentId" value={assignment.id} />
            <OfflineSubmitButton label="إلغاء النقل المقرر" pendingLabel="جارٍ الإلغاء…" />
          </form>}
        </RecordCard>)}
      </ol> : <Message tone="neutral" >لا توجد بيانات فرع أو قسم أو وظيفة مسجلة.</Message>}
    {history?.truncated && <p className="record-meta">يعرض هذا الملف أحدث 100 تغيير.</p>}
    {canManage && !employmentId && <Message tone="info" >لا يوجد توظيف مسجل لتغيير بيانات العمل.</Message>}
    {canManage && employmentId && !employmentActive && <Message tone="info" >لا يمكن تغيير بيانات العمل بعد انتهاء التوظيف.</Message>}
    {canManage && employmentId && employmentActive && !currentAssignment && history?.items.some((assignment) => assignment.status === 'initial_scheduled')
      && <Message tone="info" >تبدأ بيانات العمل الموضحة عند بدء التوظيف؛ لا يمكن نقل الموظف قبل هذا التاريخ.</Message>}
    {canManage && employmentId && employmentActive && !currentAssignment
      && !history?.items.some((assignment) => assignment.status === 'initial_scheduled')
      && <Message tone="info" >لا توجد بيانات عمل حالية يمكن نقل الموظف منها.</Message>}
    {canManage && hasPending && <Message tone="info" >يوجد نقل مقرر بالفعل. ألغِه من سجل العمل قبل إضافة تغيير آخر.</Message>}
    {mayTransfer && <Disclosure className="assignment-transfer-details" summary={<>تغيير الفرع أو القسم أو الوظيفة</>}>
      {optionsError || !options ? <Message tone="bad"  role="alert">تعذر تحميل الاختيارات المتاحة. حدّث الصفحة أو تحقق من صلاحية تعديل بيانات العمل.</Message>
        : options.sites.length === 0 ? <Message tone="neutral" >لا يوجد فرع نشط تابع لجهة عمل الموظف.</Message>
          : <form key={formState.attempt} action={formAction} className="assignment-transfer-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
            <p className="field-hint">عدّل الفرع أو القسم أو الوظيفة المطلوبة، واترك بقية البيانات كما هي.</p>
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="employmentId" value={employmentId ?? ''} />
            <input type="hidden" name="employeeId" value={employeeId} />
            <Field id="assignment-site" label={<>الفرع</>} required><Select id="assignment-site" name="siteId" required defaultValue={formState.siteId || options.sites[0]?.id}>
              {options.sites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
            </Select></Field>
            <Field id="assignment-department" label={<>القسم</>}><Select id="assignment-department" name="departmentId" value={departmentId}
              onChange={(event) => setDepartmentChoice(event.target.value)}>
              <option value="">دون تحديد</option>
              {options.departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}
            </Select></Field>
            <Field id="assignment-job" label={<>الوظيفة</>}><Select key={`${formState.attempt}-${departmentId}`} id="assignment-job" name="jobId"
              defaultValue={visibleJobs.some((job) => job.id === formState.jobId) ? formState.jobId : ''}>
              <option value="">دون تحديد</option>
              {visibleJobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}
            </Select></Field>
            <Field id="assignment-manager" label={<>المدير المباشر (اختياري)</>}><Select id="assignment-manager" name="managerId" defaultValue={formState.managerId}>
              <option value="">دون تحديد</option>
              {options.managers.filter((manager) => manager.start_date <= effectiveDateChoice).map((manager) =>
                <option key={manager.id} value={manager.id}>{manager.name}{manager.start_date > initialDate ? ` (يبدأ ${manager.start_date})` : ''}</option>)}
            </Select></Field>
            <Field id="assignment-effective-date" label={<>تاريخ سريان التغيير</>} required><Input id="assignment-effective-date" name="effectiveDate" type="date" required min={minimumTransferDate}
              value={effectiveDateChoice} onChange={(event) => setEffectiveDateChoice(event.target.value)} /></Field>
            {(options.sites_truncated || options.departments_truncated || options.jobs_truncated || options.managers_truncated)
              && <p className="field-hint">نعرض حتى 1000 اختيار لكل قائمة. راجع دليل الشركة إذا لم يظهر السجل المطلوب.</p>}
            {currentChoiceMissing && <p className="field-hint">بعض بيانات العمل الحالية لم تعد ضمن الاختيارات النشطة؛ اختر بديلًا مناسبًا قبل الحفظ.</p>}
            {formState.error && <Message tone="bad"  role="alert">{formState.error}</Message>}
            <p className="field-hint">تبدأ بيانات العمل الجديدة في التاريخ المحدد، وتنتهي البيانات الحالية عند بداية ذلك اليوم.</p>
            <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ تغيير العمل" pendingLabel="جارٍ حفظ التغيير…" /></div>
          </form>}
    </Disclosure>}
    {mayCorrectInitial && <Disclosure className="assignment-transfer-details" summary={<>تصحيح بيانات العمل اليوم</>}>
      {optionsError || !options ? <Message tone="bad"  role="alert">تعذر تحميل الاختيارات المتاحة. حدّث الصفحة أو تحقق من صلاحية تعديل بيانات العمل.</Message>
        : options.sites.length === 0 ? <Message tone="neutral" >لا يوجد فرع نشط تابع لجهة عمل الموظف.</Message>
          : <form key={correctionState.attempt} action={correctionAction} className="assignment-transfer-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
            <p className="field-hint">يُتاح هذا التصحيح في يوم بداية العمل فقط، ويحفظ سجلًا قبل التعديل وبعده.</p>
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="employmentId" value={employmentId ?? ''} />
            <input type="hidden" name="employeeId" value={employeeId} />
            <Field id="correction-site" label={<>الفرع</>} required><Select id="correction-site" name="siteId" required defaultValue={correctionState.siteId || options.sites[0]?.id}>
              {options.sites.map((site) => <option key={site.id} value={site.id}>{site.name}</option>)}
            </Select></Field>
            <Field id="correction-department" label={<>القسم</>}><Select id="correction-department" name="departmentId" defaultValue={correctionState.departmentId}>
              <option value="">دون تحديد</option>
              {options.departments.map((department) => <option key={department.id} value={department.id}>{department.name}</option>)}
            </Select></Field>
            <Field id="correction-job" label={<>الوظيفة</>}><Select id="correction-job" name="jobId" defaultValue={correctionState.jobId}>
              <option value="">دون تحديد</option>
              {options.jobs.map((job) => <option key={job.id} value={job.id}>{job.name}</option>)}
            </Select></Field>
            <Field id="correction-manager" label={<>المدير المباشر (اختياري)</>}><Select id="correction-manager" name="managerId" defaultValue={correctionState.managerId}>
              <option value="">دون تحديد</option>
              {options.managers.filter((manager) => manager.start_date <= initialDate).map((manager) =>
                <option key={manager.id} value={manager.id}>{manager.name}</option>)}
            </Select></Field>
            {correctionState.error && <Message tone="bad"  role="alert">{correctionState.error}</Message>}
            <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ تصحيح بيانات العمل" pendingLabel="جارٍ حفظ التصحيح…" /></div>
          </form>}
    </Disclosure>}
  </Panel>;
}

function addOneDay(value: string) {
  const date = new Date(`${value}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}
