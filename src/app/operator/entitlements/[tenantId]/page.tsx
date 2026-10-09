import { PageHeader, Badge, Disclosure } from '@/components/ui';
import { Panel, Message } from '@/components/ui';
import { Button, ButtonLink, Input, Select, Textarea } from '@/components/ui';
import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
import Link from 'next/link';
import { operatorEntitlementSnapshot, type OperatorEntitlement } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { CompanyTaskLinks } from '@/app/operator/company-task-links';
import { operatorPermission, sameCompanyScope } from '@/lib/operator-access';
import { OperatorActionForm } from '@/app/operator/operator-action-form';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeTenantEntitlementAction } from '../actions';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string }>;
type Decision = OperatorEntitlement;

export default async function TenantEntitlementsPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) redirect('/operator/entitlements?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [status, commercial, lifecycle] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_commercial_access'),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle').then(result => result, (error: unknown) => ({ data: null, error })),
  ]);
  if (status.error || status.data !== 'active' || !operatorPermission(commercial)) return <Status title="إدارة إتاحة الوحدات غير متاحة" />;
  const { data, error } = await supabase.rpc('platform_tenant_entitlement_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل إتاحة الشركة" />;
  const tenant = data;
  if (!operatorEntitlementSnapshot(tenant) || !sameCompanyScope(tenant.tenant_id, tenantId)) return <Status title="بيانات الإتاحة غير مكتملة" />;
  const decisions = [...tenant.entitlements].sort((a, b) => Number(a.capability_key === 'hr.payroll') - Number(b.capability_key === 'hr.payroll'));
  const peopleAvailable = decisions.some((decision) => decision.capability_key === 'hr.people'
    && decision.status === 'effective' && decision.is_granted === true && decision.evaluator_enabled);
  const leaveAvailable = decisions.some((decision) => decision.capability_key === 'hr.leave'
    && decision.status === 'effective' && decision.is_granted === true && decision.evaluator_enabled);

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><ButtonLink variant="ghost"  href="/operator/entitlements">قائمة الشركات</ButtonLink>
        <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form></nav></header>
    <Panel className="operator-setting-detail" aria-labelledby="entitlements-title">
      <p className="eyebrow">إتاحة الوحدات</p><PageHeader id="entitlements-title" title={<><bdi>{tenant.display_name}</bdi></>} />
      <Badge as="p" className={` ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</Badge>
      <CompanyTaskLinks tenantId={tenantId} current="entitlements" lifecycle={operatorPermission(lifecycle)} commercial={true} />
      {query.state === 'updated' && <Message tone="info"  role="status">إتاحة الوحدات الحالية معروضة أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.</Message>}
      {query.state && query.state !== 'updated' && <Message tone="info"  role="alert">{stateText(query.state)}</Message>}
      <p className="field-hint">تحدد هذه القرارات ما سيتاح للشركة عند إطلاق وحدات الموارد البشرية والرواتب.</p>
      <div className="operator-setting-grid">{decisions.map((decision) => <DecisionCard key={decision.capability_key} tenantId={tenantId} decision={decision} peopleAvailable={peopleAvailable} leaveAvailable={leaveAvailable} />)}</div>
    </Panel>
  </main>;
}

function DecisionCard({ tenantId, decision, peopleAvailable, leaveAvailable }: { tenantId: string; decision: Decision; peopleAvailable: boolean; leaveAvailable: boolean }) {
  const people = decision.capability_key === 'hr.people';
  const label = people ? 'إدارة الموارد البشرية' : decision.capability_key === 'hr.payroll' ? 'الرواتب' : decision.capability_key === 'hr.attendance' ? 'الحضور والسياسات' : decision.capability_key === 'hr.employee_finance' ? 'تمويل الموظفين' : 'إدارة الإجازات';
  const enabled = decision.status === 'effective' && decision.is_granted === true && decision.evaluator_enabled;
  const state = decision.status === 'conflict' || decision.status === 'future_conflict' ? 'تحتاج مراجعة'
    : enabled ? 'متاحة' : decision.is_granted && !decision.evaluator_enabled ? 'غير فعّالة' : 'غير متاحة';
  return <article className="operator-setting-card" aria-labelledby={`${decision.capability_key}-title`}>
    <h2 id={`${decision.capability_key}-title`}>{label}</h2>
    <Badge as="p" className={` ${enabled ? 'is-active' : 'is-inactive'}`}>{state}</Badge>
    {decision.status === 'missing' && <p className="field-hint">{decision.last_decision_valid_until
      ? `انتهى آخر قرار في ${dateLabel(decision.last_decision_valid_until)}. يلزم قرار إتاحة جديد.`
      : 'لم تُتح هذه الوحدة للشركة بعد.'}</p>}
    {decision.status === 'conflict' && <Message tone="info"  role="alert">تعارض في القرارات السارية؛ الإتاحة مغلقة حتى إصلاح البيانات.</Message>}
    {decision.status === 'future_conflict' && <Message tone="info"  role="alert">يوجد قرار مستقبلي متعارض؛ عالجه عبر مسار الصيانة.</Message>}
    {decision.capability_key === 'hr.payroll' && !peopleAvailable &&
      <p className="field-hint">لإتاحة الرواتب، <a href="#hr.people-title">أتح إدارة الموارد البشرية أولًا</a>. يمكنك إيقاف الرواتب من هنا إذا لزم.</p>}
    {decision.capability_key === 'hr.employee_finance' && <p className="field-hint">إتاحة تمويل الموظفين مستقلة؛ جدولة الخصم تحتاج فترات رواتب محفوظة. إيقاف الإتاحة يمنع التزامات جديدة ويُبقي تسوية الأرصدة القائمة للمسؤول المخول.</p>}
    {decision.capability_key === 'hr.employee_finance' && !peopleAvailable && <p className="field-hint">أتح إدارة الموارد البشرية أولًا لإنشاء سلف الموظفين.</p>}
    {decision.capability_key === 'hr.leave' && !peopleAvailable && <p className="field-hint">لإتاحة الإجازات، أتح إدارة الموارد البشرية أولًا.</p>}
    {decision.capability_key === 'hr.leave' && leaveAvailable && <p className="field-hint">الإجازات لا تعتمد على إتاحة الحضور.</p>}
    {decision.valid_from && <p className="field-hint">ساري من {dateLabel(decision.valid_from)}</p>}
    {decision.valid_until && <p className="field-hint">آخر يوم سريان: {new Date(new Date(decision.valid_until).getTime() - 1).toLocaleDateString(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo', numberingSystem: 'latn', day: 'numeric', month: 'long', year: 'numeric' })}</p>}
    {decision.status !== 'conflict' && decision.status !== 'future_conflict' && <Disclosure summary={<>{decision.status === 'missing' ? `تحديد إتاحة ${label}` : `تغيير إتاحة ${label}`}</>} className="operator-grant-form">

      <OperatorActionForm action={changeTenantEntitlementAction} errorMessages={entitlementErrors} label={`حفظ إتاحة ${label}`}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="capability" value={decision.capability_key} />
        <label htmlFor={`${decision.capability_key}-decision`}>القرار</label>
        <Select id={`${decision.capability_key}-decision`} name="decision" defaultValue={decision.is_granted && (people || decision.capability_key === 'hr.attendance' || peopleAvailable) ? 'grant' : 'deny'}>
          <option value="grant" disabled={!people && decision.capability_key !== 'hr.attendance' && !peopleAvailable}>إتاحة</option><option value="deny">منع</option>
        </Select>
        <label htmlFor={`${decision.capability_key}-expiry`}>آخر يوم سريان (اختياري، بتوقيت القاهرة)</label>
        <Input id={`${decision.capability_key}-expiry`} name="expiresOn" type="date" />
        <label htmlFor={`${decision.capability_key}-reason`}>سبب التغيير</label>
        <Textarea id={`${decision.capability_key}-reason`} name="reason" required minLength={3} maxLength={500} rows={3} />
      </OperatorActionForm>
    </Disclosure>}
  </article>;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function dateLabel(value: string) { return new Date(value).toLocaleDateString(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo', numberingSystem: 'latn', day: 'numeric', month: 'long', year: 'numeric' }); }
function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function stateText(state: string) {
  return Object.hasOwn(entitlementErrors, state) ? entitlementErrors[state] : 'نتيجة الإجراء غير مؤكدة. راجع الإتاحة الحالية قبل إجراء آخر.';
}
const entitlementErrors: Record<string, string> = {
    invalid: 'تحقق من بيانات القرار.', reason: 'أدخل سببًا من 3 إلى 500 حرف.', setup: 'إعداد Supabase غير مكتمل.',
    'finance-people-required': 'أتح إدارة الموارد البشرية أولًا، واجعل نهاية إتاحة تمويل الموظفين ضمن فترة إتاحتها.',
    'finance-first': 'أوقف إتاحة تمويل الموظفين أولًا أو اجعلها تنتهي قبل إنهاء الموارد البشرية. لا تُسقط الأرصدة القائمة.',
    'leave-people-required': 'أتح إدارة الموارد البشرية أولًا، وتأكد أن نهاية إتاحة الإجازات لا تتجاوز نهايتها.',
    forbidden: 'لم تعد لديك صلاحية إدارة الإتاحة.', 'not-found': 'الشركة غير متاحة.',
    'people-required': 'أتح إدارة الموارد البشرية أولًا، واجعل نهاية إتاحة الرواتب والإجازات ضمن فترة إتاحتها.',
    'payroll-first': 'أوقف إتاحة الرواتب أولًا أو اجعلها تنتهي قبل إنهاء الموارد البشرية.',
    'leave-first': 'أوقف إتاحة الإجازات أولًا أو اجعلها تنتهي قبل إنهاء الموارد البشرية.',
    'people-children-first': 'أوقف إتاحة الرواتب والإجازات أولًا أو اجعلها تنتهي قبل إنهاء الموارد البشرية.',
    'future-conflict': 'يوجد قرار مستقبلي؛ لم يتغير أي سجل.', conflict: 'توجد قرارات فعّالة متعارضة؛ لم يتغير شيء.',
    expiry: 'يجب أن يكون آخر يوم سريان في المستقبل.',
    failed: 'لم تتأكد نتيجة تحديث القرار. راجع إتاحة الوحدات الحالية قبل إجراء آخر.',
};
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><Panel className="auth-card"><PageHeader  title={<>{title}</>} /><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><ButtonLink variant="ghost"  href="/operator/entitlements">قائمة الشركات</ButtonLink></Panel></main>; }
