import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { InviteMemberForm } from './InviteMemberForm';

export const dynamic = 'force-dynamic';

export default async function InviteMemberPage({ params, searchParams }: { params: Promise<{ tenantId: string }>;
  searchParams: Promise<{ employeeId?: string }> }) {
  const { tenantId } = await params;
  const { employeeId: employeeIdParam } = await searchParams;
  const employeeId = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(employeeIdParam ?? '')
    ? employeeIdParam! : '';
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/users/invite`)}`);
  const { data, error } = await supabase.rpc('tenant_member_access_list', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status tenantId={tenantId} />;
  const result = data as Record<string, unknown>;
  const limit = result.seat_limit && typeof result.seat_limit === 'object' && !Array.isArray(result.seat_limit)
    ? result.seat_limit as Record<string, unknown> : null;
  const used = Number(result.seat_usage ?? 0);

  return <PageFrame footer="إدارة الشركة">
    <div className="workspace-form-page">
      <Link className="back-link" href={employeeId ? `/tenant/${tenantId}/people/${employeeId}` : `/tenant/${tenantId}/users`}>
        {employeeId ? 'العودة إلى ملف الموظف' : 'العودة إلى المستخدمين'}</Link>
      <header className="workspace-page-heading"><div><p className="eyebrow">المستخدمون والدعوات</p>
        <h1>دعوة عضو</h1><p>أرسل دعوة إلى بريد الشخص الذي سينضم لفريق الشركة.</p></div></header>
      <div className="workspace-page-summary"><strong>المستخدمون النشطون: {limit?.mode === 'unlimited' ? `${used} · بلا حد أقصى` : `${used} من ${String(limit?.value ?? 'غير متاح')}`}</strong>
        <span>لا يُحجز مقعد قبل قبول الدعوة.</span></div>
      <section className="workspace-form-panel" aria-label="بيانات الدعوة">
        <InviteMemberForm tenantId={tenantId} employeeId={employeeId} idempotencyKey={crypto.randomUUID()} />
      </section>
    </div>
  </PageFrame>;
}

function Status({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>لا يمكن إرسال الدعوة</h1>
    <p className="intro">تحقق من صلاحية إدارة المستخدمين أو أعد المحاولة لاحقًا.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
  </section></PageFrame>;
}
