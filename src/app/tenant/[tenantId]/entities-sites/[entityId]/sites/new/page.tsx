import { PageHeader, Panel } from '@/components/ui';
import { Message } from '@/components/ui';
import { ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { NewSiteForm } from './NewSiteForm';

export const dynamic = 'force-dynamic';

export default async function NewSitePage({ params }: { params: Promise<{ tenantId: string; entityId: string }> }) {
  const { tenantId, entityId } = await params;
  const isUuid = (value: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
  if (!isUuid(tenantId) || !isUuid(entityId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} entityId={entityId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/entities-sites/${entityId}/sites/new`)}`);
  const { data, error } = await supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status tenantId={tenantId} entityId={entityId} />;
  const snapshot = data as Record<string, unknown>;
  const entities = Array.isArray(snapshot.entities) ? snapshot.entities as Array<Record<string, unknown>> : [];
  const entity = entities.find((item) => item.id === entityId);
  if (snapshot.can_manage_sites !== true || !entity || entity.is_active !== true) return <Status tenantId={tenantId} entityId={entityId} />;
  const limit = snapshot.site_limit && typeof snapshot.site_limit === 'object' && !Array.isArray(snapshot.site_limit)
    ? snapshot.site_limit as Record<string, unknown> : null;
  const usage = Number(snapshot.site_usage ?? 0);
  const full = limit?.mode !== 'unlimited' && usage >= Number(limit?.value ?? 0);

  return <PageFrame footer="إدارة الشركة">
    <div className="workspace-form-page">
      <Link className="back-link" href={`/tenant/${tenantId}/entities-sites/${entityId}`}>العودة إلى فروع الجهة</Link>
      <header className="workspace-page-heading"><div><p className="eyebrow">الجهات والفروع</p>
        <PageHeader  title={<>إضافة فرع</>} /><p>سيُضاف الفرع إلى جهة <bdi>{String(entity.display_name ?? '')}</bdi>.</p></div></header>
      <div className="workspace-page-summary"><strong>{limit?.mode === 'unlimited' ? `${usage} فرع نشط · بلا حد أقصى` : `${usage} من ${String(limit?.value ?? 'غير متاح')} فروع نشطة`}</strong></div>
      {full ? <Message tone="info" className="capacity-message" role="status">اكتمل حد الفروع. عطّل فرعًا غير مستخدم أو اطلب رفع الحد.</Message>
        : <section className="workspace-form-panel" aria-label="بيانات الفرع">
          <NewSiteForm tenantId={tenantId} entityId={entityId} />
        </section>}
    </div>
  </PageFrame>;
}

function Status({ tenantId, entityId }: { tenantId: string; entityId: string }) {
  return <PageFrame><Panel className="auth-card"><PageHeader  title={<>إضافة الفرع غير متاحة</>} />
    <p className="intro">تحقق من حالة الجهة وصلاحيتك ثم أعد المحاولة.</p>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/entities-sites/${entityId}`}>العودة إلى الجهة</ButtonLink>
  </Panel></PageFrame>;
}
