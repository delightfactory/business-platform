import { PageHeader, Panel } from '@/components/ui';
import { Message } from '@/components/ui';
import { ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { operatorPermission } from '@/lib/operator-access';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { InvitationForm } from './InvitationForm';

export const dynamic = 'force-dynamic';

export default async function NewFirstAdminInvitationPage({ searchParams }: {
  searchParams: Promise<{ state?: string }>;
}) {
  const query = await searchParams;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect('/auth/login?next=%2Foperator%2Finvitations%2Fnew');
  const { data: capable, error } = await supabase.rpc('current_operator_can_onboard_tenants');
  if (error) return <Status detail="تعذر التحقق من صلاحية إعداد الشركات. أعد المحاولة لاحقًا." />;
  if (!operatorPermission({ data: capable, error })) return <Status />;

  return <PageFrame footer="تشغيل المنصة">
    <div className="workspace-form-page operator-invitation-form-page">
      <Link className="back-link" href="/operator/invitations">العودة إلى الدعوات</Link>
      <header className="workspace-page-heading"><div><p className="eyebrow">دعوات الشركات</p>
        <PageHeader  title={<>دعوة مسؤول لشركة جديدة</>} />
        <p>أدخل بيانات الشركة ومسؤولها الأول وحدود الاستخدام. ستُنشأ الشركة بعد قبول الدعوة.</p></div></header>
      {query.state && <Message tone="bad"  role="alert">{query.state === 'invalid'
        ? 'تحقق من البريد والبيانات والحدود، ثم حاول مجددًا.'
        : query.state === 'setup' ? 'خدمة الدعوات غير متاحة حاليًا. حاول لاحقًا.'
          : <>الرابط وحده لا يؤكد نتيجة إنشاء الدعوة أو إرسالها. <Link href="/operator/invitations">راجع الدعوات الحالية</Link> قبل إنشاء دعوة أخرى.</>}</Message>}
      <InvitationForm requestKey={crypto.randomUUID()} />
      <p className="workspace-alternate-path">هل لدى المسؤول حساب مؤكد بالفعل؟ <Link href="/operator/onboarding">إعداد الشركة لهذا الحساب</Link></p>
    </div>
  </PageFrame>;
}

function Status({ detail = 'تحقق من صلاحية إعداد الشركات أو أعد المحاولة لاحقًا.' }: { detail?: string } = {}) {
  return <PageFrame><Panel className="auth-card"><PageHeader  title={<>الدعوة غير متاحة</>} />
    <p className="intro">{detail}</p>
    <ButtonLink variant="ghost"  href="/operator/invitations">العودة إلى الدعوات</ButtonLink>
  </Panel></PageFrame>;
}
