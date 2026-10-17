import { Badge, Button, ButtonLink, Disclosure, Field, Message, Panel, Select } from '@/components/ui';
import { getWorkspaceClient } from '@/lib/workspace-access';
import { safeReturn } from '@/lib/return-to';
import { displayDate, uuid } from '../../payroll/rules';
import { type InputRecord } from '../../payroll/inputs/rules';
import { AdjustmentTypeForm, EmployeeAdjustmentForm, type AdjustmentComponent, type AdjustmentPeriod } from './EmployeeAdjustmentForm';

type Workspace = {
  access: Record<string, boolean>; employment?: string; employer?: string; eligible?: boolean;
  periods: AdjustmentPeriod[]; period: AdjustmentPeriod | null; locked: boolean;
  records: InputRecord[]; components: AdjustmentComponent[]; focused_record:InputRecord|null;
};

export async function EmployeeAdjustments({ tenant, employee, period, before, after, focus, feedback, returnTo }: {
  tenant: string; employee: string; period?: string; before?: string; after?: string; focus?:string; feedback?:string; returnTo?: string | null;
}) {
  const client = await getWorkspaceClient();
  if (!client) return <Message tone="warn">تعذر الاتصال. أعد تحميل الملف.</Message>;
  if (period && !uuid(period) || after && !uuid(after) || before && !/^\d{4}-\d{2}-\d{2}$/.test(before)) return <Message tone="bad">رابط الفترة غير صالح. <a href="?tab=adjustments">اختيار الفترة من جديد</a></Message>;
  const result = await client.rpc('people_employee_adjustments', {
    p_tenant: tenant, p_employee: employee, p_period: period ?? null, p_before: before ?? null, p_after: after ?? null, p_focus:focus&&uuid(focus)?focus:null,
  });
  if (result.error || !result.data) return <Panel><h2>المكافآت والجزاءات</h2><Message tone="warn">{result.error?.code === '42501' ? 'عرض هذا السجل يحتاج صلاحية المكافآت والجزاءات. اطلبها من مدير الشركة.' : 'تعذر تحميل الفترة والسجل. أعد تحميل الملف، أو اختر الفترة من جديد.'}</Message><ButtonLink variant="ghost" href="?tab=adjustments">إعادة فتح السجل</ButtonLink></Panel>;
  const workspace = result.data as Workspace;
  if (!workspace.employment || !workspace.employer) return <Panel><h2>المكافآت والجزاءات</h2><p>أكمل بيانات عمل الموظف أولًا من «سجل العمل».</p></Panel>;
  const path = `/tenant/${tenant}/people/${employee}`;
  const safeBack = safeReturn(tenant, returnTo ?? undefined);
  const href = (values: Record<string, string>) => `${path}?${new URLSearchParams({ tab: 'adjustments', ...(safeBack ? { return: safeBack } : {}), ...(workspace.period ? { adjustmentPeriod: workspace.period.id } : {}), ...values })}`;
  const periods = workspace.period && !workspace.periods.some(item => item.id === workspace.period?.id) ? [workspace.period, ...workspace.periods] : workspace.periods;
  const access = workspace.access;
  const canManage = access['employee_finance.manage'] === true && access.enabled === true;
  const canApprove = access['employee_finance.approve'] === true && access.enabled === true;
  const pageRecords = workspace.records.slice(0, 20);
  const records = workspace.focused_record&&!pageRecords.some(item=>item.id===workspace.focused_record?.id) ? [workspace.focused_record,...pageRecords] : pageRecords;
  const components = workspace.components;
  const missingKinds=(['earning','deduction'] as const).filter(kind=>!components.some(component=>component.classification===kind));
  const scope = workspace.period ? { tenant, employee, employer: workspace.employer, employment: workspace.employment, period: workspace.period, returnTo:safeBack } : null;
  const saved=records.find(record=>record.id===focus && record.status===feedback);
  return <>
    {saved && <Message tone="ok" role="status">{saved.status==='approved'?'تم الاعتماد. سيُدرج المبلغ عند حساب مسير هذه الفترة. إذا حُسب سابقًا، أعد حسابه قبل اعتماده.':saved.status==='cancelled'?'تم إلغاء الإضافة. أعد حساب المسير إذا كان محسوبًا قبل الإلغاء.':'تم الحفظ بانتظار الاعتماد. افتح السجل أدناه لاعتماده؛ لن يدخل المسير قبل الاعتماد.'}</Message>}
    {feedback==='type'&&components.some(item=>item.id===focus)&&<Message tone="ok" role="status">تم تجهيز النوع للشركة. يمكنك إضافة المبلغ الآن.</Message>}
    <Panel><h2>المكافآت والجزاءات</h2><p className="record-meta">أضف المبلغ وسببه هنا. بعد الاعتماد يدخل في حساب مسير الفترة المختارة، دون إعادة إدخاله.</p>
      {periods.length > 0 ? <form action={path} className="auth-form compact-form">
        <input type="hidden" name="tab" value="adjustments"/>{safeBack && <input type="hidden" name="return" value={safeBack}/>}
        <Field id="adjustment-period" label="فترة الراتب" help="نعرض الفترة الحالية تلقائيًا إذا كانت محددة. اختر الفترة التي تريد أن يظهر فيها المبلغ."><Select id="adjustment-period" name="adjustmentPeriod" required defaultValue={workspace.period?.id ?? ''}><option value="" disabled>اختر الفترة</option>{periods.map(item => <option key={item.id} value={item.id}>{displayDate(item.starts_on)} — {displayDate(item.ends_on)}</option>)}</Select></Field>
        <Button type="submit" variant="ghost">عرض الفترة</Button>
      </form> : <Message tone="info">لا توجد فترات رواتب مناسبة للعمل المسجل. جهّز أول مسير، ثم ارجع إلى ملف الموظف لإضافة المبلغ.</Message>}
      {workspace.periods.length === 24 && <ButtonLink variant="ghost" href={href({ adjustmentPeriod: '', adjustmentBefore: workspace.periods.at(-1)!.starts_on })}>فترات أقدم</ButtonLink>}
      {before && <ButtonLink variant="ghost" href={href({ adjustmentPeriod: '', adjustmentBefore: '' })}>العودة للفترة الحالية</ButtonLink>}
      {!access.enabled && <Message tone="info">خدمة الرواتب غير مفعلة للإضافات الجديدة. السجل المحفوظ متاح للمراجعة؛ راجع مدير الشركة لتفعيل الخدمة.</Message>}
    </Panel>
    {scope && <>
      {workspace.locked ? <Panel><Message tone="info">أُقفل راتب الموظف لهذه الفترة. اختر فترة مفتوحة لإضافة مبلغ جديد؛ المبالغ المحفوظة لا تتغير.</Message>{access['payroll.correct'] && <ButtonLink variant="ghost" href={`/tenant/${tenant}/payroll/corrections?person=${employee}`}>تصحيح راتب مقفل</ButtonLink>}</Panel>
        : !workspace.eligible ? <Message tone="info">الموظف غير مضاف إلى مسيرات الرواتب. راجع إضافته من قسم «الراتب» في ملفه أولًا.</Message>
        : canManage && !workspace.focused_record && <Panel><h3>إضافة مكافأة أو جزاء</h3><EmployeeAdjustmentForm scope={scope} components={components} canManage={canManage} canApprove={canApprove} locked={false}/></Panel>}
      <Panel><h3>سجل هذه الفترة</h3>
        {!records.length && <p className="record-meta">{after ? 'لا توجد سجلات أخرى.' : 'لم تسجل مكافآت أو جزاءات لهذا الموظف في هذه الفترة بعد.'}</p>}
        {records.map(record => <Disclosure key={`${record.id}:${record.revision}`} open={record.id===focus} summary={`${components.find(item => item.id === record.data.component_id)?.name ?? 'مكافأة أو خصم'} · ${Number(record.data.amount).toLocaleString('ar-EG')} جنيه · ${record.status === 'draft' ? 'بانتظار الاعتماد' : record.status === 'approved' ? 'معتمد' : record.status === 'applied' ? 'أُدرج في المسير' : 'ملغى'}`}>
          <EmployeeAdjustmentForm scope={scope} record={record} components={components} canManage={canManage} canApprove={canApprove} locked={workspace.locked}/>
        </Disclosure>)}
        {workspace.records.length > 20 && <ButtonLink variant="ghost" href={href({ adjustmentAfter: pageRecords.at(-1)!.id })}>سجلات أخرى</ButtonLink>}
        {after && <ButtonLink variant="ghost" href={href({ adjustmentAfter: '' })}>بداية السجل</ButtonLink>}
      </Panel>
      {workspace.focused_record&&canManage&&workspace.eligible&&!workspace.locked&&<Disclosure summary="إضافة مكافأة أو جزاء آخر"><Panel><EmployeeAdjustmentForm scope={scope} components={components} canManage={canManage} canApprove={canApprove} locked={false}/></Panel></Disclosure>}
      {missingKinds.length>0&&access['payroll_config.manage'] && access.enabled && !workspace.locked && <Disclosure summary="تجهيز نوع مكافأة أو جزاء للشركة"><Panel><p className="record-meta">مرة واحدة لكل نوع. اختَر معاملته حسب سياسة الشركة، ثم أضف المبالغ للموظفين.</p><AdjustmentTypeForm scope={scope} kinds={missingKinds} keySuffix={crypto.randomUUID().slice(0,8)}/></Panel></Disclosure>}
      {components.length === 101 && <Message tone="info">يوجد المزيد من الأنواع. <a href={`/tenant/${tenant}/payroll/inputs?${new URLSearchParams({ employer: scope.employer, period: scope.period.id, kind: 'adjustment', employee: scope.employment, return: href({}) })}`}>عرض جميع الأنواع</a></Message>}
    </>}
    {(access['payroll.view'] || access['payroll.prepare']) && <ButtonLink variant="ghost" href={`/tenant/${tenant}/payroll?${new URLSearchParams({ employer: workspace.employer, ...(workspace.period ? { period: workspace.period.id } : {}) })}`}>{workspace.period ? 'فتح المسير وحساب الرواتب' : 'تجهيز أول مسير'}</ButtonLink>}
    {!canManage && !canApprove && <Badge>للعرض فقط</Badge>}
  </>;
}
