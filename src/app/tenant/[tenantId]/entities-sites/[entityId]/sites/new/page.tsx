import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { SubmitButton } from '@/components/submit-button';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { manageSiteAction } from '../../../actions';

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
        <h1>إضافة فرع</h1><p>سيُضاف الفرع إلى جهة <bdi>{String(entity.display_name ?? '')}</bdi>.</p></div></header>
      <div className="workspace-page-summary"><strong>{limit?.mode === 'unlimited' ? `${usage} فرع نشط · بلا حد أقصى` : `${usage} من ${String(limit?.value ?? 'غير متاح')} فروع نشطة`}</strong></div>
      {full ? <p className="form-message capacity-message" role="status">اكتمل حد الفروع. عطّل فرعًا غير مستخدم أو اطلب رفع الحد.</p>
        : <section className="workspace-form-panel" aria-label="بيانات الفرع">
          <form action={manageSiteAction} className="auth-form compact-form">
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="legalEntityId" value={entityId} />
            <input type="hidden" name="returnEntityId" value={entityId} />
            <input type="hidden" name="action" value="create" />
            <label htmlFor="site-name">اسم الفرع أو الموقع</label>
            <input id="site-name" name="displayName" required maxLength={160} autoFocus />
            <label htmlFor="site-create-reason">سبب الإضافة</label>
            <input id="site-create-reason" name="reason" required minLength={3} maxLength={500} />
            <div className="workspace-form-actions"><SubmitButton label="إضافة الفرع" pendingLabel="جارٍ الإضافة…" />
              <Link className="secondary-button" href={`/tenant/${tenantId}/entities-sites/${entityId}`}>إلغاء</Link></div>
          </form>
        </section>}
    </div>
  </PageFrame>;
}

function Status({ tenantId, entityId }: { tenantId: string; entityId: string }) {
  return <PageFrame><section className="auth-card"><h1>إضافة الفرع غير متاحة</h1>
    <p className="intro">تحقق من حالة الجهة وصلاحيتك ثم أعد المحاولة.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}/entities-sites/${entityId}`}>العودة إلى الجهة</Link>
  </section></PageFrame>;
}
