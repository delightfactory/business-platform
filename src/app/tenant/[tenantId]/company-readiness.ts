import { readWorkspaceRpc, type getWorkspaceClient } from '@/lib/workspace-access';
import type { ReadinessItem } from '@/components/patterns/readiness-list/ReadinessList';
import type { TodayModel } from './today';
import { isObject, isUuid, nextLeaveSetup, readAccess, readConfiguration } from './leave/settings/rules';

type Client = NonNullable<Awaited<ReturnType<typeof getWorkspaceClient>>>;
type Result = { data: unknown; error: { code?: string } | null };
const record = (value: unknown) => isObject(value) ? value : null;

// Called only after the parent has authenticated and read tenant_admin_snapshot.
// These are setup facts, not employee counts or financial/capture qualification.
export async function readCompanyReadiness(client: Client, tenantId: string, email: string, snapshot: Record<string, unknown>, today: TodayModel): Promise<ReadinessItem[]> {
  const base = `/tenant/${tenantId}`;
  const reads = await Promise.allSettled([
    readWorkspaceRpc(client, 'people_access_snapshot', tenantId, 'p_tenant_id'),
    readWorkspaceRpc(client, 'leave_access_snapshot', tenantId, 'p_tenant'),
    readWorkspaceRpc(client, 'attendance_channel_access', tenantId, 'p_tenant'),
    readWorkspaceRpc(client, 'tenant_entities_sites_snapshot', tenantId, 'p_tenant_id'),
    readWorkspaceRpc(client, 'payroll_access_snapshot', tenantId, 'p_tenant'),
  ]);
  const results: Result[] = reads.map(result => result.status === 'fulfilled' ? result.value : { data: null, error: { code: 'unavailable' } });
  const [peopleResult, leaveResult, channelResult, entitiesResult, payrollResult] = results;
  const people = !peopleResult.error ? record(peopleResult.data) : null;
  const channel = !channelResult.error ? record(channelResult.data) : null;
  const leave = !leaveResult.error ? readAccess(leaveResult.data) : null;
  const payroll = !payrollResult.error ? record(payrollResult.data) : null;
  const entities = !entitiesResult.error ? record(entitiesResult.data)?.entities : null;
  const active = Array.isArray(entities) ? entities.filter(item => isObject(item) && item.is_active === true && isUuid(item.id)) : [];
  const employer = active.length === 1 ? active[0] : null;
  const hasWork = today.work.length > 0 || today.followUp.length > 0;
  const basics = record(snapshot.default_legal_entity) && record(snapshot.default_site);
  const steps: ReadinessItem[] = [
    { title: 'صلاحيات عملك', state: hasWork ? 'done' : today.unavailable.length ? 'unknown' : 'todo', detail: hasWork ? 'تظهر لك مهام العمل المتاحة لحسابك.' : today.unavailable.length ? 'تعذر التحقق من بعض صلاحيات العمل. أعد تحميل الصفحة قبل تغييرها.' : 'دور مسؤول الشركة لا يضيف كل صلاحيات العمل تلقائيًا. اختر ما تحتاجه لمهامك.', action: { href: `${base}/users?q=${encodeURIComponent(email)}`, label: 'راجع صلاحيات عملك' } },
    { title: 'الجهة والفرع الأساسيان', state: basics ? 'done' : 'todo', detail: basics ? 'الجهة والفرع الأساسيان مسجلان. إعداد موقع تسجيل الحضور خطوة مستقلة.' : 'حدد جهة وفرعًا أساسيين للعمل.', action: { href: `${base}/entities-sites`, label: 'الجهات والفروع' } },
  ];

  let leaveStep: ReadinessItem = { title: 'الإجازات', state: 'other-role', detail: 'راجع مسؤول الإجازات لتجهيز التقويم وسنة الرصيد والأنواع.', owner: 'مسؤول الإجازات' };
  if (leaveResult.error && leaveResult.error.code !== '42501') leaveStep = { title: 'الإجازات', state: 'unknown', detail: 'تعذر التحقق من صلاحيات الإجازات الآن.', action: { href: base, label: 'إعادة المحاولة' } };
  else if (leave?.canView) {
    leaveStep = { title: 'الإجازات', state: leave.canManage ? 'todo' : 'other-role', detail: 'اختر الجهة لمراجعة خطوات إعداد إجازاتها.', owner: leave.canManage ? undefined : 'مسؤول الإجازات', action: { href: `${base}/leave/settings`, label: 'راجع إعداد الإجازات' } };
    if (employer && isUuid(employer.id)) {
      let response: Result;
      try { response = await client.rpc('leave_configuration_snapshot', { p_tenant: tenantId, p_employer: employer.id }); }
      catch { response = { data: null, error: { code: 'unavailable' } }; }
      const configuration = !response.error ? readConfiguration(response.data) : null;
      if (!configuration) leaveStep = { title: 'الإجازات', state: 'unknown', detail: 'تعذر التحقق من إعدادات الجهة. افتح إعداداتها لإعادة المحاولة.', action: { href: `${base}/leave/settings/${employer.id}`, label: 'راجع إعداد الجهة' } };
      else {
        const next = nextLeaveSetup(configuration), canEdit = leave.canManage && leave.newWorkEnabled;
        leaveStep = { title: 'الإجازات', state: !next ? 'done' : canEdit ? 'todo' : 'other-role', detail: next ? next.detail : 'التقويم وسنة الرصيد وأنواع الإجازات محفوظة؛ راجع تطبيقها وأرصدة الموظفين في الإجازات.',
          owner: next && !canEdit ? leave.newWorkEnabled ? 'مسؤول الإجازات' : 'مسؤول الشركة لإتاحة الخدمة' : undefined,
          action: { href: `${base}/leave/settings/${employer.id}${next && canEdit ? `/${next.path}` : ''}`, label: next && canEdit ? next.label : 'راجع إعداد الجهة' } };
      }
    }
  }
  steps.push(leaveStep);

  const calendar = today.payrollSetup;
  if (calendar) steps.push({ title: 'الرواتب', state: calendar.configured ? 'done' : calendar.canManage && calendar.enabled ? 'todo' : 'other-role', detail: calendar.configured ? 'دورة رواتب الجهة محفوظة. جاهزية الحساب والاعتماد تُراجع داخل الرواتب.' : 'جهّز دورة الرواتب قبل إنشاء فتراتها.', owner: !calendar.configured && !calendar.canManage ? 'مدير دورة الرواتب' : !calendar.enabled ? 'مسؤول الشركة لإتاحة الخدمة' : undefined, action: { href: `${base}/payroll/setup?employer=${calendar.employerId}`, label: calendar.canManage ? 'إعداد رواتب الجهة' : 'راجع دورة الرواتب' } });
  else if (payroll?.can_view === true || payroll?.can_manage === true) steps.push({ title: 'الرواتب', state: 'unknown', detail: 'اختر جهة العمل لمراجعة حالة إعداد دورتها وفتراتها.', action: { href: `${base}/payroll/setup`, label: 'راجع جهات الرواتب' } });
  else steps.push({ title: 'الرواتب', state: payrollResult.error?.code === '42501' ? 'other-role' : 'unknown', detail: 'اطلب من مدير دورة الرواتب مراجعة إعداد الجهات والفترات.', owner: 'مدير دورة الرواتب' });

  if (steps.every(item => item.state === 'done')) return [];
  const peopleStep: ReadinessItem = people?.can_view === true
    ? { title: 'الموظفون', state: 'unknown', statusLabel: 'راجع الجاهزية', detail: 'راجع ملفات الموظفين وجاهزية كل موظف من الدليل.', action: { href: `${base}/people`, label: 'افتح الموظفين' } }
    : { title: 'الموظفون', state: peopleResult.error?.code === '42501' ? 'other-role' : 'unknown', detail: 'تحتاج مراجعة الملفات إلى صلاحية عرض الموظفين.', owner: 'الموارد البشرية' };
  const attendanceStep: ReadinessItem = channel?.can_view === true
    ? { title: 'وسائل الحضور', state: 'unknown', statusLabel: 'راجع الجاهزية', detail: 'راجع وسائل التسجيل ومواقع العمل؛ وجود فرع لا يثبت جاهزية تسجيل الحضور.', action: { href: `${base}/attendance/sources`, label: 'وسائل تسجيل الحضور' } }
    : { title: 'وسائل الحضور', state: channelResult.error?.code === '42501' ? 'other-role' : 'unknown', detail: 'راجع مسؤول الحضور لتهيئة وسائل التسجيل ومواقعه.', owner: 'مسؤول الحضور' };
  return [steps[0], steps[1], peopleStep, leaveStep, steps[3], attendanceStep];
}
