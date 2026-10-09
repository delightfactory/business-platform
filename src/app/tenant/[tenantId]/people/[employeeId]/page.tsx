import { Avatar, Badge, ButtonLink, Field, Input, Message, Panel, RecordCard, Select } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';

import { EmployeeProfileTabs, type ProfileArea } from './EmployeeProfileTabs';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { WorkAssignmentPanel, type AssignmentHistory, type TransferOptions } from './WorkAssignmentPanel';
import { CompensationPanel, type CompensationHistory, type CompensationOptions } from './CompensationPanel';
import { EmploymentLifecyclePanel, type EmploymentHistory, type RehireOptions } from './EmploymentLifecyclePanel';
import { EmployeeUserLinkPanel, type AccountProvision, type LinkSnapshot, type Options as EmployeeUserLinkOptions } from './EmployeeUserLinkPanel';
import { assignAttendancePolicyOverrideAction, assignWorkPolicyAction, cancelAttendancePolicyOverrideAction } from '../work-policy-actions';

export const dynamic = 'force-dynamic';
type Employment = { id: string; employer: string; start_date: string; end_date: string | null; status: string };
type Assignment = { id: string; site: string; department: string | null; job: string | null; manager: string | null; valid_from: string };
type Employee = { id: string; code: string; name: string; status: string; employment: Employment | null; assignment: Assignment | null };

