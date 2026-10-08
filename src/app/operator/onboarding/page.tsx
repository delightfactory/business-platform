import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { operatorUuid, onboardingSnapshot } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { onboardTenantAction } from '@/app/operator/actions';
import { OperatorActionForm } from '@/app/operator/operator-action-form';
import { LimitFields } from './LimitFields';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type SearchParams = Promise<{ key?: string; state?: string }>;

export default async function OperatorOnboardingPage({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status title="إعداد الاتصال غير مكتمل" detail="أضف إعدادات Supabase العامة ثم أعد تشغيل التطبيق." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data: status, error: statusError } = await supabase.rpc('current_platform_operator_status');
  if (statusError) return <Status title="تعذر التحقق من الصلاحية" detail="أعد قراءة الصفحة للتحقق من مهمة إعداد الشركات." />;
  if (status !== 'active') return <Status title="لا توجد صلاحية تشغيل" detail="هذا الحساب لا يملك صلاحية مشغّل المنصة النشطة." />;
  const { data: canOnboard, error: capabilityError } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (capabilityError) return <Status title="تعذر التحقق من الصلاحية" detail="أعد قراءة الصفحة للتحقق من مهمة إعداد الشركات." />;
  if (!operatorPermission({ data: canOnboard, error: capabilityError })) return <Status title="إعداد الشركات غير متاح" detail="صلاحية إعداد الشركات غير ممنوحة لهذا المشغّل." />;
  if (params.key !== undefined && !operatorUuid(params.key)) return <Status title="مرجع الإعداد غير صالح" detail="تعذر مراجعة المحاولة بهذا الرابط. احتفظ بصفحة المحاولة الأصلية ولا تبدأ شركة جديدة لتجاوز نتيجتها غير المؤكدة." />;
  const key = params.key ?? null;
  const { data: result, error: resultError } = key ? await supabase.rpc('tenant_onboarding_result', { p_idempotency_key: key }) : { data: null, error: null };
  const resultUnavailable = Boolean(resultError) || (result !== null && !onboardingSnapshot(result));

  return (
    <main className="app-shell">
      <header className="topbar"><Link className="brand" href="/operator">مهام تشغيل المنصة</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب"><Link className="secondary-button" href="/operator">العودة للمهام</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></nav></header>
      <section className="work-card" aria-labelledby="onboard-title">
        <p className="eyebrow">إعداد الشركات</p><h1 id="onboard-title">إعداد شركة جديدة</h1>
        <p className="intro">أدخل بيانات الشركة ومسؤولًا لديه حساب موجود وبريد مؤكد.</p>
        <p><Link className="secondary-button" href="/operator/invitations">دعوة مسؤول جديد عبر البريد</Link></p>
        {params.state && !resultUnavailable && !result && <p className="form-message" role="alert">{stateMessage()}</p>}
        {resultUnavailable ? <div role="alert" className="form-message form-error"><p>تعذر التحقق من نتيجة إعداد الشركة. لا تبدأ طلبًا جديدًا قبل مراجعة المحاولة الأصلية.</p><Link className="primary-button" href={`/operator/onboarding?key=${encodeURIComponent(key ?? '')}`}>إعادة قراءة النتيجة</Link></div> : result ? <OnboardingResult result={result} /> : (<>
          {key && <p className="form-message" role="status">لم تُرجع قراءة هذا الحساب نتيجة محفوظة للمحاولة. هذا لا يؤكد نتيجة حساب آخر؛ يُستخدم المرجع نفسه عند إرسال النموذج.</p>}
          <OperatorActionForm className="auth-form onboarding-form" action={onboardTenantAction} errorMessages={onboardingErrors} label="إنشاء الشركة" pendingLabel="جارٍ إنشاء الشركة…">
            <input type="hidden" name="idempotencyKey" value={key ?? crypto.randomUUID()} />
            <label htmlFor="tenantName">اسم الشركة</label><input id="tenantName" name="tenantName" required maxLength={160} />
            <label htmlFor="entityName">الاسم القانوني للشركة (اختياري)</label>
            <input id="entityName" name="entityName" maxLength={160} placeholder="يُستخدم اسم الشركة إذا تُرك فارغًا" />
            <label htmlFor="siteName">اسم الفرع الأول</label><input id="siteName" name="siteName" required maxLength={160} />
            <label htmlFor="adminEmail">بريد مسؤول الشركة الحالي</label>
            <input id="adminEmail" name="adminEmail" type="email" autoComplete="email" required maxLength={254} />
            <p className="field-hint">يجب أن يكون الحساب موجودًا ومؤكد البريد. لا يتم إنشاء حساب جديد هنا.</p>
            <LimitFields kind="seats" label="حد المستخدمين" /><LimitFields kind="sites" label="حد الفروع" />
          </OperatorActionForm></>
        )}
      </section><footer className="footer">منصة الأعمال · تأسيس الشركات</footer>
    </main>
  );
}

function OnboardingResult({ result }: { result: Record<string, unknown> }) {
  const tenantId = typeof result.tenant_id === 'string' ? result.tenant_id : '';
  const tenantName = typeof result.tenant_name === 'string' ? result.tenant_name : 'الشركة';
  return <div className="success-panel" role="status"><h2>تم إعداد {tenantName}</h2>
    <p>الاسم القانوني: {String(result.legal_entity_name)} · الفرع الأول: {String(result.site_name)}</p>
    <p>المستخدمون: {limitText(result.seat_limit_mode, result.seat_limit)} (المستخدم حاليًا {String(result.seat_usage)})</p>
    <p>الفروع: {limitText(result.site_limit_mode, result.site_limit)} (المستخدم حاليًا {String(result.site_usage)})</p>
    {tenantId && <><p>أرسل رابط مساحة المسؤول إلى الحساب المُعيّن. يتطلب فتحه تسجيل الدخول بذلك الحساب:</p>
      <Link className="primary-button" href={`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}`)}`}>دخول مسؤول الشركة إلى المساحة</Link></>}
    <Link className="secondary-button" href="/operator/onboarding">إعداد شركة أخرى</Link>
  </div>;
}

function limitText(mode: unknown, value: unknown) { return mode === 'unlimited' ? 'غير محدود' : String(value); }
function stateMessage() {
  return 'الرابط وحده لا يؤكد نتيجة إعداد الشركة. راجع بيانات المحاولة والحالة الحالية قبل الإرسال.';
}
const onboardingErrors: Record<string, string> = {
    setup: 'إعداد Supabase غير مكتمل.', forbidden: 'لا تسمح صلاحيتك الحالية بإعداد الشركات.',
    admin: 'تعذر العثور على حساب مسؤول صالح. تحقق من البريد وتأكيد الحساب.',
    limit: 'يجب أن يكون كل حد رقمًا موجبًا أو غير محدود صراحةً.',
    conflict: 'مفتاح الطلب مستخدم ببيانات مختلفة. أعد تحميل الصفحة وحاول مجددًا.',
    failed: 'لم يكتمل إعداد الشركة. لم يتم حفظ عملية جزئية؛ راجع البيانات وحاول مجددًا.',
};
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
    <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form></header>
    <section className="auth-card" aria-labelledby="status-title"><p className="eyebrow">مساحة المشغّل</p>
      <h1 id="status-title">{title}</h1><p className="intro">{detail}</p></section>
    <footer className="footer">منصة الأعمال · تأسيس الشركات</footer></main>;
}
