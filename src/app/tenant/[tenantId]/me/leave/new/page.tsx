import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isObject, isUuid } from '../form-rules';
import { PendingLink } from '../pending-link';
import { NewLeaveRequestForm } from './NewLeaveRequestForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;

export default async function NewLeaveRequestPage({ params }: { params: Params }) {
  const { tenantId } = await params;
  if (!isUuid(tenantId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/leave/new`)}`);
  const { data, error } = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  if (error || !isObject(data)) {
    const forbidden = error?.code === '42501';
    return <Status tenantId={tenantId} retry={!forbidden}
      title={forbidden ? 'الخدمة الذاتية غير متاحة لهذا الحساب' : 'تعذر فتح طلب الإجازة'}
      detail={forbidden ? 'لا يملك حسابك أي صلاحية لخدمة الإجازات في الشركة. راجع إدارة الموارد البشرية.'
        : 'حدث خطأ أثناء التحقق من صلاحيتك. أعد المحاولة.'} />;
  }
  if (data.self_access !== true) {
    return <Status tenantId={tenantId} retry={false} title="عرض إجازاتك غير متاح لهذا الحساب"
      detail="لا يملك حسابك صلاحية عرض بيانات إجازاته الذاتية. راجع إدارة الموارد البشرية." />;
  }
  if (data.self_can_request !== true) {
    return <Status tenantId={tenantId} retry={false} title="طلب إجازة غير متاح لهذا الحساب"
      detail="يمكن لحسابك مراجعة إجازاته وأرصدته، لكن إنشاء طلبات جديدة غير مفعّل له حاليًا. راجع إدارة الموارد البشرية." />;
  }
  if (data.new_work_enabled !== true) {
    return <Status tenantId={tenantId} retry={false} title="إنشاء طلبات الإجازة غير متاح حاليًا"
      detail="يمكنك مراجعة سجل طلباتك وأرصدتك من صفحة إجازاتي. تواصل مع إدارة الموارد البشرية لإعادة تفعيل إنشاء الطلبات." />;
  }

  return <PageFrame footer="الخدمة الذاتية">
    <div className="workspace-form-page">
      <PendingLink className="back-link" href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</PendingLink>
      <header className="workspace-page-heading"><div><p className="eyebrow">الخدمة الذاتية</p>
        <h1>طلب إجازة جديد</h1>
        <p>اختر تاريخين أولًا لعرض أنواع الإجازة المتاحة في هذه الفترة، ثم أرسل الطلب.</p></div></header>
      <section className="workspace-form-panel" aria-label="بيانات طلب الإجازة">
        <NewLeaveRequestForm tenantId={tenantId} idempotencyKey={crypto.randomUUID()} />
      </section>
    </div>
  </PageFrame>;
}

function Status({ tenantId, title, detail, retry = false }: { tenantId: string; title: string; detail: string; retry?: boolean }) {
  return <PageFrame footer="الخدمة الذاتية">
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      {retry && <Link className="secondary-button" href={`/tenant/${tenantId}/me/leave/new`}>إعادة المحاولة</Link>}
      <Link className="secondary-button" href={`/tenant/${tenantId}/me/leave`}>العودة إلى إجازاتي</Link>
    </section>
  </PageFrame>;
}
