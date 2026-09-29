import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeTenantEntitlementAction } from '../actions';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string }>;
type Decision = { capability_key: 'hr.people' | 'hr.payroll'; status: string; is_granted: boolean | null; valid_from: string | null; valid_until: string | null; evaluator_enabled: boolean; last_decision: boolean | null; last_decision_valid_from: string | null; last_decision_valid_until: string | null };
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
  if (!Array.isArray(tenant.entitlements) || tenant.entitlements.length !== 2) return <Status title="بيانات الإتاحة غير مكتملة" />;

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator/entitlements">قائمة الشركات</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
    <section className="work-card" aria-labelledby="entitlements-title">
      <p className="eyebrow">إتاحة الوحدات الاختيارية</p><h1 id="entitlements-title"><bdi>{tenant.display_name}</bdi></h1>
      <p className="intro">حالة الشركة: {stateLabel(tenant.lifecycle_state)}</p>
      {query.state === 'updated' && <p className="form-message" role="status">تم تحديث الإتاحة وتسجيل السبب.</p>}
      {query.state && query.state !== 'updated' && <p className="form-message" role="alert">{stateText(query.state)}</p>}
      <p className="field-hint">هذه القرارات تجهز إتاحة الموارد البشرية والرواتب عند إطلاقهما. لا توقف أي عملية حالية في المنصة.</p>
      <div className="member-list">{tenant.entitlements.map((decision) => <DecisionCard key={decision.capability_key} tenantId={tenantId} decision={decision} />)}</div>
    </section><footer className="footer">منصة الأعمال · إتاحة الوحدات</footer>
  </main>;
}

function DecisionCard({ tenantId, decision }: { tenantId: string; decision: Decision }) {
  const people = decision.capability_key === 'hr.people';
  const label = people ? 'إدارة الموارد البشرية' : 'الرواتب';
  return <article className="work-card" aria-labelledby={`${decision.capability_key}-title`}>
    <h2 id={`${decision.capability_key}-title`}>{label}</h2>
    {decision.status === 'missing' ? <div className="form-message" role="status">
      <p>{decision.last_decision_valid_until ? `انتهى آخر قرار (${decision.last_decision ? 'إتاحة' : 'منع'}) في ${dateTime(decision.last_decision_valid_until)}؛ الإتاحة الآن مرفوضة افتراضيًا.` : 'لم يُسجّل قرار سارٍ؛ الإتاحة مرفوضة افتراضيًا.'}</p>
      <p>انتهاء قرار المنع لا يتيح الوحدة تلقائيًا؛ يلزم وجود قرار إتاحة ساري.</p>
    </div>
      : decision.status === 'conflict' ? <p className="form-message" role="alert">تعارض في القرارات الفعّالة؛ الإتاحة مغلقة حتى إصلاح البيانات.</p>
        : decision.status === 'future_conflict' ? <p className="form-message" role="alert">يوجد قرار مستقبلي متعارض؛ عالجه عبر مسار صيانة.</p>
          : <p>{decision.is_granted ? 'مسموحة' : 'مرفوضة'}{decision.capability_key === 'hr.payroll' && !decision.evaluator_enabled ? ' · غير فعّالة لغياب إتاحة الموارد البشرية' : ''}</p>}
    {decision.valid_from && <p className="field-hint">بدأ القرار: {dateTime(decision.valid_from)} بتوقيت القاهرة</p>}
    {decision.valid_until && <p className="field-hint">آخر يوم سريان: {new Date(new Date(decision.valid_until).getTime() - 1).toLocaleDateString('ar-EG', { timeZone: 'Africa/Cairo' })}</p>}
    {decision.status !== 'conflict' && decision.status !== 'future_conflict' && <details className="operator-grant-form">
      <summary className="secondary-button">تغيير القرار</summary>
      <form action={changeTenantEntitlementAction} className="auth-form">
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="capability" value={decision.capability_key} />
        <label htmlFor={`${decision.capability_key}-decision`}>القرار</label>
        <select id={`${decision.capability_key}-decision`} name="decision" defaultValue={decision.is_granted ? 'grant' : 'deny'}>
          <option value="grant">إتاحة</option><option value="deny">منع</option>
        </select>
        <label htmlFor={`${decision.capability_key}-expiry`}>آخر يوم سريان (اختياري، بتوقيت القاهرة)</label>
        <input id={`${decision.capability_key}-expiry`} name="expiresOn" type="date" />
        <label htmlFor={`${decision.capability_key}-reason`}>سبب التغيير</label>
        <textarea id={`${decision.capability_key}-reason`} name="reason" required minLength={3} maxLength={500} rows={3} />
        <button className="primary-button" type="submit">تأكيد القرار</button>
      </form>
    </details>}
  </article>;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function dateTime(value: string) { return new Date(value).toLocaleString('ar-EG', { timeZone: 'Africa/Cairo' }); }
function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function stateText(state: string) {
  const messages: Record<string, string> = {
    invalid: 'تحقق من بيانات القرار.', reason: 'أدخل سببًا من 3 إلى 500 حرف.', setup: 'إعداد Supabase غير مكتمل.',
    forbidden: 'لم تعد لديك صلاحية إدارة الإتاحة.', 'not-found': 'الشركة غير متاحة.',
    'people-required': 'أتح الموارد البشرية أولًا، واجعل نهاية إتاحة الرواتب لا تتجاوز نهاية إتاحة الموارد البشرية.',
    'payroll-first': 'أوقف إتاحة الرواتب أولًا أو اجعلها تنتهي قبل إنهاء الموارد البشرية.',
    'future-conflict': 'يوجد قرار مستقبلي؛ لم يتغير أي سجل.', conflict: 'توجد قرارات فعّالة متعارضة؛ لم يتغير شيء.',
    expiry: 'يجب أن يكون آخر يوم سريان في المستقبل.',
    failed: 'تعذر تحديث القرار. لم يُعتمد التغيير دون سجل تدقيق.',
  };
  return messages[state] ?? 'تعذر إتمام الإجراء.';
}
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><Link className="secondary-button" href="/operator/entitlements">قائمة الشركات</Link></section></main>; }
