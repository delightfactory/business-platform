import Link from 'next/link';
import { operatorCommercialSnapshot, type OperatorLimit } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { CompanyTaskLinks } from '@/app/operator/company-task-links';
import { operatorPermission, sameCompanyScope } from '@/lib/operator-access';
import { OperatorActionForm } from '@/app/operator/operator-action-form';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { changeCommercialLimitAction } from '../actions';
import { LimitModeFields } from './LimitModeFields';

export const dynamic = 'force-dynamic';
type Query = Promise<{ state?: string }>;
type Params = Promise<{ tenantId: string }>;
type Limit = OperatorLimit;

export default async function CommercialTenantPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) redirect('/operator/commercial?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const [operatorStatus, commercial, lifecycle] = await Promise.all([
    supabase.rpc('current_platform_operator_status'), supabase.rpc('current_operator_can_manage_commercial_access'),
    supabase.rpc('current_operator_can_manage_tenant_lifecycle').then(result => result, (error: unknown) => ({ data: null, error })),
  ]);
  if (operatorStatus.error || operatorStatus.data !== 'active' || !operatorPermission(commercial)) return <Status title="إدارة الحدود غير متاحة" />;
  const { data, error } = await supabase.rpc('platform_tenant_commercial_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status title="تعذر تحميل حدود الشركة" />;
  const tenant = data;
  if (!operatorCommercialSnapshot(tenant) || !sameCompanyScope(tenant.tenant_id, tenantId)) return <Status title="بيانات الحدود غير مكتملة" />;

  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator/commercial">قائمة الشركات</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
    <section className="work-card operator-setting-detail" aria-labelledby="commercial-title">
      <p className="eyebrow">حدود الاستخدام</p><h1 id="commercial-title"><bdi>{tenant.display_name}</bdi></h1>
      <p className={`entity-status ${tenant.lifecycle_state === 'active' ? 'is-active' : 'is-inactive'}`}>{stateLabel(tenant.lifecycle_state)}</p>
      <CompanyTaskLinks tenantId={tenantId} current="commercial" lifecycle={operatorPermission(lifecycle)} commercial={true} />
      {query.state === 'updated' && <p className="form-message" role="status">حدود الاستخدام الحالية معروضة أدناه؛ الرابط وحده لا يؤكد حفظ تغيير.</p>}
      {query.state && query.state !== 'updated' && <p className="form-message" role="alert">{stateText(query.state)}</p>}
      <div className="operator-setting-grid">{tenant.limits.map((limit) => <LimitCard key={limit.capability_key} tenantId={tenantId} limit={limit} />)}</div>
    </section><footer className="footer">منصة الأعمال · حدود الاستخدام</footer>
  </main>;
}

