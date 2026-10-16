import { Button, ButtonLink, Field, Message, Panel, Select } from '@/components/ui';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { cairoToday, isCivilDate } from '@/lib/attendance-calendar';
import { EgyptForm, type EgyptContext } from '../../payroll/setup/employee/EgyptForm';

type Period = { id: string; starts_on: string; ends_on: string };
type Props = {
  tenantId: string; employeeId: string; employmentId: string; employerId: string;
  employeeCode: string; employmentStart: string; employmentEnd: string | null;
  canPrepare: boolean | null; periodId?: string; before?: string; returnTo?: string | null;
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function EmployeePayrollSetup(props: Props) {
  if (props.canPrepare !== true) return <Panel><h2>الضريبة والتأمينات</h2><Message tone="info">{props.canPrepare === false ? 'استكمال هذه البيانات يحتاج إلى صلاحية إعداد الرواتب. اطلبها من مدير الشركة عند الحاجة.' : 'تعذر التحقق من صلاحية إعداد الرواتب. أعد تحميل الملف للتحقق.'}</Message></Panel>;
  try { return await PayrollSetup(props); }
  catch { return <Panel><h2>الضريبة والتأمينات</h2><Message tone="warn">تعذر تحميل بيانات الرواتب. بقية ملف الموظف متاحة؛ أعد تحميل الملف للتحقق.</Message></Panel>; }
}

async function PayrollSetup({ tenantId, employeeId, employmentId, employerId, employeeCode, employmentStart, employmentEnd, periodId, before, returnTo }: Props) {
  const client = await getWorkspaceClient();
  if (!client) return <Panel><h2>الضريبة والتأمينات</h2><Message tone="warn">تعذر الاتصال. أعد تحميل الملف لاستكمال بيانات الرواتب.</Message></Panel>;
  const validBefore = isCivilDate(before) ? before : undefined;
  const [periodsResult, accessResult] = await Promise.all([
    client.rpc('payroll_input_periods', { p_tenant: tenantId, p_employer: employerId, p_before: validBefore ?? null }),
    client.rpc('payroll_input_access', { p_tenant: tenantId }),
  ]);
  if (periodsResult.error || accessResult.error || !Array.isArray(periodsResult.data) || !accessResult.data) return <Panel><h2>الضريبة والتأمينات</h2><Message tone="warn">تعذر تحميل فترات الرواتب أو صلاحية إعدادها. أعد المحاولة من ملف الموظف.</Message></Panel>;
  const access = accessResult.data as Record<string, boolean>;
  if (access['payroll.prepare'] !== true) return <Panel><h2>الضريبة والتأمينات</h2><Message tone="info">لا يملك حسابك حاليًا صلاحية إعداد رواتب الموظفين.</Message></Panel>;
  const periods: Period[] = periodsResult.data.filter((item: unknown): item is Period => Boolean(item && typeof item === 'object' && 'id' in item && typeof item.id === 'string' && uuid.test(item.id) && 'starts_on' in item && isCivilDate(item.starts_on) && 'ends_on' in item && isCivilDate(item.ends_on)));
  if (periods.length !== periodsResult.data.length) return <Panel><h2>الضريبة والتأمينات</h2><Message tone="warn">تعذر قراءة قائمة الفترات كاملة. أعد تحميل الملف قبل اختيار فترة.</Message></Panel>;
  const eligible = periods.filter(period => employmentStart <= period.ends_on && (!employmentEnd || employmentEnd >= period.starts_on));
  let taskPeriod: string | undefined;
  if (!periodId && returnTo) {
    const destination = new URL(returnTo, 'https://workspace.invalid');
    const value = destination.searchParams.get('period');
    if (destination.pathname === `/tenant/${tenantId}/payroll/runs` && destination.searchParams.get('employer') === employerId && uuid.test(value ?? '')) taskPeriod = value!;
  }
  const requestedPeriod = periodId || taskPeriod;
  const today = cairoToday();
  const current = eligible.filter(period => period.starts_on <= today && period.ends_on >= today);
  let selected = requestedPeriod ? eligible.find(period => period.id === requestedPeriod) : current.length === 1 ? current[0] : null;
  if (requestedPeriod && uuid.test(requestedPeriod) && !selected) {
    const exact = await client.rpc('payroll_input_workspace', { p_tenant: tenantId, p_employer: employerId, p_period: requestedPeriod, p_limit: 1 });
    const period = exact.error ? null : exact.data?.period;
    if (period?.id === requestedPeriod && isCivilDate(period.starts_on) && isCivilDate(period.ends_on) && employmentStart <= period.ends_on && (!employmentEnd || employmentEnd >= period.starts_on)) {
      selected = { id: requestedPeriod, starts_on: period.starts_on, ends_on: period.ends_on };
      eligible.push(selected);
    }
  }
  const profile = `/tenant/${tenantId}/people/${employeeId}`;
  const profileQuery = { tab: 'compensation', ...(validBefore ? { payrollBefore: validBefore } : {}), ...(returnTo ? { return: returnTo } : {}) };
  const startPayroll = `/tenant/${tenantId}/payroll?${new URLSearchParams({ employer: employerId })}`;
  const earlier = periods.length === 24 ? periods[periods.length - 1]?.starts_on : null;
  const heading = <h2>الضريبة والتأمينات</h2>;
  const picker = <form method="get" action={profile} className="workspace-form-actions">
    {Object.entries(profileQuery).map(([key,value]) => <input key={key} type="hidden" name={key} value={value}/>)}
    <Field id="employee-payroll-period" label="فترة الرواتب"><Select id="employee-payroll-period" name="payrollPeriod" required defaultValue={selected?.id ?? ''}><option value="" disabled>اختر الفترة</option>{eligible.map(period => <option key={period.id} value={period.id}>{period.starts_on} — {period.ends_on}</option>)}</Select></Field>
    <Button type="submit" variant="ghost">عرض البيانات</Button>
  </form>;
  if (!selected) return <Panel>{heading}
    {requestedPeriod && <Message tone="info">تعذر فتح الفترة المطلوبة أو أنها لا تقع ضمن مدة عمل الموظف. اختر فترة مناسبة؛ لم نختر فترة أخرى بدلًا منها.</Message>}
    {eligible.length ? <><p className="record-meta">اختر الفترة التي تجهّز راتبها، وستظهر بيانات هذا الموظف هنا.</p>{picker}</> : <p>لا توجد فترة رواتب في هذه القائمة تقع ضمن مدة عمل الموظف.</p>}
    <div className="workspace-form-actions"><ButtonLink href={startPayroll}>{periods.length ? 'فتح المسيرات وإنشاء فترة' : 'إنشاء أول مسير'}</ButtonLink>{earlier && <ButtonLink variant="ghost" href={`${profile}?${new URLSearchParams({ ...profileQuery, payrollBefore: earlier })}`}>فترات أقدم</ButtonLink>}</div>
  </Panel>;
  const result = await client.rpc('payroll_egypt_setup_context', { p_tenant: tenantId, p_employer: employerId, p_period: selected.id, p_employment: employmentId });
  const facts = !result.error && result.data && typeof result.data === 'object' && !Array.isArray(result.data) ? result.data as EgyptContext : null;
  const profileHref = `${profile}?${new URLSearchParams({ ...profileQuery, payrollPeriod: selected.id })}`;
  const scope = new URLSearchParams({ employer: employerId, period: selected.id });
  const review = `/tenant/${tenantId}/payroll/runs?${scope}`;
  const advanced = `/tenant/${tenantId}/payroll/inputs?${new URLSearchParams({ employer: employerId, period: selected.id, employee: employmentId, q: employeeCode, task: 'fix', kind: 'statutory_context', return: profileHref })}`;
  const openingHref = `/tenant/${tenantId}/payroll/inputs?${new URLSearchParams({ employer: employerId, period: selected.id, employee: employmentId, q: employeeCode, task: 'fix', kind: 'opening_ytd', ...(facts?.opening?.id ? { head: facts.opening.id } : {}), return: profileHref })}`;
  return <Panel>{heading}{picker}
    {!facts ? <Message tone="warn">تعذر تحميل بيانات الموظف لهذه الفترة. تحقق من إضافته إلى مسيرات الرواتب، ثم أعد المحاولة.</Message> : <>
      {!access.enabled && <Message tone="info">خدمة الرواتب موقوفة حاليًا. البيانات السابقة متاحة للقراءة.</Message>}
      <EgyptForm key={`${selected.id}:${facts.stamp}`} tenant={tenantId} employer={employerId} period={selected.id} employment={employmentId} facts={facts} advanced={advanced} openingHref={openingHref} review={review} profileHref={profileHref} readOnly={!access.enabled}/>
    </>}
    {earlier && <ButtonLink variant="ghost" href={`${profile}?${new URLSearchParams({ ...profileQuery, payrollBefore: earlier })}`}>فترات أقدم</ButtonLink>}
  </Panel>;
}
