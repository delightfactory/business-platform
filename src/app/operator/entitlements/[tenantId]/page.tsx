import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { FeedbackToast } from '@/components/feedback-toast';
import { OperatorActionForm } from '@/app/operator/operator-action-form';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeTenantEntitlementAction } from '../actions';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string }>;
type Decision = { capability_key: 'hr.people' | 'hr.payroll' | 'hr.attendance' | 'hr.leave' | 'hr.employee_finance'; status: string; is_granted: boolean | null; valid_from: string | null; valid_until: string | null; evaluator_enabled: boolean; last_decision: boolean | null; last_decision_valid_from: string | null; last_decision_valid_until: string | null };
type Snapshot = { tenant_id: string; display_name: string; lifecycle_state: string; entitlements: Decision[] };

export default async function TenantEntitlementsPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) redirect('/operator/entitlements?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [{ data: status }, { data: authorized }] = await Promise.all([
    supabase.rpc('current_platform_operator_status'),
    supabase.rpc('current_operator_can_manage_commercial_access'),
  ]);
  if (status !== 'active' || !authorized) return <Status title="إدارة إتاحة الوحدات غير متاحة" />;
  const { data, error } = await supabase.rpc('platform_tenant_entitlement_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل إتاحة الشركة" />;
  const tenant = data as Snapshot;
  const expectedCapabilities = ['hr.people', 'hr.payroll', 'hr.attendance', 'hr.leave', 'hr.employee_finance'];
  if (!Array.isArray(tenant.entitlements) || tenant.entitlements.length !== expectedCapabilities.length
    || new Set(tenant.entitlements.map((item) => item.capability_key)).size !== expectedCapabilities.length
    || expectedCapabilities.some((key) => !tenant.entitlements.some((item) => item.capability_key === key))) return <Status title="بيانات الإتاحة غير مكتملة" />;
  const decisions = [...tenant.entitlements].sort((a, b) => Number(a.capability_key === 'hr.payroll') - Number(b.capability_key === 'hr.payroll'));
  const peopleAvailable = decisions.some((decision) => decision.capability_key === 'hr.people'
    && decision.status === 'effective' && decision.is_granted === true && decision.evaluator_enabled);
  const leaveAvailable = decisions.some((decision) => decision.capability_key === 'hr.leave'
    && decision.status === 'effective' && decision.is_granted === true && decision.evaluator_enabled);

  return <main className="app-shell">
    {query.state === 'updated' && <FeedbackToast key={crypto.randomUUID()} message="تم تحديث إتاحة الوحدة وتسجيل السبب." />}
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator/entitlements">قائمة الشركات</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
    <section className="work-card operator-setting-detail" aria-labelledby="entitlements-title">
      <p className="eyebrow">إتاحة الوحدات</p><h1 id="entitlements-title"><bdi>{tenant.display_name}</bdi></h1>
      <p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p>
      {query.state && query.state !== 'updated' && <p className="form-message" role="alert">{stateText(query.state)}</p>}
      <p className="field-hint">تحدد هذه القرارات ما سيتاح للشركة عند إطلاق وحدات الموارد البشرية والرواتب.</p>
      <div className="operator-setting-grid">{decisions.map((decision) => <DecisionCard key={decision.capability_key} tenantId={tenantId} decision={decision} peopleAvailable={peopleAvailable} leaveAvailable={leaveAvailable} />)}</div>
    </section><footer className="footer">منصة الأعمال · إتاحة الوحدات</footer>
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
    <p className={`entity-status ${enabled ? 'is-active' : 'is-inactive'}`}>{state}</p>
    {decision.status === 'missing' && <p className="field-hint">{decision.last_decision_valid_until
      ? `انتهى آخر قرار في ${dateLabel(decision.last_decision_valid_until)}. يلزم قرار إتاحة جديد.`
      : 'لم تُتح هذه الوحدة للشركة بعد.'}</p>}
    {decision.status === 'conflict' && <p className="form-message" role="alert">تعارض في القرارات السارية؛ الإتاحة مغلقة حتى إصلاح البيانات.</p>}
    {decision.status === 'future_conflict' && <p className="form-message" role="alert">يوجد قرار مستقبلي متعارض؛ عالجه عبر مسار الصيانة.</p>}
    {decision.capability_key === 'hr.payroll' && !peopleAvailable &&
      <p className="field-hint">لإتاحة الرواتب، <a href="#hr.people-title">أتح إدارة الموارد البشرية أولًا</a>. يمكنك إيقاف الرواتب من هنا إذا لزم.</p>}
    {decision.capability_key === 'hr.employee_finance' && <p className="field-hint">إتاحة تمويل الموظفين مستقلة؛ جدولة الخصم تحتاج فترات رواتب محفوظة. إيقاف الإتاحة يمنع التزامات جديدة ويُبقي تسوية الأرصدة القائمة للمسؤول المخول.</p>}
    {decision.capability_key === 'hr.employee_finance' && !peopleAvailable && <p className="field-hint">أتح إدارة الموارد البشرية أولًا لإنشاء سلف الموظفين.</p>}
    {decision.capability_key === 'hr.leave' && !peopleAvailable && <p className="field-hint">لإتاحة الإجازات، أتح إدارة الموارد البشرية أولًا.</p>}
    {decision.capability_key === 'hr.leave' && leaveAvailable && <p className="field-hint">الإجازات لا تعتمد على إتاحة الحضور.</p>}
    {decision.valid_from && <p className="field-hint">ساري من {dateLabel(decision.valid_from)}</p>}
    {decision.valid_until && <p className="field-hint">آخر يوم سريان: {new Date(new Date(decision.valid_until).getTime() - 1).toLocaleDateString('ar-EG', { timeZone: 'Africa/Cairo', day: 'numeric', month: 'long', year: 'numeric' })}</p>}
    {decision.status !== 'conflict' && decision.status !== 'future_conflict' && <details className="operator-grant-form">
      <summary className="secondary-button">{decision.status === 'missing' ? `تحديد إتاحة ${label}` : `تغيير إتاحة ${label}`}</summary>
      <OperatorActionForm action={changeTenantEntitlementAction} errorMessages={entitlementErrors} label={`حفظ إتاحة ${label}`}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="capability" value={decision.capability_key} />
        <label htmlFor={`${decision.capability_key}-decision`}>القرار</label>
        <select id={`${decision.capability_key}-decision`} name="decision" defaultValue={decision.is_granted && (people || decision.capability_key === 'hr.attendance' || peopleAvailable) ? 'grant' : 'deny'}>
          <option value="grant" disabled={!people && decision.capability_key !== 'hr.attendance' && !peopleAvailable}>إتاحة</option><option value="deny">منع</option>
        </select>
        <label htmlFor={`${decision.capability_key}-expiry`}>آخر يوم سريان (اختياري، بتوقيت القاهرة)</label>
        <input id={`${decision.capability_key}-expiry`} name="expiresOn" type="date" />
        <label htmlFor={`${decision.capability_key}-reason`}>سبب التغيير</label>
        <textarea id={`${decision.capability_key}-reason`} name="reason" required minLength={3} maxLength={500} rows={3} />
      </OperatorActionForm>
    </details>}
  </article>;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function dateLabel(value: string) { return new Date(value).toLocaleDateString('ar-EG', { timeZone: 'Africa/Cairo', day: 'numeric', month: 'long', year: 'numeric' }); }
function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function stateText(state: string) {
  return entitlementErrors[state] ?? 'تعذر إتمام الإجراء.';
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
    failed: 'تعذر تحديث القرار. لم يُعتمد التغيير دون سجل تدقيق.',
};
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><Link className="secondary-button" href="/operator/entitlements">قائمة الشركات</Link></section></main>; }