function LimitCard({ tenantId, limit }: { tenantId: string; limit: Limit }) {
  const users = limit.capability_key === 'tenant.users';
  const over = (limit.status === 'effective' || limit.status === 'future_conflict')
    && limit.mode === 'limited' && limit.value !== null && limit.usage > limit.value;
  const atCapacity = (limit.status === 'effective' || limit.status === 'future_conflict')
    && limit.mode === 'limited' && limit.value !== null && limit.usage === limit.value;
  return <article className="operator-setting-card" aria-labelledby={`${limit.capability_key}-title`}>
    <h2 id={`${limit.capability_key}-title`}>{users ? 'المستخدمون' : 'الفروع'}</h2>
    <p>{users ? 'المستخدمون النشطون' : 'الفروع النشطة'}: <strong>{limit.usage}</strong></p>
    {limit.status === 'missing' ? <p className="form-message" role="status">لا يوجد حد فعّال؛ أنشئ حدًا جديدًا لتفعيل إدارة النمو.</p>
      : limit.status === 'conflict' ? <p className="form-message" role="alert">تعارض في سجلات الحد. أصلح البيانات قبل إجراء تغيير.</p>
        : limit.status === 'future_conflict' ? <p className="form-message" role="alert">يوجد حد مستقبلي يتعارض مع التغيير الجديد. عالج الجدول الزمني عبر مسار صيانة.</p>
          : null}
    {limit.status !== 'conflict' && limit.mode && <>
      <p>الحد الحالي: <strong>{limit.mode === 'unlimited' ? 'غير محدود' : limit.value}</strong></p>
      {over && <p className="form-message" role="status">تبقى الموارد الموجودة فعّالة. لا يمكن إضافة {users ? 'مستخدمين' : 'فروع'} جديدة إلا عندما يصبح الاستخدام أقل من الحد أو يُرفع الحد. يمكن لمسؤول الشركة تعطيل {users ? 'حسابات' : 'فروع'} غير مستخدمة، أو طلب رفع الحد.</p>}
      {atCapacity && <p className="field-hint">بلغ الاستخدام الحد. لا يمكن إضافة جديد إلا عندما يصبح الاستخدام أقل من الحد أو يُرفع الحد؛ مسؤول الشركة يدير تعطيل الموارد غير المستخدمة.</p>}
      {limit.valid_from && <p className="field-hint">ساري من {new Date(limit.valid_from).toLocaleDateString('ar-EG', { timeZone: 'Africa/Cairo', numberingSystem: 'latn', day: 'numeric', month: 'long', year: 'numeric' })}</p>}
    </>}
    {limit.status !== 'conflict' && limit.status !== 'future_conflict' && <details className="operator-grant-form"><summary className="secondary-button">{limit.status === 'missing' ? `تحديد حد ${users ? 'المستخدمين' : 'الفروع'}` : `تغيير حد ${users ? 'المستخدمين' : 'الفروع'}`}</summary>
      <OperatorActionForm action={changeCommercialLimitAction} errorMessages={limitErrors} label={`حفظ حد ${users ? 'المستخدمين' : 'الفروع'}`}>
        <input type="hidden" name="tenantId" value={tenantId} />
        <input type="hidden" name="capabilityKey" value={limit.capability_key} />
        <input type="hidden" name="limitKey" value={limit.limit_key} />
        <LimitModeFields id={limit.capability_key} label={users ? 'الحد الأقصى للمستخدمين' : 'الحد الأقصى للفروع'}
          mode={limit.mode} value={limit.value} />
        <label htmlFor={`${limit.capability_key}-reason`}>سبب التغيير</label>
        <textarea id={`${limit.capability_key}-reason`} name="reason" required minLength={3} maxLength={500} rows={3} />
      </OperatorActionForm>
    </details>}
  </article>;
}

function stateLabel(state: string) { return state === 'active' ? 'نشطة' : state === 'suspended' ? 'معلّقة' : state === 'archived' ? 'مؤرشفة' : 'غير متاحة'; }
function stateText(state: string) {
  return Object.hasOwn(limitErrors, state) ? limitErrors[state] : 'نتيجة الإجراء غير مؤكدة. راجع الحدود الحالية قبل إجراء آخر.';
}
const limitErrors: Record<string, string> = {
    invalid: 'تحقق من بيانات الحد.', reason: 'أدخل سببًا من 3 إلى 500 حرف.', setup: 'إعداد Supabase غير مكتمل.',
    forbidden: 'لم تعد لديك صلاحية إدارة الحدود.', 'not-found': 'الشركة غير متاحة.',
    'future-conflict': 'يوجد حد مستقبلي؛ لم يتغير أي سجل.', conflict: 'توجد حدود فعّالة متعارضة؛ لم يتغير شيء.',
    failed: 'لم تتأكد نتيجة تحديث الحد. راجع الحدود الحالية قبل إجراء آخر.',
};
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title }: { title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من الصلاحية والاتصال ثم أعد المحاولة.</p><Link className="secondary-button" href="/operator/commercial">قائمة الشركات</Link></section></main>; }
