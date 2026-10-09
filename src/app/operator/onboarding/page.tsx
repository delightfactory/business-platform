import { PageHeader } from '@/components/ui';
import { Panel, Message } from '@/components/ui';
import { Button, ButtonLink, Input } from '@/components/ui';
import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { operatorUuid, onboardingSnapshot } from '@/lib/operator-read';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { OnboardingForm } from './OnboardingForm';
import { OnboardingResult } from './OnboardingResult';
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
        <nav className="topbar-actions" aria-label="إجراءات الحساب"><ButtonLink variant="ghost"  href="/operator">العودة للمهام</ButtonLink>
          <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form></nav></header>
      <Panel  aria-labelledby="onboard-title">
        <p className="eyebrow">إعداد الشركات</p><PageHeader id="onboard-title" title={<>إعداد شركة جديدة</>} />
        <p className="intro">أدخل بيانات الشركة ومسؤولًا لديه حساب موجود وبريد مؤكد.</p>
        <p><ButtonLink variant="ghost"  href="/operator/invitations">دعوة مسؤول جديد عبر البريد</ButtonLink></p>
        {params.state && !resultUnavailable && !result && <Message tone="info"  role="alert">{stateMessage()}</Message>}
        {resultUnavailable ? <Message as="div" tone="bad" role="alert" ><p>تعذر التحقق من نتيجة إعداد الشركة. لا تبدأ طلبًا جديدًا قبل مراجعة المحاولة الأصلية.</p><ButtonLink variant="solid"  href={`/operator/onboarding?key=${encodeURIComponent(key ?? '')}`}>إعادة قراءة النتيجة</ButtonLink></Message> : result ? <OnboardingResult result={result} /> : (<>
          {key && <Message tone="info"  role="status">لم تُرجع قراءة هذا الحساب نتيجة محفوظة للمحاولة. هذا لا يؤكد نتيجة حساب آخر؛ يُستخدم المرجع نفسه عند إرسال النموذج.</Message>}
          <OnboardingForm actorId={user.id} requestKey={key ?? crypto.randomUUID()}>
            <fieldset className="ui-form-section"><legend>الشركة والفرع</legend><label htmlFor="tenantName">اسم الشركة</label><Input id="tenantName" name="tenantName" required maxLength={160} />
            <label htmlFor="entityName">الاسم القانوني للشركة (اختياري)</label>
            <Input id="entityName" name="entityName" maxLength={160} placeholder="يُستخدم اسم الشركة إذا تُرك فارغًا" />
            <label htmlFor="siteName">اسم الفرع الأول</label><Input id="siteName" name="siteName" required maxLength={160} />
            </fieldset><fieldset className="ui-form-section"><legend>المسؤول وحدود الاستخدام</legend><label htmlFor="adminEmail">بريد مسؤول الشركة الحالي</label>
            <Input id="adminEmail" name="adminEmail" type="email" dir="ltr" autoComplete="email" required maxLength={254} />
            <p className="field-hint">يجب أن يكون الحساب موجودًا ومؤكد البريد. لا يتم إنشاء حساب جديد هنا.</p>
            <LimitFields kind="seats" label="حد المستخدمين" /><LimitFields kind="sites" label="حد الفروع" /></fieldset>
          </OnboardingForm></>
        )}
      </Panel>
    </main>
  );
}

function stateMessage() {
  return 'الرابط وحده لا يؤكد نتيجة إعداد الشركة. راجع بيانات المحاولة والحالة الحالية قبل الإرسال.';
}
function Status({ title, detail }: { title: string; detail: string }) {
  return <main className="app-shell"><header className="topbar"><Link className="brand" href="/">منصة الأعمال</Link>
    <form action={signOutAction}><Button variant="ghost"  type="submit">تسجيل الخروج</Button></form></header>
    <Panel className="auth-card" aria-labelledby="status-title"><p className="eyebrow">مساحة المشغّل</p>
      <PageHeader id="status-title" title={<>{title}</>} /><p className="intro">{detail}</p></Panel>
    </main>;
}
