import styles from './profile-summary.module.css';
import { Avatar, Badge, Button, ButtonLink, Disclosure, Field, Input, Message, Panel, RecordCard, Select } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';

import { EmployeeProfileTabs, type ProfileArea } from './EmployeeProfileTabs';
import { activityKinds, activityLabels, EmployeeActivity, readActivity, type ActivityResult } from './EmployeeActivity';
import { readAccountsPage } from '../../leave/balances/rules';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser, readWorkspaceRpc } from '@/lib/workspace-access';
import { safeReturn } from '@/lib/return-to';
import { profileBackLink, profileReturnUrl, workPolicyCatalogUrl } from '@/lib/profile-return';
import { ProfileReturnField } from '@/components/profile-return-field';
import { PEOPLE_ROLE_BUNDLES } from '../../users/bundles';
import { EmployeeSelfServices, type SelfServiceAccess } from './EmployeeSelfServices';
import { EmployeeReadiness } from './EmployeeReadiness';
import { PayrollInclusion } from './PayrollInclusion';
import { payrollInclusion } from './payroll-inclusion-rules';
import { EmployeePayrollSetup } from './EmployeePayrollSetup';
import { EmployeeAdjustments } from './EmployeeAdjustments';
import { WorkAssignmentPanel, type AssignmentHistory, type TransferOptions } from './WorkAssignmentPanel';
import { CompensationPanel, type CompensationHistory, type CompensationOptions } from './CompensationPanel';
import { EmploymentLifecyclePanel, type EmploymentHistory, type RehireOptions } from './EmploymentLifecyclePanel';
import { EmployeeUserLinkPanel, type AccountProvision, type LinkSnapshot, type Options as EmployeeUserLinkOptions } from './EmployeeUserLinkPanel';
import { assignAttendancePolicyOverrideAction, assignWorkPolicyAction, cancelAttendancePolicyOverrideAction } from '../work-policy-actions';

export const dynamic = 'force-dynamic';
type Employment = { id: string; employer_id: string; employer: string; start_date: string; end_date: string | null; status: string };
type Assignment = { id: string; site: string; department: string | null; job: string | null; manager: string | null; valid_from: string };
type Employee = { id: string; code: string; name: string; status: string; employment: Employment | null; assignment: Assignment | null };

