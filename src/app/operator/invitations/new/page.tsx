import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { InvitationForm } from './InvitationForm';

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
  if (error) return <Status detail="تعذر التحقق من صلاحية إعداد الشركات. أعد المحاولة لاحقًا." />;
  if (!operatorPermission({ data: capable, error })) return <Status />;

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
      <InvitationForm requestKey={crypto.randomUUID()} />
      <p className="workspace-alternate-path">هل لدى المسؤول حساب مؤكد بالفعل؟ <Link href="/operator/onboarding">إعداد الشركة لهذا الحساب</Link></p>
    </div>
  </PageFrame>;
}

function Status({ detail = 'تحقق من صلاحية إعداد الشركات أو أعد المحاولة لاحقًا.' }: { detail?: string } = {}) {
  return <PageFrame><section className="auth-card"><h1>الدعوة غير متاحة</h1>
    <p className="intro">{detail}</p>
    <Link className="secondary-button" href="/operator/invitations">العودة إلى الدعوات</Link>
  </section></PageFrame>;
}
