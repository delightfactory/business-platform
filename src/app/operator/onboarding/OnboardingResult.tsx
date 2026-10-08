import Link from 'next/link';

export function OnboardingResult({ result }: { result: Record<string, unknown> }) {
  const tenantId = String(result.tenant_id), tenantName = String(result.tenant_name);
  return <div className="success-panel" role="status"><h2>تم إعداد <bdi>{tenantName}</bdi></h2>
    <p>الاسم القانوني: <bdi>{String(result.legal_entity_name)}</bdi> · الفرع الأول: <bdi>{String(result.site_name)}</bdi></p>
    <p>المستخدمون: {limitText(result.seat_limit_mode, result.seat_limit)} (المستخدم حاليًا {String(result.seat_usage)})</p>
    <p>الفروع: {limitText(result.site_limit_mode, result.site_limit)} (المستخدم حاليًا {String(result.site_usage)})</p>
    <p>أرسل رابط مساحة المسؤول إلى الحساب المُعيّن. يتطلب فتحه تسجيل الدخول بذلك الحساب:</p>
    <Link className="primary-button" href={`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}`)}`}>دخول مسؤول الشركة إلى المساحة</Link>
    {/* A new task after a confirmed receipt needs a fresh server-rendered form, even at the same URL. */}
    <form method="get" action="/operator/onboarding"><button className="secondary-button" type="submit">إعداد شركة أخرى</button></form>
  </div>;
}

function limitText(mode: unknown, value: unknown) { return mode === 'unlimited' ? 'غير محدود' : String(value); }
