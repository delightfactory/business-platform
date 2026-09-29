import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { signOutAction } from '@/app/auth/actions';
import { onboardTenantAction } from '@/app/operator/actions';

export const dynamic = 'force-dynamic';

type SearchParams = Promise<{ key?: string; state?: string }>;

export default async function OperatorPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة إلى ملف البيئة ثم أعد تشغيل التطبيق." />;

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  if (userError) return <Status title="تعذر التحقق من الجلسة" detail="حاول تسجيل الدخول مرة أخرى." />;

  const { data: operatorStatus, error: statusError } = await supabase.rpc('current_platform_operator_status');
  if (statusError) return <Status title="تعذر التحقق من الصلاحية" detail="تعذر التحقق من صلاحية تشغيل المنصة. حاول لاحقًا." />;
  if (operatorStatus !== 'active') return <Status title="لا توجد صلاحية تشغيل" detail="هذا الحساب لا يملك صلاحية مشغّل المنصة النشطة." />;

  const { data: canOnboard, error: capabilityError } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (capabilityError || !canOnboard) {
    return <Status title="إعداد الشركات غير متاح لهذا الحساب" detail="صلاحية إعداد الشركات غير ممنوحة لهذا المشغّل." />;
  }

  const key = params.key && /^[0-9a-f-]{36}$/i.test(params.key) ? params.key : null;
  const { data: result } = key
    ? await supabase.rpc('tenant_onboarding_result', { p_idempotency_key: key })
    : { data: null };

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}>
          <button className="secondary-button" type="submit">تسجيل الخروج</button>
        </form>
      </header>
      <section className="work-card" aria-labelledby="onboard-title">
        <p className="eyebrow">إعداد الشركات</p>
        <h1 id="onboard-title">إعداد شركة جديدة</h1>
        <p className="intro">أدخل بيانات الشركة ومسؤولًا لديه حساب موجود وبريد مؤكد. إرسال الدعوات سيضاف لاحقًا.</p>
        {params.state && <p className="form-message" role="alert">{stateMessage(params.state)}</p>}
        {result ? <OnboardingResult result={result} /> : (
          <form className="auth-form onboarding-form" action={onboardTenantAction}>
            <input type="hidden" name="idempotencyKey" value={key ?? crypto.randomUUID()} />
            <label htmlFor="tenantName">اسم الشركة</label>
            <input id="tenantName" name="tenantName" required maxLength={160} />
            <label htmlFor="entityName">اسم الكيان القانوني الافتراضي (اختياري)</label>
            <input id="entityName" name="entityName" maxLength={160} placeholder="يُستخدم اسم الشركة إذا تُرك فارغًا" />
            <label htmlFor="siteName">اسم الموقع الافتراضي</label>
            <input id="siteName" name="siteName" required maxLength={160} />
            <label htmlFor="adminEmail">بريد مسؤول الشركة الحالي</label>
            <input id="adminEmail" name="adminEmail" type="email" autoComplete="email" required maxLength={254} />
            <p className="field-hint">يجب أن يكون الحساب موجودًا ومؤكد البريد. لا يتم إنشاء حساب جديد هنا.</p>
            <LimitFields kind="seats" label="حد المستخدمين" />
            <LimitFields kind="sites" label="حد المواقع" />
            <button className="primary-button" type="submit">إنشاء الشركة</button>
          </form>
        )}
      </section>
      <footer className="footer">منصة الأعمال · تأسيس الشركات</footer>
    </main>
  );
}

function LimitFields({ kind, label }: { kind: 'seats' | 'sites'; label: string }) {
  return (
    <fieldset className="limit-fields">
      <legend>{label}</legend>
      <label htmlFor={`${kind}Mode`}>نوع الحد</label>
      <select id={`${kind}Mode`} name={`${kind}Mode`} defaultValue="limited">
        <option value="limited">عدد محدد</option>
        <option value="unlimited">غير محدود</option>
      </select>
      <label htmlFor={`${kind}Limit`}>العدد عند اختيار حد محدد</label>
      <input id={`${kind}Limit`} name={`${kind}Limit`} type="number" min="1" step="1" defaultValue="10" />
    </fieldset>
  );
}

function OnboardingResult({ result }: { result: Record<string, unknown> }) {
  const tenantId = typeof result.tenant_id === 'string' ? result.tenant_id : '';
  const tenantName = typeof result.tenant_name === 'string' ? result.tenant_name : 'الشركة';
  return (
    <div className="success-panel" role="status">
      <h2>تم إعداد {tenantName}</h2>
      <p>الكيان الافتراضي: {String(result.legal_entity_name)} · الموقع الافتراضي: {String(result.site_name)}</p>
      <p>المستخدمون: {limitText(result.seat_limit_mode, result.seat_limit)} (المستخدم حاليًا {String(result.seat_usage)})</p>
      <p>المواقع: {limitText(result.site_limit_mode, result.site_limit)} (المستخدم حاليًا {String(result.site_usage)})</p>
      {tenantId && (
        <>
          <p>أرسل رابط مساحة المسؤول إلى الحساب المُعيّن. يتطلب فتحه تسجيل الدخول بذلك الحساب:</p>
          <Link className="primary-button" href={`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}`)}`}>
            دخول مسؤول الشركة إلى المساحة
          </Link>
        </>
      )}
      <Link className="secondary-button" href="/operator">إعداد شركة أخرى</Link>
    </div>
  );
}

function limitText(mode: unknown, value: unknown) {
  return mode === 'unlimited' ? 'غير محدود' : String(value);
}

function stateMessage(state: string) {
  const messages: Record<string, string> = {
    setup: 'إعداد Supabase غير مكتمل.',
    forbidden: 'لا تسمح صلاحيتك الحالية بإعداد الشركات.',
    admin: 'تعذر العثور على حساب مسؤول صالح. تحقق من البريد وتأكيد الحساب.',
    limit: 'يجب أن يكون كل حد رقمًا موجبًا أو غير محدود صراحةً.',
    conflict: 'مفتاح الطلب مستخدم ببيانات مختلفة. أعد تحميل الصفحة وحاول مجددًا.',
    failed: 'لم يكتمل إعداد الشركة. لم يتم حفظ عملية جزئية؛ راجع البيانات وحاول مجددًا.',
  };
  return messages[state] ?? 'تعذر إتمام الطلب.';
}

function Status({ title, detail }: { title: string; detail: string }) {
  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href="/">منصة الأعمال</Link>
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="auth-card" aria-labelledby="status-title">
        <p className="eyebrow">مساحة المشغّل</p>
        <h1 id="status-title">{title}</h1>
        <p className="intro">{detail}</p>
      </section>
      <footer className="footer">منصة الأعمال · تأسيس الشركات</footer>
    </main>
  );
}
