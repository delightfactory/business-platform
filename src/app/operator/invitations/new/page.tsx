import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { SubmitButton } from '@/components/submit-button';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { createInvitationAction } from '../actions';

export const dynamic = 'force-dynamic';

export default async function NewFirstAdminInvitationPage({ searchParams }: {
  searchParams: Promise<{ state?: string }>;
}) {
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?next=%2Foperator%2Finvitations%2Fnew');
  const { data: capable, error } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (error || !capable) return <Status />;

  return <PageFrame footer="تشغيل المنصة">
    <div className="workspace-form-page operator-invitation-form-page">
      <Link className="back-link" href="/operator/invitations">العودة إلى الدعوات</Link>
      <header className="workspace-page-heading"><div><p className="eyebrow">دعوات الشركات</p>
        <h1>دعوة مسؤول لشركة جديدة</h1>
        <p>أدخل بيانات الشركة ومسؤولها الأول وحدود الاستخدام. ستُنشأ الشركة بعد قبول الدعوة.</p></div></header>
      {query.state && <p className="form-message form-error" role="alert">{query.state === 'invalid'
        ? 'تحقق من البريد والبيانات والحدود، ثم حاول مجددًا.'
        : query.state === 'setup' ? 'خدمة الدعوات غير متاحة حاليًا. حاول لاحقًا.'
          : 'تعذر إرسال الدعوة. تحقق من صلاحيتك والبيانات ثم حاول مجددًا.'}</p>}
      <section className="workspace-form-panel" aria-label="بيانات دعوة المسؤول الأول">
        <form className="auth-form onboarding-form" action={createInvitationAction}>
          <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
          <h2>الشركة</h2>
          <label htmlFor="tenantName">اسم الشركة</label>
          <input id="tenantName" name="tenantName" required maxLength={160} autoFocus />
          <label htmlFor="entityName">اسم الجهة القانونية (اختياري)</label>
          <input id="entityName" name="entityName" maxLength={160} placeholder="يُستخدم اسم الشركة إذا تُرك فارغًا" />
          <label htmlFor="siteName">اسم الفرع الرئيسي</label>
          <input id="siteName" name="siteName" defaultValue="المقر الرئيسي" required maxLength={160} />
          <h2>المسؤول الأول</h2>
          <label htmlFor="targetEmail">البريد الإلكتروني</label>
          <input id="targetEmail" name="targetEmail" type="email" autoComplete="email" required maxLength={254} />
          <h2>حدود الاستخدام الأولية</h2>
          <LimitFields kind="seats" label="المستخدمون" />
          <LimitFields kind="sites" label="الفروع" />
          <div className="workspace-form-actions"><SubmitButton label="إرسال الدعوة" pendingLabel="جارٍ الإرسال…" />
            <Link className="secondary-button" href="/operator/invitations">إلغاء</Link></div>
        </form>
      </section>
      <p className="workspace-alternate-path">هل لدى المسؤول حساب مؤكد بالفعل؟ <Link href="/operator/onboarding">إعداد الشركة لهذا الحساب</Link></p>
    </div>
  </PageFrame>;
}

function LimitFields({ kind, label }: { kind: 'seats' | 'sites'; label: string }) {
  return <fieldset className="limit-fields">
    <legend>{label}</legend>
    <label htmlFor={`${kind}Mode`}>نوع الحد</label>
    <select id={`${kind}Mode`} name={`${kind}Mode`} defaultValue="limited">
      <option value="limited">عدد محدد</option><option value="unlimited">غير محدود</option>
    </select>
    <label htmlFor={`${kind}Limit`}>العدد عند اختيار حد محدد</label>
    <input id={`${kind}Limit`} name={`${kind}Limit`} type="number" min="1" step="1" defaultValue="10" />
  </fieldset>;
}

function Status() {
  return <PageFrame><section className="auth-card"><h1>الدعوة غير متاحة</h1>
    <p className="intro">تحقق من صلاحية إعداد الشركات أو أعد المحاولة لاحقًا.</p>
    <Link className="secondary-button" href="/operator/invitations">العودة إلى الدعوات</Link>
  </section></PageFrame>;
}
