import { ButtonLink } from '@/components/ui';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { RecordActionForm } from './RecordActionForm';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string; entityId: string }>;
type Query = Promise<{ state?: string }>;
type Site = { id: string; display_name: string; is_active: boolean; is_default: boolean };
type Entity = { id: string; display_name: string; legal_name: string | null; is_active: boolean; is_default: boolean; active_site_count: number; sites: Site[] };
type Snapshot = {
  tenant_id: string; tenant_name: string; site_limit: { mode: 'limited' | 'unlimited'; value: number | null };
  site_usage: number; can_manage_legal_entities: boolean; can_manage_sites: boolean; entities: Entity[];
};

export default async function LegalEntitySitesPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId, entityId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId) || !isUuid(entityId)) notFound();
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/entities-sites/${entityId}`)}`);
  const { data, error } = await supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    return <Status tenantId={tenantId} title="لا يمكن عرض التفاصيل" detail="تحتاج إلى صلاحية إدارة الجهات أو المواقع في هذه الشركة." />;
  }
  const snapshot = data as unknown as Snapshot;
  const entity = (snapshot.entities ?? []).find((item) => item.id === entityId);
  if (!entity) return <Status tenantId={tenantId} title="الجهة غير متاحة" detail="لم نعثر على هذه الجهة ضمن الشركة الحالية." />;
  const canEntities = snapshot.can_manage_legal_entities === true;
  const canSites = snapshot.can_manage_sites === true;
  const activeSites = Number(snapshot.site_usage ?? 0);
  const full = snapshot.site_limit?.mode !== 'unlimited' && activeSites >= Number(snapshot.site_limit?.value ?? 0);
  const feedback = feedbackForState(query.state);

  return (
    <PageFrame footer="بيانات الشركة">
      {feedback.success && <FeedbackToast key={crypto.randomUUID()} message={feedback.success} />}
      <section className="work-card task-page tenant-detail-header" aria-labelledby="entity-title">
        <Link className="back-link" href={`/tenant/${tenantId}/entities-sites`}>العودة إلى الجهات والفروع</Link>
        <p className="eyebrow">جهة قانونية</p>
        <div className="record-title-row"><h1 id="entity-title">{entity.display_name}</h1>
          <span className={`entity-status ${entity.is_active ? 'is-active' : 'is-inactive'}`}>{entity.is_active ? 'نشط' : 'غير نشط'}</span></div>
        {entity.legal_name && <p className="record-meta">الاسم القانوني: <bdi>{entity.legal_name}</bdi></p>}
        <p className="record-meta">{entity.is_default ? 'الجهة الأساسية للشركة' : 'جهة قانونية للشركة'} · الفروع النشطة: {Number(entity.active_site_count ?? 0)}</p>
        {feedback.error && <p className="form-message form-error" role="alert">{feedback.error}</p>}
        {feedback.info && <p className="form-message" role="status">{feedback.info}</p>}

        {canEntities && <div className="task-actions">
          <details className="task-disclosure">
            <summary className="secondary-button">تعديل بيانات الجهة</summary>
            <RecordActionForm tenantId={tenantId} entityId={entity.id} action="update" displayName={entity.display_name}
              legalName={entity.legal_name ?? ''} label="حفظ بيانات الجهة" />
          </details>
          {entity.is_active && !entity.is_default && <details className="task-disclosure">
            <summary className="secondary-button">جعلها الجهة الافتراضية</summary>
            <RecordActionForm tenantId={tenantId} entityId={entity.id} action="default" label="تأكيد اختيار الجهة الأساسية" />
          </details>}
          {entity.is_active && Number(entity.active_site_count ?? 0) > 0
            ? <p className="field-hint">عطّل المواقع التابعة أولًا قبل تعطيل الجهة.</p>
            : entity.is_active ? <details className="task-disclosure danger-disclosure">
              <summary className="secondary-button">تعطيل الجهة</summary>
              <RecordActionForm tenantId={tenantId} entityId={entity.id} action="deactivate" label="تأكيد تعطيل الجهة" />
            </details> : <details className="task-disclosure">
              <summary className="secondary-button">إعادة تفعيل الجهة</summary>
              <RecordActionForm tenantId={tenantId} entityId={entity.id} action="reactivate" label="تأكيد إعادة تفعيل الجهة" />
            </details>}
        </div>}
      </section>

      <section className="work-card task-page tenant-detail-sites" aria-labelledby="sites-title">
        <div className="record-title-row"><div><h2 id="sites-title">الفروع والمواقع</h2>
          <span className="record-meta">الفروع النشطة بالشركة: {snapshot.site_limit?.mode === 'unlimited'
            ? `${activeSites} نشط · بلا حد أقصى` : `${activeSites} من ${String(snapshot.site_limit?.value ?? 'غير متاح')}`}</span></div>
          {canSites && entity.is_active && <ButtonLink variant="solid" className="primary-button" href={`/tenant/${tenantId}/entities-sites/${entity.id}/sites/new`}>إضافة فرع</ButtonLink>}</div>
        <p className="field-hint">يُسجَّل كل فرع أو موقع عمل تحت الجهة القانونية التي يتبعها.</p>
        {!canSites && <p className="form-message" role="status">عرض التفاصيل يتطلب صلاحية إدارة المواقع.</p>}
        {canSites && entity.sites.length === 0 && <div className="empty-state"><p>لا توجد فروع أو مواقع مسجلة لهذه الجهة.</p></div>}
        {canSites && entity.sites.length > 0 && <ul className="record-list">
          {entity.sites.map((site) => <li className="record-card site-record" key={site.id}>
            <div className="record-main">
              <div className="record-title-row"><h3>{site.display_name}</h3>
                <span className={`entity-status ${site.is_active ? 'is-active' : 'is-inactive'}`}>{site.is_active ? 'نشط' : 'غير نشط'}</span></div>
              {site.is_default && <p className="record-meta">الموقع الافتراضي للشركة</p>}
            </div>
            <details className="task-disclosure site-actions-disclosure">
              <summary className="secondary-button" aria-label={`إجراءات فرع ${site.display_name}`}>إجراءات الفرع</summary>
              <div className="task-actions">
                <details className="task-disclosure"><summary className="secondary-button">تعديل الاسم</summary>
                <RecordActionForm tenantId={tenantId} entityId={entity.id} siteId={site.id} action="update"
                  displayName={site.display_name} label="حفظ اسم الفرع" /></details>
                {site.is_active && !site.is_default && <details className="task-disclosure"><summary className="secondary-button">جعله الفرع الأساسي</summary>
                  <RecordActionForm tenantId={tenantId} entityId={entity.id} siteId={site.id} action="default"
                    displayName={site.display_name} label="تأكيد اختيار الفرع الأساسي" />
                </details>}
                {site.is_active ? <details className="task-disclosure danger-disclosure"><summary className="secondary-button">تعطيل الفرع</summary>
                  <RecordActionForm tenantId={tenantId} entityId={entity.id} siteId={site.id} action="deactivate"
                    displayName={site.display_name} label="تأكيد تعطيل الفرع" />
                </details>
                  : !entity.is_active ? <p className="field-hint">أعد تفعيل الجهة أولًا لإعادة تفعيل هذا الموقع.</p>
                    : full ? <p className="field-hint">اكتمل الحد. عطّل موقعًا آخر أو اطلب رفع الحد قبل إعادة التفعيل.</p>
                      : <details className="task-disclosure"><summary className="secondary-button">إعادة تفعيل الفرع</summary>
                        <RecordActionForm tenantId={tenantId} entityId={entity.id} siteId={site.id} action="reactivate"
                          displayName={site.display_name} label="تأكيد إعادة تفعيل الفرع" />
                      </details>}
              </div>
            </details>
          </li>)}
        </ul>}
      </section>
    </PageFrame>
  );
}

