import { PageHeader, Panel } from '@/components/ui';
import { Message, RecordCard, Badge } from '@/components/ui';
import { ButtonLink } from '@/components/ui';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string }>;
type Entity = {
  id: string; display_name: string; legal_name: string | null; is_active: boolean;
  is_default: boolean; active_site_count: number;
};
type Snapshot = {
  tenant_id: string; tenant_name: string;
  site_limit: { mode: 'limited' | 'unlimited'; value: number | null };
  site_usage: number; can_manage_legal_entities: boolean; can_manage_sites: boolean; entities: Entity[];
};

export default async function TenantEntitiesSitesPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) return <Status tenantId={tenantId} title="الشركة غير متاحة" detail="تعذر العثور على الشركة المطلوبة." />;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/entities-sites`)}`);
  const { data, error } = await supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    return <Status tenantId={tenantId} title="لا يمكن عرض هذه الصفحة" detail="تحتاج إلى صلاحية إدارة الجهات أو المواقع في الشركة." />;
  }
  const snapshot = data as unknown as Snapshot;
  const entities = Array.isArray(snapshot.entities) ? snapshot.entities : [];
  const canEntities = snapshot.can_manage_legal_entities === true;
  const siteLimitText = snapshot.site_limit?.mode === 'unlimited'
    ? `الفروع النشطة: ${Number(snapshot.site_usage ?? 0)} · بلا حد أقصى`
    : `الفروع النشطة: ${Number(snapshot.site_usage ?? 0)} من ${String(snapshot.site_limit?.value ?? 'غير متاح')}`;
  const feedback = feedbackForState(query.state);

  return (
    <PageFrame footer="إعداد الشركة">
      {feedback.success && <FeedbackToast key={crypto.randomUUID()} message={feedback.success} />}
      <header className="workspace-page-heading">
        <div><p className="eyebrow">إدارة الشركة</p><PageHeader id="entities-sites-title" title={<>الجهات والفروع</>} />
          <p>رتّب الجهات التابعة للشركة، ثم أدر فروع كل جهة من صفحتها.</p></div>
        {canEntities && <ButtonLink variant="solid"  href={`/tenant/${tenantId}/entities-sites/new`}>إضافة جهة</ButtonLink>}
      </header>
      <div className="workspace-page-summary"><strong>{siteLimitText}</strong><span>الفروع المعطّلة محفوظة ولا تُحتسب ضمن الحد.</span></div>
      <Panel className="workspace-records-panel tenant-collection" aria-labelledby="entities-sites-title">
        {feedback.error && <Message tone="bad"  role="alert">{feedback.error}</Message>}
        {feedback.info && <Message tone="info"  role="status">{feedback.info}</Message>}
        {!entities.some((entity) => entity.is_active && entity.is_default) &&
          <Message tone="info"  role="status">لا توجد جهة افتراضية نشطة؛ اختر جهة نشطة من تفاصيلها.</Message>}

        {entities.length === 0 ? <div className="empty-state">
          <h2>لا توجد جهات مسجلة</h2>
          <p>{canEntities ? 'أضف الجهة الأولى، ثم أنشئ فروعها من صفحة التفاصيل.' : 'اطلب من مسؤول الشركة إضافة جهة.'}</p>
        </div> : <ul className="record-list">
          {entities.map((entity) => <RecordCard  key={entity.id}>
            <div className="record-main">
              <div className="record-title-row">
                <h2>{entity.display_name}</h2>
                <Badge className={` ${entity.is_active ? 'is-active' : 'is-inactive'}`}>{entity.is_active ? 'نشط' : 'غير نشط'}</Badge>
              </div>
              {entity.legal_name && <p className="record-meta">الاسم القانوني: <bdi>{entity.legal_name}</bdi></p>}
              <p className="record-meta">{entity.is_default ? 'الجهة الأساسية' : 'جهة قانونية'} · الفروع النشطة: {Number(entity.active_site_count ?? 0)}</p>
            </div>
            <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/entities-sites/${entity.id}`}>عرض التفاصيل</ButtonLink>
          </RecordCard>)}
        </ul>}
      </Panel>
    </PageFrame>
  );
}

function feedbackForState(state?: string) {
  const successes: Record<string, string> = {
    'entity-created': 'تمت إضافة الجهة القانونية.',
    'entity-updated': 'تم تحديث بيانات الجهة.',
    'entity-default': 'تم تغيير الجهة الافتراضية.',
    'entity-deactivate': 'تم تعطيل الجهة مع حفظ سجلها.',
    'entity-reactivate': 'تمت إعادة تفعيل الجهة.',
    'site-created': 'تمت إضافة الموقع.', 'site-updated': 'تم تحديث اسم الموقع.',
    'site-default': 'تم تغيير الموقع الافتراضي.', 'site-deactivate': 'تم تعطيل الموقع مع حفظ سجله.',
    'site-reactivate': 'تمت إعادة تفعيل الموقع.',
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
    inactive: 'أعد تفعيل الجهة أولًا ثم أعد المحاولة.',
    'entity-unavailable': 'الجهة غير متاحة أو تتبع شركة أخرى.',
    'not-found': 'لم نعثر على السجل المطلوب. حدّث الصفحة ثم أعد المحاولة.',
    move: 'لا يمكن نقل الموقع إلى جهة أخرى بعد إنشائه.',
    unavailable: 'الشركة غير نشطة أو أن بياناتها غير متاحة.',
  };
  return { success: null, info: null, error: errors[state] ?? 'تعذر إتمام الإجراء. حدّث الصفحة ثم أعد المحاولة.' };
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }

function Status({ title, detail, tenantId }: { title: string; detail: string; tenantId: string }) {
  return <PageFrame>
    <Panel className="auth-card"><PageHeader  title={<>{title}</>} /><p className="intro">{detail}</p>
      <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink></Panel></PageFrame>;
}
