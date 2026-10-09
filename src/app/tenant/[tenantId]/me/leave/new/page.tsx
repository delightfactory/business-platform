import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { isLeaveAccessSnapshot, isUuid } from '../form-rules';
import { PendingLink } from '../pending-link';
import { NewLeaveRequestForm } from './NewLeaveRequestForm';
import { Icon, PageHeader } from '@/components/ui';
import styles from '../leave.module.css';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;

export default async function NewLeaveRequestPage({ params }: { params: Params }) {
  const { tenantId } = await params;
  if (!isUuid(tenantId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/me/leave/new`)}`);
  let response;
  try {
    response = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  } catch {
    response = { data: null, error: { code: 'READ_UNAVAILABLE' } };
  }
  const { data, error } = response;
  if (error || !isLeaveAccessSnapshot(data)) {
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
    <div className={styles.requestSheet}>
      <PendingLink className="ui-button ui-button-ghost ui-button-md" href={`/tenant/${tenantId}/me/leave`}><Icon name="arrowRight" size={18}/>إجازاتي</PendingLink>
      <PageHeader title="طلب إجازة" description="اختر الفترة ثم نوع الإجازة. أرسل الطلب عندما تكتمل البيانات." />
      <section className={styles.requestSheetBody} aria-label="بيانات طلب الإجازة">
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