function feedbackForState(state?: string) {
  const successes: Record<string, string> = {
    'entity-created': 'تمت إضافة الجهة القانونية.', 'entity-updated': 'تم تحديث بيانات الجهة.',
    'entity-default': 'تم تغيير الجهة الافتراضية.', 'entity-deactivate': 'تم تعطيل الجهة مع حفظ سجلها.',
    'entity-reactivate': 'تمت إعادة تفعيل الجهة.', 'site-created': 'تمت إضافة الموقع.',
    'site-updated': 'تم تحديث اسم الموقع.', 'site-default': 'تم تغيير الموقع الافتراضي.',
    'site-deactivate': 'تم تعطيل الموقع مع حفظ سجله.', 'site-reactivate': 'تمت إعادة تفعيل الموقع.',
  };
  if (!state) return { success: null, info: null, error: null };
  if (successes[state]) return { success: successes[state], info: null, error: null };
  if (state === 'entity-unchanged' || state === 'site-unchanged') {
    return { success: null, info: 'لم تتغير البيانات؛ لا حاجة لحفظ جديد.', error: null };
  }
  const errors: Record<string, string> = {
    forbidden: 'لا تملك الصلاحية اللازمة لهذا الإجراء.', setup: 'تعذر الاتصال بخدمة الحسابات. أعد المحاولة.',
    failed: 'تعذر حفظ التغيير. لم يُعتمد أي تغيير دون سجل التدقيق.', invalid: 'تحقق من المدخلات ثم أعد المحاولة.',
    reason: 'اكتب سببًا من 3 إلى 500 حرف.', name: 'اسم العرض مطلوب ويجب ألا يتجاوز 160 حرفًا.',
    capacity: 'اكتمل حد المواقع. عطّل موقعًا غير مستخدم أو اطلب رفع الحد.',
    limit: 'تعذر التحقق من حد المواقع الحالي؛ لم يُحفظ أي تغيير.',
    'entity-has-sites': 'عطّل المواقع النشطة التابعة لهذه الجهة أولًا.',
    inactive: 'أعد تفعيل الجهة أولًا ثم أعد المحاولة.', 'entity-unavailable': 'الجهة غير متاحة أو تتبع شركة أخرى.',
    'not-found': 'لم نعثر على السجل المطلوب. حدّث الصفحة ثم أعد المحاولة.',
    move: 'لا يمكن نقل الموقع إلى جهة أخرى بعد إنشائه.', unavailable: 'الشركة غير نشطة أو أن بياناتها غير متاحة.',
  };
  return { success: null, info: null, error: errors[state] ?? 'تعذر إتمام الإجراء. حدّث الصفحة ثم أعد المحاولة.' };
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, detail, tenantId }: { title: string; detail: string; tenantId: string }) {
  return <PageFrame>
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      <ButtonLink variant="ghost" className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink></section></PageFrame>;
}