export default async function EmployeePage({ params, searchParams }: {
  params: Promise<{ tenantId: string; employeeId: string }>;
  searchParams: Promise<{ state?: string; assignment?: string; compensation?: string; employment?: string; userLink?: string; linkQuery?: string; linkPage?: string; account?: string; policy?: string; policyOverride?: string }>;
}) {
  const { tenantId, employeeId } = await params;
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/${employeeId}`)}`);
  const [employeeResult, accessResult] = await Promise.all([
    supabase.rpc('people_employee_snapshot', { p_tenant_id: tenantId, p_employee_id: employeeId }),
    supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId }),
  ]);
  if (employeeResult.error || !employeeResult.data || typeof employeeResult.data !== 'object'
    || Array.isArray(employeeResult.data) || accessResult.error || !accessResult.data) {
    return <Unavailable tenantId={tenantId} />;
  }
  const employee = employeeResult.data as unknown as Employee;
  const access = accessResult.data as Record<string, unknown>;
  const employmentId = employee.employment?.id ?? null;
  const canViewCompensation = access.can_view_compensation === true;
  const canManageCompensation = access.can_manage_compensation === true;
  const canManageWorkContext = access.can_manage_org === true;
  const canManageLifecycle = access.can_manage === true && access.can_manage_employment === true
    && canManageWorkContext && canManageCompensation;
  const linkQuery = typeof query.linkQuery === 'string' ? query.linkQuery.slice(0, 100) : '';
  const linkPage = Math.min(1000, Math.max(1, Number.parseInt(query.linkPage ?? '1', 10) || 1));
  const [historyResult, optionsResult, compensationHistoryResult, compensationOptionsResult, employmentHistoryResult, rehireOptionsResult, linkSnapshotResult, linkOptionsResult, membershipSnapshotResult, workPolicyResult] = await Promise.all([
    employmentId ? supabase.rpc('people_work_assignment_history', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    canManageWorkContext && employmentId ? supabase.rpc('people_work_assignment_options', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    canViewCompensation && employmentId ? supabase.rpc('people_compensation_history', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    canManageCompensation && employmentId ? supabase.rpc('people_compensation_options', {
      p_tenant_id: tenantId, p_employment_id: employmentId,
    }) : Promise.resolve({ data: null, error: null }),
    supabase.rpc('people_employment_history', { p_tenant_id: tenantId, p_employee_id: employeeId }),
    canManageLifecycle && employee.status === 'ended'
      ? supabase.rpc('people_onboarding_options', { p_tenant_id: tenantId })
      : Promise.resolve({ data: null, error: null }),
    supabase.rpc('people_employee_user_link_snapshot', { p_tenant_id: tenantId, p_employee_id: employeeId }),
    access.can_manage === true ? supabase.rpc('people_employee_user_link_options', {
      p_tenant_id: tenantId, p_employee_id: employeeId, p_query: linkQuery, p_page: linkPage,
    }) : Promise.resolve({ data: null, error: null }),
    access.can_manage === true ? supabase.rpc('tenant_membership_snapshot', { p_tenant_id: tenantId })
      : Promise.resolve({ data: null, error: null }),
    employmentId ? supabase.rpc('people_work_policy_panel', { p_tenant_id: tenantId, p_employment_id: employmentId }) : Promise.resolve({ data: null, error: null }),
  ]);
  const linkSnapshot = linkSnapshotResult.data && typeof linkSnapshotResult.data === 'object'
    ? linkSnapshotResult.data as unknown as LinkSnapshot : null;
  const linkOptions = linkOptionsResult.data && typeof linkOptionsResult.data === 'object'
    ? linkOptionsResult.data as unknown as EmployeeUserLinkOptions : null;
  const membershipSnapshot = membershipSnapshotResult.data && typeof membershipSnapshotResult.data === 'object'
    ? membershipSnapshotResult.data as Record<string, unknown> : null;
  const canProvisionEmployeeAccount = access.can_manage === true && membershipSnapshot?.can_manage_members === true;
  const accountProvisionResult = canProvisionEmployeeAccount ? await supabase.rpc('people_employee_account_provision_snapshot', {
    p_tenant_id: tenantId, p_employee_id: employeeId,
  }) : { data: null, error: null };
  const accountProvision = accountProvisionResult.data && typeof accountProvisionResult.data === 'object'
    ? accountProvisionResult.data as unknown as AccountProvision : null;
  const assignmentHistory = historyResult.data && typeof historyResult.data === 'object'
    ? historyResult.data as unknown as AssignmentHistory : null;
  const transferOptions = optionsResult.data && typeof optionsResult.data === 'object'
    ? optionsResult.data as unknown as TransferOptions : null;
  const historyError = Boolean(employmentId && (historyResult.error || !assignmentHistory));
  const optionsError = Boolean(canManageWorkContext && employmentId && (optionsResult.error || !transferOptions));
  const compensationHistory = compensationHistoryResult.data && typeof compensationHistoryResult.data === 'object'
    ? compensationHistoryResult.data as unknown as CompensationHistory : null;
  const compensationOptions = compensationOptionsResult.data && typeof compensationOptionsResult.data === 'object'
    ? compensationOptionsResult.data as unknown as CompensationOptions : null;
  const compensationHistoryError = Boolean(canViewCompensation && employmentId
    && (compensationHistoryResult.error || !compensationHistory));
  const compensationOptionsError = Boolean(canManageCompensation && employmentId
    && (compensationOptionsResult.error || !compensationOptions));
  const employmentHistory = employmentHistoryResult.data && typeof employmentHistoryResult.data === 'object'
    ? employmentHistoryResult.data as unknown as EmploymentHistory : null;
  const employmentHistoryError = Boolean(employmentHistoryResult.error || !employmentHistory);
  const rehireOptions = rehireOptionsResult.data && typeof rehireOptionsResult.data === 'object'
    ? rehireOptionsResult.data as unknown as RehireOptions : null;
  const rehireOptionsError = Boolean(canManageLifecycle && employee.status === 'ended'
    && (rehireOptionsResult.error || !rehireOptions));
  const today = cairoToday();
  const policyOverrideMinDate = employee.employment?.start_date && employee.employment.start_date > today ? employee.employment.start_date : today;
  const workPolicyPanel = workPolicyResult.data && typeof workPolicyResult.data === 'object'
    ? workPolicyResult.data as {
      history: { assignment_id: string; policy_id: string | null; version: number | null; name: string | null; code: string | null; valid_from: string; valid_until: string | null }[];
      options: { id: string; code: string; name: string; version: number }[];
      overrides: { id: string; policy_id: string; version: number; name: string; code: string; valid_from: string; valid_through: string; reason: string; cancelled_at: string | null; can_cancel: boolean }[];
      can_assign: boolean; can_manage_catalog: boolean;
    } : null;
  const correctionAccess=await supabase.rpc('payroll_correction_access',{p_tenant:tenantId});
  const initialTab: ProfileArea = query.userLink || query.account || query.linkQuery !== undefined || query.linkPage !== undefined
    ? 'account' : query.employment ? 'employment'
      : query.compensation && (canViewCompensation || canManageCompensation) ? 'compensation'
        : query.assignment || query.policy || query.policyOverride ? 'work' : 'overview';
  const overview = <>
    <Panel  aria-labelledby="employment-heading">
      <h2 id="employment-heading">{employee.status === 'scheduled' ? 'العمل المقرر' : employee.status === 'ended' ? 'آخر علاقة عمل' : 'العمل الحالي'}</h2>
      {employee.employment ? <dl className="snapshot-grid">
        <div><dt>جهة التوظيف</dt><dd>{employee.employment.employer}</dd></div>
        <div><dt>تاريخ البداية</dt><dd><bdi>{employee.employment.start_date}</bdi></dd></div>
        <div><dt>الفرع</dt><dd>{employee.assignment?.site ?? 'غير محدد'}</dd></div>
        {employee.assignment?.department && <div><dt>القسم</dt><dd>{employee.assignment.department}</dd></div>}
        {employee.assignment?.job && <div><dt>الوظيفة</dt><dd>{employee.assignment.job}</dd></div>}
        {employee.assignment?.manager && <div><dt>المدير المباشر</dt><dd>{employee.assignment.manager}</dd></div>}
      </dl> : <p>لا توجد علاقة توظيف نشطة لهذا الموظف.</p>}
      {employee.status === 'scheduled' && employee.employment && <p className="record-meta">
        بيانات الفرع والقسم والوظيفة المعروضة مقررة لتبدأ مع العمل في <bdi>{employee.employment.start_date}</bdi>؛ لم تبدأ بعد.
      </p>}
    </Panel>
  </>;
  const work = <>
    <WorkAssignmentPanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId}
      employmentStartDate={employee.employment?.start_date ?? null}
      employmentActive={employee.employment?.status === 'active'}
      history={assignmentHistory} historyError={historyError} options={transferOptions} optionsError={optionsError}
      canManage={canManageWorkContext} initialDate={today} />
    {workPolicyPanel && <Panel  aria-labelledby="work-policy-heading">
      <h2 id="work-policy-heading">سياسة الدوام</h2>
      <p className="record-meta">تعرض القائمة سياسة الدوام الأساسية. أما التغيير لفترة محددة فيُسجل للحضور من دون تعديل بيانات العمل الأساسية.</p>
      {workPolicyPanel.history.length ? <ol className="assignment-history-list">{workPolicyPanel.history.map((row) => <RecordCard className="assignment-history-item" key={row.assignment_id}>
        <strong>{row.name ? `${row.name} · ${row.code} · الإصدار ${row.version}` : 'دون سياسة دوام محددة'}</strong>
        <p>من <bdi>{row.valid_from}</bdi>{row.valid_until ? ` إلى ما قبل ${row.valid_until}` : ' · مستمر'}</p>
      </RecordCard>)}</ol> : <Message tone="neutral" >لا يوجد سجل سياسة دوام.</Message>}
      {workPolicyPanel.can_assign && employmentId && employee.employment?.status === 'active' && !workPolicyPanel.options.length && <Message tone="info">لا توجد قوالب دوام متاحة للاختيار؛ لذلك لا يمكن حفظ سياسة جديدة الآن. {workPolicyPanel.can_manage_catalog ? 'أضف قالبًا من إدارة قوالب سياسات العمل أدناه.' : 'اطلب من مسؤول الشركة تجهيز قالب دوام.'}</Message>}
      {workPolicyPanel.can_assign && employmentId && employee.employment?.status === 'active' && <OfflineForm action={assignWorkPolicyAction} className="work-policy-assignment-form">
        <input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="employeeId" value={employee.id}/><input type="hidden" name="employmentId" value={employmentId}/>
        <div className="work-policy-assignment-field"><Field id="work-policy-id" label={<>قالب الدوام</>} required><Select id="work-policy-id" name="policyId" required defaultValue=""><option value="" disabled>اختر قالبًا متاحًا</option>{workPolicyPanel.options.map((item)=><option key={item.id} value={item.id}>{item.name} · {item.code} · إصدار {item.version}</option>)}</Select></Field></div>
        <div className="work-policy-assignment-field"><Field id="work-policy-date" label={<>تاريخ بدء السريان</>} required><Input id="work-policy-date" type="date" name="effectiveDate" min={today} defaultValue={today} required/></Field></div>
        <p className="field-hint">إذا كانت هذه أول بيانات عمل ويبدأ سريانها اليوم، تُصحح السياسة في سجلها. وفي غير ذلك يُسجل تغيير بتاريخ سريانه مع حفظ السجل السابق.</p>
        {query.policy === 'payroll-correction' && <Message tone="bad"  role="alert">يمس هذا التغيير تاريخ راتب مقفل. لم تتغير البيانات؛ راجع مسؤول تصحيح الرواتب لإعداد مقترح التصحيح بتاريخ سريان محدد للفترة نفسها.</Message>}
        {query.policy === 'failed' && <Message tone="bad"  role="alert">تعذر تعيين السياسة. تحقق من الإتاحة، التاريخ، وعدم وجود تغيير آخر مقرر في بيانات العمل.</Message>}
        {query.policy === 'pending' && <Message tone="bad"  role="alert">يوجد تغيير عمل مقرر؛ عالجه أولًا قبل جدولة سياسة أخرى.</Message>}
        {query.policy === 'materialized' && <Message tone="bad"  role="alert">بدأ تسجيل حضور لهذا اليوم وفق سياسة الدوام الحالية؛ اختر تاريخ سريان لاحقًا لم يُفتح للحضور.</Message>}
        <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ سياسة الدوام" pendingLabel="جارٍ حفظ السياسة…" disabled={!workPolicyPanel.options.length} /></div>
      </OfflineForm>}
      {workPolicyPanel.can_manage_catalog && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/work-policies`}>إدارة قوالب سياسات العمل</ButtonLink>}
      <h3 className="section-subheading">تغيير الدوام لفترة محددة</h3>
      <p className="record-meta">يسري التغيير على أيام العمل داخل الفترة، من دون تعديل بيانات عمل الموظف الأساسية. تُحفظ نسخة القالب الحالية، ولا يمكن تغيير يوم سبق فتحه للحضور.</p>
      {workPolicyPanel.overrides.length ? <ol className="assignment-history-list">{workPolicyPanel.overrides.map((override) => <RecordCard className="assignment-history-item" key={override.id}>
        <strong>{override.name} · {override.code} · الإصدار {override.version}</strong>
        <p>من <bdi>{override.valid_from}</bdi> إلى <bdi>{override.valid_through}</bdi>{override.cancelled_at ? ' · ملغى' : ''}</p>
        <p>{override.reason}</p>
        {override.can_cancel && workPolicyPanel.can_manage_catalog && <OfflineForm action={cancelAttendancePolicyOverrideAction} className="work-policy-assignment-form">
          <input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="employeeId" value={employee.id}/><input type="hidden" name="overrideId" value={override.id}/>
          <div className="work-policy-assignment-field"><Field id={`override-cancel-reason-${override.id}`} label={<>سبب الإلغاء</>} required><Input id={`override-cancel-reason-${override.id}`} name="cancelReason" minLength={3} maxLength={500} required/></Field></div>
          <div className="workspace-form-actions"><OfflineSubmitButton className="secondary-button" label="إلغاء التغيير المقرر" pendingLabel="جارٍ الإلغاء…" /></div>
        </OfflineForm>}
      </RecordCard>)}</ol> : <Message tone="neutral" >لا توجد تغييرات دوام لفترات محددة.</Message>}
      {workPolicyPanel.can_manage_catalog && employmentId && employee.employment?.status === 'active' && <OfflineForm action={assignAttendancePolicyOverrideAction} className="work-policy-assignment-form">
        <input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="employeeId" value={employee.id}/><input type="hidden" name="employmentId" value={employmentId}/>
        <div className="work-policy-assignment-field"><Field id="policy-override-id" label={<>قالب الدوام للفترة</>} required><Select id="policy-override-id" name="policyId" required defaultValue=""><option value="" disabled>اختر قالبًا متاحًا</option>{workPolicyPanel.options.map((item)=><option key={item.id} value={item.id}>{item.name} · {item.code} · إصدار {item.version}</option>)}</Select></Field></div>
        <div className="work-policy-assignment-field"><Field id="policy-override-from" label={<>من تاريخ</>} required><Input id="policy-override-from" type="date" name="validFrom" min={policyOverrideMinDate} defaultValue={policyOverrideMinDate} required/></Field></div>
        <div className="work-policy-assignment-field"><Field id="policy-override-through" label={<>إلى تاريخ</>} required><Input id="policy-override-through" type="date" name="validThrough" min={policyOverrideMinDate} defaultValue={policyOverrideMinDate} required/></Field></div>
        <div className="work-policy-assignment-field"><Field id="policy-override-reason" label={<>سبب التغيير</>} required><Input id="policy-override-reason" name="reason" minLength={3} maxLength={500} required/></Field></div>
        {query.policyOverride === 'invalid' && <Message tone="bad"  role="alert">راجع القالب والتاريخين، واجعل الفترة 90 يومًا أو أقل، واكتب سببًا واضحًا.</Message>}
        {query.policyOverride === 'overlap' && <Message tone="bad"  role="alert">تتداخل الفترة مع تغيير دوام محفوظ. اختر فترة أخرى.</Message>}
        {query.policyOverride === 'materialized' && <Message tone="bad"  role="alert">بدأ فتح الحضور لأحد أيام الفترة؛ لم يُغيّر أي سجل. اختر تواريخ لم تُفتح بعد.</Message>}
        {query.policyOverride === 'historical' && <Message tone="bad"  role="alert">لا يمكن إضافة تغيير يبدأ بتاريخ سابق. اختر اليوم أو تاريخًا لاحقًا.</Message>}
        {(query.policyOverride === 'failed' || query.policyOverride === 'forbidden' || query.policyOverride === 'cancel-failed') && <Message tone="bad"  role="alert">تعذر حفظ التغيير. تحقق من صلاحيتك وحالة العمل والقالب، ثم حدّث الصفحة.</Message>}
        <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ تغيير الدوام للفترة" pendingLabel="جارٍ حفظ التغيير…" disabled={!workPolicyPanel.options.length} /></div>
      </OfflineForm>}
    </Panel>}
  </>;
  const compensation = <>
    {(canViewCompensation || canManageCompensation) && <CompensationPanel tenantId={tenantId} employeeId={employee.id}
      employmentId={employmentId} canView={canViewCompensation} canManage={canManageCompensation}
      history={compensationHistory} historyError={compensationHistoryError}
      options={compensationOptions} optionsError={compensationOptionsError} today={today} />}
  </>;
  const employment = <>
    <EmploymentLifecyclePanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId}
      employmentStatus={employee.employment?.status ?? null} workforceStatus={employee.status}
      employmentStartDate={employee.employment?.start_date ?? null}
      previousEndDate={employee.employment?.end_date ?? null} canManage={canManageLifecycle} today={today}
      history={employmentHistory} historyError={employmentHistoryError}
      rehireOptions={rehireOptions} optionsError={rehireOptionsError} />
  </>;
  const account = <>
    <EmployeeUserLinkPanel tenantId={tenantId} employeeId={employee.id} canManage={access.can_manage === true}
      canInvite={membershipSnapshot?.can_manage_members === true}
      canProvisionAccount={canProvisionEmployeeAccount}
      accountProvision={accountProvision} accountProvisionError={Boolean(canProvisionEmployeeAccount && (accountProvisionResult.error || !accountProvision))}
      requestKey={crypto.randomUUID()} accountState={query.account}
      snapshot={linkSnapshot} snapshotError={Boolean(linkSnapshotResult.error || !linkSnapshot)}
      options={linkOptions} optionsError={Boolean(access.can_manage === true && (linkOptionsResult.error || !linkOptions))}
      query={linkQuery} page={linkPage} state={query.userLink} />
  </>;
  return <PageFrame footer="الموارد البشرية">
    {query.state === 'created' && <FeedbackToast key={employeeId} message="تمت إضافة الموظف وحفظ بيانات عمله." />}
    {query.assignment === 'scheduled' && <FeedbackToast key="assignment-scheduled" message="تم حفظ نقل العمل وسيبدأ في التاريخ المحدد." />}
    {query.assignment === 'transferred' && <FeedbackToast key="assignment-transferred" message="تم تحديث بيانات العمل اعتبارًا من اليوم." />}
    {query.assignment === 'corrected' && <FeedbackToast key="assignment-corrected" message="تم تصحيح بيانات العمل لهذا اليوم وحفظ تفاصيل التعديل." />}
    {query.assignment === 'cancelled' && <FeedbackToast key="assignment-cancelled" message="تم إلغاء النقل المقرر واستعادة بيانات العمل السابقة." />}
    {query.assignment === 'cancel-error' && <FeedbackToast key="assignment-cancel-error" message="تعذر إلغاء النقل. حدّث الصفحة للتحقق من حالته." />}
    {query.compensation === 'changed' && <FeedbackToast key="compensation-changed" message="تم تحديث الأجر الأساسي اعتبارًا من اليوم." />}
    {query.compensation === 'corrected' && <FeedbackToast key="compensation-corrected" message="تم حفظ التعديل بتاريخ سابق. راجع أي فترة رواتب مقفلة؛ التواريخ المقفلة تخضع لمقترح تصحيح مستقل ومراجعة المسيرات المحفوظة المتأثرة." />}
    {query.compensation === 'initial_corrected' && <FeedbackToast key="compensation-initial-corrected" message="تم تصحيح الأجر الأول لهذا اليوم وحُفظ سجل التعديل." />}
    {query.compensation === 'scheduled' && <FeedbackToast key="compensation-scheduled" message="تم حفظ تغيير الأجر وسيبدأ في التاريخ المحدد." />}
    {query.compensation === 'cancelled' && <FeedbackToast key="compensation-cancelled" message="تم إلغاء تغيير الأجر المقرر واستعادة الأجر السابق." />}
    {query.compensation === 'cancel-error' && <FeedbackToast key="compensation-cancel-error" message="تعذر إلغاء تغيير الأجر. حدّث الصفحة للتحقق من حالته." />}
    {query.employment === 'ended' && <FeedbackToast key="employment-ended" message="تم إنهاء علاقة العمل. راجع الرواتب والإجازات وسلف الموظف للتسوية والمتابعة اللازمة." />}
    {query.employment === 'rehired' && <FeedbackToast key="employment-rehired" message="تم إنشاء علاقة عمل جديدة للموظف. راجع الرواتب والإجازات وسلف الموظف بشأن الفترة السابقة." />}
    {query.policy === 'assigned' && <FeedbackToast key="policy-assigned" message="تم حفظ سياسة الدوام وسجل تاريخ سريانها."/>}
    {query.policy === 'invalid' && <FeedbackToast key="policy-invalid" message="تحقق من بيانات سياسة الدوام."/>}
    {query.policyOverride === 'assigned' && <FeedbackToast key="policy-override-assigned" message="تم حفظ سياسة الدوام للفترة المحددة."/>}
    {query.policyOverride === 'cancelled' && <FeedbackToast key="policy-override-cancelled" message="تم إلغاء التغيير المقرر للدوام."/>}
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink>
    <header className="workspace-page-heading"><div className="employee-profile-identity"><Avatar name={employee.name} size={64} status={employee.status === 'active' ? 'ok' : 'neutral'} /><div><p className="eyebrow">ملف الموظف</p><h1>{employee.name}</h1>
      <p>رمز الموظف: <bdi>{employee.code}</bdi></p></div></div>
      <Badge className={`entity-status ${employee.status === 'active' ? 'is-active' : 'is-inactive'}`}>
        {employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'سيبدأ قريبًا' : employee.status === 'ended' ? 'انتهت خدمته' : 'غير نشط'}</Badge>
    </header>
    <EmployeeProfileTabs initialTab={initialTab} areas={[
      { value: 'overview', label: 'نظرة عامة', content: overview },
      { value: 'work', label: 'العمل والتعيينات', content: work },
      ...(canViewCompensation || canManageCompensation
        ? [{ value: 'compensation' as const, label: 'الأجر الأساسي', content: compensation }] : []),
      { value: 'account', label: 'الحساب والدخول', content: account },
      { value: 'employment', label: 'علاقة العمل والسجل', content: employment },
    ]} />
    <Panel  aria-label="الخطوة التالية">
      <h2>الخطوة التالية</h2>{correctionAccess.data?.can_correct&&<ButtonLink variant="ghost"  href={`/tenant/${tenantId}/payroll/corrections?${new URLSearchParams({person:employee.id})}`}>تصحيح مصدر يمس راتبًا مقفلًا</ButtonLink>}<p>تأكد من بيانات العمل المسجلة، ثم تابع إلى دليل الموظفين أو أضف موظفًا آخر.</p>
      <div className="workspace-form-actions"><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>عرض جميع الموظفين</ButtonLink>
        {access.can_manage === true && access.can_manage_employment === true && access.can_manage_compensation === true &&
          <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/new`}>إضافة موظف آخر</ButtonLink>}</div>
    </Panel>
  </PageFrame>;
}

function cairoToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><Panel ><h1>ملف الموظف غير متاح</h1>
    <p className="intro">قد يكون الملف غير موجود، أو ليس لديك صلاحية عرضه في هذه الشركة.</p>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink>
  </Panel></PageFrame>;
}
