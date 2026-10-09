import { ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { NewEntityForm } from './NewEntityForm';

export const dynamic = 'force-dynamic';

export default async function NewLegalEntityPage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/entities-sites/new`)}`);
  const { data, error } = await supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data) ||
      (data as Record<string, unknown>).can_manage_legal_entities !== true) return <Status tenantId={tenantId} />;

  return <PageFrame footer="إدارة الشركة">
    <div className="workspace-form-page">
      <Link className="back-link" href={`/tenant/${tenantId}/entities-sites`}>العودة إلى الجهات والفروع</Link>
      <header className="workspace-page-heading"><div><p className="eyebrow">الجهات والفروع</p>
        <h1>إضافة جهة</h1><p>أدخل بيانات الجهة. ستتمكن من إضافة فروعها بعد حفظها.</p></div></header>
      <section className="workspace-form-panel" aria-label="بيانات الجهة">
        <NewEntityForm tenantId={tenantId} />
      </section>
    </div>
  </PageFrame>;
}

function Status({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>لا يمكن إضافة جهة</h1>
    <p className="intro">تحقق من صلاحياتك أو أعد المحاولة لاحقًا.</p>
    <ButtonLink variant="ghost" className="secondary-button" href={`/tenant/${tenantId}/entities-sites`}>العودة إلى الجهات والفروع</ButtonLink>
  </section></PageFrame>;
}