export default async function EmployeePage({ params, searchParams }: {
  params: Promise<{ tenantId: string; employeeId: string }>;
  searchParams: Promise<{ state?: string; assignment?: string; compensation?: string; employment?: string; userLink?: string; linkQuery?: string; linkPage?: string; account?: string; policy?: string; policyOverride?: string; tab?: string; return?: string; selfService?: string; activityAfter?:string; payrollPeriod?:string; payrollBefore?:string; payrollSaved?:string; adjustmentPeriod?:string; adjustmentBefore?:string; adjustmentAfter?:string; adjustmentFocus?:string; adjustmentResult?:string }>;
}) {
  const { tenantId, employeeId } = await params;
  const query = await searchParams;
  const returnTo = safeReturn(tenantId, query.return);
  const backLink = profileBackLink(tenantId, returnTo);
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(profileReturnUrl(tenantId, employeeId, `/tenant/${tenantId}/people/${employeeId}`, returnTo))}`);
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
  const [historyResult, optionsResult, compensationHistoryResult, compensationOptionsResult, employmentHistoryResult, rehireOptionsResult, linkSnapshotResult, linkOptionsResult, membershipSnapshotResult, workPolicyResult, inclusionResult] = await Promise.all([
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
    readWorkspaceRpc(supabase, 'tenant_membership_snapshot', tenantId, 'p_tenant_id'),
    employmentId ? supabase.rpc('people_work_policy_panel', { p_tenant_id: tenantId, p_employment_id: employmentId }) : Promise.resolve({ data: null, error: null }),
    employmentId ? supabase.rpc('people_payroll_inclusion', { p_tenant_id: tenantId, p_employment_id: employmentId }) : Promise.resolve({ data: null, error: null }),
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
  const canManageMembers = membershipSnapshot?.can_manage_members === true;
  let selfService: SelfServiceAccess = { state: membershipSnapshotResult.error || !membershipSnapshot || canManageMembers ? 'unknown' : 'other-role', keys: [] };
  const [memberAccess, channelAccess, leaveAccess, payrollAccess] = await Promise.all([
    canManageMembers && linkSnapshot?.linked && linkSnapshot.identity_visible && linkSnapshot.email
      ? supabase.rpc('tenant_member_access_page', { p_tenant_id: tenantId, p_view: 'members', p_page: 1, p_query: linkSnapshot.email.slice(0, 120) }) : Promise.resolve({ data: null, error: null }),
    readWorkspaceRpc(supabase, 'attendance_channel_access', tenantId, 'p_tenant'),
    readWorkspaceRpc(supabase, 'leave_access_snapshot', tenantId, 'p_tenant'),
    readWorkspaceRpc(supabase, 'payroll_run_access', tenantId, 'p_tenant'),
  ]);
  if (canManageMembers && !linkSnapshotResult.error && linkSnapshot?.linked === false) selfService = { state: 'unlinked', keys: [] };
  else if (canManageMembers && !memberAccess.error && Array.isArray(memberAccess.data?.rows)) {
    const member = memberAccess.data.rows.find((row: { user_id: string }) => row.user_id === linkSnapshot?.user_id);
    if (member && Array.isArray(member.roles)) selfService = { state: member.access_state === 'active' ? 'ready' : 'inactive', userId: member.user_id, email: member.email,
      keys: PEOPLE_ROLE_BUNDLES.filter(bundle => member.roles.some((role: { role_key: string }) => role.role_key === bundle.key)).map(bundle => bundle.key) };
  }
  const channelReady = !channelAccess.error && channelAccess.data?.can_view === true
    ? await supabase.rpc('people_employee_channel_readiness', { p_tenant: tenantId, p_employee: employeeId }) : { data: null, error: null };
  const correctionAccess=await supabase.rpc('payroll_correction_access',{p_tenant:tenantId});
  const financeAccess=await supabase.rpc('payroll_input_access',{p_tenant:tenantId});
  const canViewAdjustments=!financeAccess.error && ['employee_finance.view','employee_finance.manage','employee_finance.approve'].some(key=>financeAccess.data?.[key]===true);
  const hasPayrollSetupAccess = !payrollAccess.error && payrollAccess.data?.can_prepare === true;
  const payrollSaveConfirmed = hasPayrollSetupAccess && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(query.payrollSaved ?? '')
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(query.payrollPeriod ?? '');
  const validAfter = typeof query.activityAfter === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(query.activityAfter) ? query.activityAfter : undefined;
  const activityResponses = await Promise.all(activityKinds.map(kind => kind === 'payroll' && query.tab !== 'payroll' ? Promise.resolve(null) : supabase.rpc('people_employee_activity', {
    p_tenant: tenantId, p_employee: employeeId, p_kind: kind, p_after: query.tab === kind ? validAfter ?? null : null, p_limit: 20,
  })));
  const activities = Object.fromEntries(activityKinds.map((kind,index) => {
    const response = activityResponses[index];
    return [kind, { page: !response || response.error ? null : readActivity(response.data, employeeId, kind), forbidden: response?.error?.code === '42501' }];
  })) as Record<typeof activityKinds[number], ActivityResult>;
  const balanceResponse = !leaveAccess.error && leaveAccess.data?.can_view === true && employee.employment?.employer_id
    ? await supabase.rpc('leave_balance_accounts', { p_tenant: tenantId, p_employee: employeeId, p_employer: employee.employment.employer_id, p_limit: 50 }) : null;
  const employeeBalances = balanceResponse && !balanceResponse.error ? readAccountsPage(balanceResponse.data) : null;
  const requestedTab = ['overview', 'work', 'account', 'employment', ...activityKinds, ...(canViewAdjustments ? ['adjustments'] : []), ...(canViewCompensation || canManageCompensation || hasPayrollSetupAccess ? ['compensation'] : [])].includes(query.tab ?? '') ? query.tab as ProfileArea : null;
  const initialTab: ProfileArea = requestedTab ?? (query.userLink || query.account || query.selfService || query.linkQuery !== undefined || query.linkPage !== undefined
    ? 'account' : query.employment ? 'employment'
      : query.compensation && (canViewCompensation || canManageCompensation) ? 'compensation'
        : query.assignment || query.policy || query.policyOverride ? 'work' : 'overview');
  const lifecycleFollowup = ['ended', 'rehired'].includes(query.employment ?? '');
  const employerQuery: Record<string, string> = employee.employment?.employer_id ? { employer: employee.employment.employer_id } : {};
  const inclusion = inclusionResult.error ? null : payrollInclusion(inclusionResult.data);
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
    <EmployeeReadiness tenantId={tenantId} employeeId={employeeId} employerId={employee.employment?.employer_id ?? null} returnTo={returnTo} facts={{
      work: { active: employee.status === 'active' && employee.employment?.status === 'active', hasAssignment: Boolean(employee.assignment), canManage: canManageWorkContext },
      compensation: { canView: canViewCompensation, current: compensationHistoryError ? null : compensationHistory?.items.some(item => item.status === 'current') ?? false },
      policy: { current: workPolicyPanel ? workPolicyPanel.history.some(item => Boolean(item.policy_id) && item.valid_from <= today && (!item.valid_until || item.valid_until > today)) : null,
        canAssign: workPolicyPanel?.can_assign === true, hasOptions: Boolean(workPolicyPanel?.options.length), canManageCatalog: workPolicyPanel?.can_manage_catalog === true, forbidden: workPolicyResult.error?.code === '42501' },
      account: { linked: linkSnapshotResult.error || !linkSnapshot ? null : linkSnapshot.linked, canManage: access.can_manage === true, provisionState: accountProvision?.state },
      selfService,
      channel: channelAccess.error || typeof channelAccess.data?.can_view !== 'boolean' ? channelAccess.error?.code === '42501' ? { canView: false, canManage: false } : null
        : { canView: channelAccess.data?.can_view === true, canManage: channelAccess.data?.can_manage === true, state: channelReady.error ? undefined : channelReady.data?.state, captureEnabled: channelReady.data?.capture_enabled },
      canReviewBalances: leaveAccess.error?.code === '42501' ? false : leaveAccess.error || typeof leaveAccess.data?.can_view !== 'boolean' ? null : leaveAccess.data.can_view,
      canPreparePayroll: payrollAccess.error?.code === '42501' ? false : payrollAccess.error || typeof payrollAccess.data?.can_prepare !== 'boolean' ? null : payrollAccess.data.can_prepare,
    }} />

  </>;
  const work = <>
    <WorkAssignmentPanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId} returnTo={returnTo}
      employmentStartDate={employee.employment?.start_date ?? null}
      employmentActive={employee.employment?.status === 'active'}
      history={assignmentHistory} historyError={historyError} options={transferOptions} optionsError={optionsError}
      canManage={canManageWorkContext} initialDate={today} />
    {workPolicyPanel && <Panel  aria-labelledby="work-policy-heading">
      <h2 id="work-policy-heading">نظام الدوام</h2>
      <p className="record-meta">الدوام الحالي: {workPolicyPanel.history.find(item => item.valid_from <= today && (!item.valid_until || item.valid_until > today))?.name ?? 'لم يُحدد بعد'}</p>
      <Disclosure summary="سجل أنظمة الدوام">{workPolicyPanel.history.length ? <ol className="assignment-history-list">{workPolicyPanel.history.map((row) => <RecordCard className="assignment-history-item" key={row.assignment_id}>
        <strong>{row.name ?? 'دون سياسة دوام محددة'}</strong>
        {row.name && <Disclosure summary="تفاصيل القالب"><p>الرمز: <bdi>{row.code}</bdi> · الإصدار {row.version}</p></Disclosure>}
        <p>من <bdi>{row.valid_from}</bdi>{row.valid_until ? ` إلى ما قبل ${row.valid_until}` : ' · مستمر'}</p>
      </RecordCard>)}</ol> : <Message tone="neutral">لم يُسجل نظام دوام بعد.</Message>}</Disclosure>
      {workPolicyPanel.can_assign && employmentId && employee.employment?.status === 'active' && !workPolicyPanel.options.length && <Message tone="info">لا توجد أنظمة دوام للاختيار. {workPolicyPanel.can_manage_catalog ? 'أضف نظامًا من «إعداد أنظمة الدوام» أدناه.' : 'اطلب من مسؤول الشركة إعداد نظام الدوام.'}</Message>}
      {workPolicyPanel.can_assign && workPolicyPanel.options.length > 0 && employmentId && employee.employment?.status === 'active' && <OfflineForm action={assignWorkPolicyAction} className="work-policy-assignment-form">
        <ProfileReturnField value={returnTo} />
        <input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="employeeId" value={employee.id}/><input type="hidden" name="employmentId" value={employmentId}/>
        <div className="work-policy-assignment-field"><Field id="work-policy-id" label="نظام الدوام" required><Select id="work-policy-id" name="policyId" required defaultValue=""><option value="" disabled>اختر الدوام</option>{workPolicyPanel.options.map((item)=><option key={item.id} value={item.id}>{policyChoiceLabel(item, workPolicyPanel.options)}</option>)}</Select></Field></div>
        <Disclosure summary="تفاصيل أنظمة الدوام المتاحة"><ul>{workPolicyPanel.options.map(item => <li key={item.id}>{item.name} — <bdi>{item.code}</bdi> · الإصدار {item.version}</li>)}</ul></Disclosure>
        <div className="work-policy-assignment-field"><Field id="work-policy-date" label="يبدأ من يوم" required><Input id="work-policy-date" type="date" name="effectiveDate" min={today} defaultValue={today} required/></Field></div>
        <Disclosure summary="كيف يُحفظ تغيير الدوام؟"><p>يبدأ العمل بالنظام من اليوم الذي تختاره. تبقى مواعيد الدوام السابقة محفوظة، ولا تتغير سجلات الحضور التي بدأت بالفعل.</p></Disclosure>
        {query.policy === 'payroll-correction' && <Message tone="bad"  role="alert">يمس هذا التغيير تاريخ راتب مقفل. لم تتغير البيانات؛ راجع مسؤول تصحيح الرواتب لإعداد مقترح التصحيح بتاريخ سريان محدد للفترة نفسها.</Message>}
        {query.policy === 'failed' && <Message tone="bad" role="alert">تعذر تغيير الدوام. راجع التاريخ وأي تغيير عمل مقرر بالفعل.</Message>}
        {query.policy === 'pending' && <Message tone="bad"  role="alert">يوجد تغيير عمل مقرر؛ عالجه أولًا قبل جدولة سياسة أخرى.</Message>}
        {query.policy === 'materialized' && <Message tone="bad"  role="alert">بدأ تسجيل حضور لهذا اليوم وفق سياسة الدوام الحالية؛ اختر تاريخ سريان لاحقًا لم يُفتح للحضور.</Message>}
        <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ نظام الدوام" pendingLabel="جارٍ حفظ الدوام…" disabled={!workPolicyPanel.options.length} /></div>
      </OfflineForm>}
      {workPolicyPanel.can_manage_catalog && <ButtonLink variant="ghost" href={workPolicyCatalogUrl(tenantId, employeeId, returnTo)}>إعداد أنظمة الدوام</ButtonLink>}
      <Disclosure summary="تغيير الدوام لفترة محددة" open={Boolean(query.policyOverride)}>
      <p className="record-meta">اختر مواعيد مختلفة لفترة مؤقتة، ثم يعود الموظف إلى دوامه المعتاد. الأيام التي بدأ تسجيل حضورها لا تتغير.</p>
      {workPolicyPanel.overrides.length ? <ol className="assignment-history-list">{workPolicyPanel.overrides.map((override) => <RecordCard className="assignment-history-item" key={override.id}>
        <strong>{override.name}</strong><Disclosure summary="تفاصيل القالب"><p>الرمز: <bdi>{override.code}</bdi> · الإصدار {override.version}</p></Disclosure>
        <p>من <bdi>{override.valid_from}</bdi> إلى <bdi>{override.valid_through}</bdi>{override.cancelled_at ? ' · ملغى' : ''}</p>
        <p>{override.reason}</p>
        {override.can_cancel && workPolicyPanel.can_manage_catalog && <OfflineForm action={cancelAttendancePolicyOverrideAction} className="work-policy-assignment-form">
          <ProfileReturnField value={returnTo} />
          <input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="employeeId" value={employee.id}/><input type="hidden" name="overrideId" value={override.id}/>
          <div className="work-policy-assignment-field"><Field id={`override-cancel-reason-${override.id}`} label={<>سبب الإلغاء</>} required help="اكتب سببًا مختصرًا وواضحًا يساعد على مراجعة الإجراء لاحقًا."><Input id={`override-cancel-reason-${override.id}`} name="cancelReason" minLength={3} maxLength={500} required placeholder="مثال: تحديث البيانات بعد مراجعتها"/></Field></div>
          <div className="workspace-form-actions"><OfflineSubmitButton className="secondary-button" label="إلغاء التغيير المقرر" pendingLabel="جارٍ الإلغاء…" /></div>
        </OfflineForm>}
      </RecordCard>)}</ol> : <Message tone="neutral" >لا توجد تغييرات دوام لفترات محددة.</Message>}
      {workPolicyPanel.can_manage_catalog && workPolicyPanel.options.length > 0 && employmentId && employee.employment?.status === 'active' && <OfflineForm action={assignAttendancePolicyOverrideAction} className="work-policy-assignment-form">
        <ProfileReturnField value={returnTo} />
        <input type="hidden" name="tenantId" value={tenantId}/><input type="hidden" name="employeeId" value={employee.id}/><input type="hidden" name="employmentId" value={employmentId}/>
        <div className="work-policy-assignment-field"><Field id="policy-override-id" label="الدوام المؤقت" required><Select id="policy-override-id" name="policyId" required defaultValue=""><option value="" disabled>اختر الدوام</option>{workPolicyPanel.options.map((item)=><option key={item.id} value={item.id}>{policyChoiceLabel(item, workPolicyPanel.options)}</option>)}</Select></Field></div>
        <div className="work-policy-assignment-field"><Field id="policy-override-from" label={<>من تاريخ</>} required><Input id="policy-override-from" type="date" name="validFrom" min={policyOverrideMinDate} defaultValue={policyOverrideMinDate} required/></Field></div>
        <div className="work-policy-assignment-field"><Field id="policy-override-through" label={<>إلى تاريخ</>} required><Input id="policy-override-through" type="date" name="validThrough" min={policyOverrideMinDate} defaultValue={policyOverrideMinDate} required/></Field></div>
        <div className="work-policy-assignment-field"><Field id="policy-override-reason" label={<>سبب التغيير</>} required help="اكتب سببًا مختصرًا وواضحًا يساعد على مراجعة الإجراء لاحقًا."><Input id="policy-override-reason" name="reason" minLength={3} maxLength={500} required placeholder="مثال: تحديث البيانات بعد مراجعتها"/></Field></div>
        {query.policyOverride === 'invalid' && <Message tone="bad"  role="alert">راجع القالب والتاريخين، واجعل الفترة 90 يومًا أو أقل، واكتب سببًا واضحًا.</Message>}
        {query.policyOverride === 'overlap' && <Message tone="bad"  role="alert">تتداخل الفترة مع تغيير دوام محفوظ. اختر فترة أخرى.</Message>}
        {query.policyOverride === 'materialized' && <Message tone="bad"  role="alert">بدأ فتح الحضور لأحد أيام الفترة؛ لم يُغيّر أي سجل. اختر تواريخ لم تُفتح بعد.</Message>}
        {query.policyOverride === 'historical' && <Message tone="bad"  role="alert">لا يمكن إضافة تغيير يبدأ بتاريخ سابق. اختر اليوم أو تاريخًا لاحقًا.</Message>}
        {(query.policyOverride === 'failed' || query.policyOverride === 'forbidden' || query.policyOverride === 'cancel-failed') && <Message tone="bad"  role="alert">تعذر حفظ التغيير. تحقق من صلاحيتك وحالة العمل والقالب، ثم حدّث الصفحة.</Message>}
        <div className="workspace-form-actions"><OfflineSubmitButton label="حفظ تغيير الدوام للفترة" pendingLabel="جارٍ حفظ التغيير…" disabled={!workPolicyPanel.options.length} /></div>
      </OfflineForm>}
      </Disclosure>
    </Panel>}
  </>;
  const compensation = <>
    {payrollSaveConfirmed && <Message tone="ok" role="status">تم حفظ بيانات الضريبة والتأمينات للموظف. راجع القيم المحفوظة أدناه، ثم افتح المسير لحساب الرواتب.</Message>}
    {employmentId && (inclusion ? <PayrollInclusion key={employmentId} tenant={tenantId} employment={employmentId} employee={employeeId} employer={employee.employment?.employer_id ?? ''} active={employee.employment?.status === 'active'} snapshot={inclusion}/> : <Message tone="info">تعذر التحقق من إضافة الموظف إلى مسيرات الرواتب. أعد تحميل الملف للتحقق.</Message>)}
    {(canViewCompensation || canManageCompensation) && <CompensationPanel tenantId={tenantId} employeeId={employee.id} returnTo={returnTo}
      employmentId={employmentId} canView={canViewCompensation} canManage={canManageCompensation}
      history={compensationHistory} historyError={compensationHistoryError}
      options={compensationOptions} optionsError={compensationOptionsError} today={today} />}
    {employee.employment && <EmployeePayrollSetup tenantId={tenantId} employeeId={employeeId} employmentId={employee.employment.id} employerId={employee.employment.employer_id} employeeCode={employee.code} employmentStart={employee.employment.start_date} employmentEnd={employee.employment.end_date} periodId={query.payrollPeriod} before={query.payrollBefore} returnTo={returnTo} canPrepare={payrollAccess.error ? payrollAccess.error.code === '42501' ? false : null : payrollAccess.data?.can_prepare === true}/>}
  </>;
  const employment = <>
    <EmploymentLifecyclePanel tenantId={tenantId} employeeId={employee.id} employmentId={employmentId} returnTo={returnTo}
      employmentStatus={employee.employment?.status ?? null} workforceStatus={employee.status}
      employmentStartDate={employee.employment?.start_date ?? null}
      previousEndDate={employee.employment?.end_date ?? null} canManage={canManageLifecycle} today={today}
      history={employmentHistory} historyError={employmentHistoryError}
      rehireOptions={rehireOptions} optionsError={rehireOptionsError} />
  </>;
  const account = <>
    <EmployeeUserLinkPanel tenantId={tenantId} employeeId={employee.id} canManage={access.can_manage === true} returnTo={returnTo}
      canInvite={membershipSnapshot?.can_manage_members === true}
      canProvisionAccount={canProvisionEmployeeAccount}
      accountProvision={accountProvision} accountProvisionError={Boolean(canProvisionEmployeeAccount && (accountProvisionResult.error || !accountProvision))}
      requestKey={crypto.randomUUID()} accountState={query.account}
      snapshot={linkSnapshot} snapshotError={Boolean(linkSnapshotResult.error || !linkSnapshot)}
      options={linkOptions} optionsError={Boolean(access.can_manage === true && (linkOptionsResult.error || !linkOptions))}
      query={linkQuery} page={linkPage} state={query.userLink} />
    <EmployeeSelfServices tenantId={tenantId} employeeId={employeeId} access={selfService} result={query.selfService} returnTo={returnTo} />
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
    {query.policy === 'template-saved' && <FeedbackToast key="policy-template-saved" message="تم حفظ قالب الدوام. اختره وحدد تاريخ سريانه لتعيينه للموظف."/>}
    {query.policy === 'invalid' && <FeedbackToast key="policy-invalid" message="تحقق من بيانات سياسة الدوام."/>}
    {query.policyOverride === 'assigned' && <FeedbackToast key="policy-override-assigned" message="تم حفظ سياسة الدوام للفترة المحددة."/>}
    {query.policyOverride === 'cancelled' && <FeedbackToast key="policy-override-cancelled" message="تم إلغاء التغيير المقرر للدوام."/>}
    <ButtonLink className={styles.profileReturn} variant="ghost" href={backLink.href}>{backLink.label}</ButtonLink>
    <header className="workspace-page-heading"><div className="employee-profile-identity"><Avatar name={employee.name} size={64} status={employee.status === 'active' ? 'ok' : 'neutral'} /><div><p className="eyebrow">ملف الموظف</p><h1>{employee.name}</h1>
      <p>رمز الموظف: <bdi>{employee.code}</bdi></p></div></div>
      <Badge className={`entity-status ${employee.status === 'active' ? 'is-active' : 'is-inactive'}`}>
        {employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'سيبدأ قريبًا' : employee.status === 'ended' ? 'انتهت خدمته' : 'غير نشط'}</Badge>
    </header>
    <EmployeeProfileTabs key={initialTab} initialTab={initialTab} baseHref={profileReturnUrl(tenantId, employeeId, `/tenant/${tenantId}/people/${employeeId}`, returnTo)} areas={[
      { value: 'overview', label: 'ملخص الموظف', content: overview },
      { value: 'work', label: 'العمل والدوام', content: work },
      ...(canViewCompensation || canManageCompensation || hasPayrollSetupAccess
        ? [{ value: 'compensation' as const, label: 'الراتب', content: compensation }] : []),
      ...(canViewAdjustments ? [{ value: 'adjustments' as const, label: 'المكافآت والجزاءات',
        ...(query.tab !== 'adjustments' ? {href:profileReturnUrl(tenantId,employeeId,`/tenant/${tenantId}/people/${employeeId}?tab=adjustments`,returnTo)} : {}),
        content: query.tab === 'adjustments' ? <EmployeeAdjustments tenant={tenantId} employee={employeeId} period={query.adjustmentPeriod} before={query.adjustmentBefore} after={query.adjustmentAfter} focus={query.adjustmentFocus} feedback={query.adjustmentResult} returnTo={returnTo}/> : <Panel><ButtonLink href={profileReturnUrl(tenantId,employeeId,`/tenant/${tenantId}/people/${employeeId}?tab=adjustments`,returnTo)}>فتح المكافآت والجزاءات</ButtonLink></Panel>
      }] : []),
      ...activityKinds.map(kind => ({ value: kind, label: activityLabels[kind], ...(kind === 'payroll' && query.tab !== 'payroll' ? { href: profileReturnUrl(tenantId, employeeId, `/tenant/${tenantId}/people/${employeeId}?tab=payroll`, returnTo) } : {}), content: <>
        {query.tab === kind && query.activityAfter && !validAfter && <Message tone="info">تعذر متابعة الصفحة المطلوبة. نعرض أحدث السجلات.</Message>}
        {kind === 'leave' && leaveAccess.data?.can_manage === true && leaveAccess.data?.new_work_enabled === true && employee.employment?.status === 'active' && <Disclosure summary="تسجيل إجازة لهذا الموظف">
          <form method="get" action={`/tenant/${tenantId}/leave/new`} className="auth-form compact-form">
            <input type="hidden" name="employee" value={employeeId}/><input type="hidden" name="employment" value={employee.employment.id}/><input type="hidden" name="q" value={employee.code}/>
            <input type="hidden" name="return" value={`/tenant/${tenantId}/people/${employeeId}?tab=leave`}/>
            <Field id="employee-leave-start" label="من يوم" required><Input id="employee-leave-start" type="date" name="start" required/></Field>
            <Field id="employee-leave-end" label="إلى يوم" required><Input id="employee-leave-end" type="date" name="end" required/></Field>
            <Button type="submit">اختيار نوع الإجازة</Button>
          </form>
        </Disclosure>}
        {kind === 'payroll' && query.tab !== 'payroll' ? <Panel><h2>رواتب الموظف</h2><p className="record-meta">افتح السجل لتحميل المسيرات المحفوظة لهذا الموظف.</p><a className="ui-button ui-button-solid ui-button-md" href={profileReturnUrl(tenantId, employeeId, `/tenant/${tenantId}/people/${employeeId}?tab=payroll`, returnTo)}>تحميل رواتب الموظف</a></Panel>
          : <EmployeeActivity tenantId={tenantId} employeeId={employeeId} kind={kind} result={activities[kind]} after={query.tab === kind ? validAfter : undefined} />}
        {kind === 'leave' && !leaveAccess.error && leaveAccess.data?.can_view === true && employee.employment?.employer_id && <Panel><h2>رصيد الإجازات</h2>
          {employeeBalances ? employeeBalances.items.length ? <dl className="snapshot-grid">{employeeBalances.items.map(item => <div key={item.accountId}><dt>{item.typeName} · {item.periodLabel}</dt><dd>{item.balanceDays} يوم</dd></div>)}</dl> : <p>لم يُسجل رصيد إجازات لهذا الموظف بعد.</p> : <Message tone="info">تعذر تحميل الأرصدة. افتح صفحة الأرصدة لإعادة المحاولة.</Message>}
          <ButtonLink variant="ghost" href={`/tenant/${tenantId}/leave/balances?${new URLSearchParams({ employee: employeeId, employer: employee.employment.employer_id })}`}>{employeeBalances?.hasMore ? 'عرض باقي الأرصدة وتعديلها' : 'عرض الأرصدة وحركاتها'}</ButtonLink>
        </Panel>}
      </> })),
      { value: 'account', label: 'الحساب والدخول', content: account },
      { value: 'employment', label: 'سجل العمل', content: employment },
    ]} />
    <Disclosure summary="إجراءات إضافية" open={lifecycleFollowup}>
      {lifecycleFollowup && <section aria-label="متابعة التسوية"><p>راجع آثار علاقة العمل في المساحات المصرّح لك بها؛ لا يُنفّذ هذا التنبيه أي تسوية تلقائية.</p><div className="workspace-form-actions">
        {!payrollAccess.error && payrollAccess.data?.can_view === true && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/payroll?${new URLSearchParams(employerQuery)}`}>راجع الرواتب</ButtonLink>}
        {!leaveAccess.error && leaveAccess.data?.can_view === true && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/leave/balances?${new URLSearchParams({ ...employerQuery, employee: employeeId })}`}>راجع أرصدة الإجازات</ButtonLink>}
        {!activities.advances.forbidden && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/people/${employeeId}?tab=advances`}>راجع سلف الموظف</ButtonLink>}
      </div></section>}
      {correctionAccess.data?.can_correct&&<ButtonLink variant="ghost" href={`/tenant/${tenantId}/payroll/corrections?${new URLSearchParams({person:employee.id})}`}>تصحيح بيانات مسير محفوظ</ButtonLink>}
      <div className="workspace-form-actions">{backLink.fromTask && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/people`}>عرض جميع الموظفين</ButtonLink>}
        {access.can_manage === true && access.can_manage_employment === true && access.can_manage_compensation === true &&
          <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/new`}>إضافة موظف آخر</ButtonLink>}</div>
    </Disclosure>
  </PageFrame>;
}

function policyChoiceLabel(item: { id: string; name: string; code: string; version: number }, options: { id: string; name: string }[]) {
  return options.some(other => other.id !== item.id && other.name === item.name) ? `${item.name} (${item.code}، إصدار ${item.version})` : item.name;
}
function cairoToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><Panel ><h1>ملف الموظف غير متاح</h1>
    <p className="intro">قد يكون الملف غير موجود، أو ليس لديك صلاحية عرضه في هذه الشركة.</p>
    <ButtonLink variant="ghost" href={`/tenant/${tenantId}`}>العودة إلى اليوم</ButtonLink>
  </Panel></PageFrame>;
}
