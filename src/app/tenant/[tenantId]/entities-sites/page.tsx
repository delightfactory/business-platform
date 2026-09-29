import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame, TenantNavigation } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { manageLegalEntityAction } from './actions';

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
    ? `المواقع النشطة: ${Number(snapshot.site_usage ?? 0)} · بلا حد أقصى`
    : `المواقع النشطة: ${Number(snapshot.site_usage ?? 0)} من ${String(snapshot.site_limit?.value ?? 'غير متاح')}`;
  const feedback = feedbackForState(query.state);

  return (
    <PageFrame footer="إعداد الشركة">
      {feedback.success && <FeedbackToast key={crypto.randomUUID()} message={feedback.success} />}
      <TenantNavigation tenantId={tenantId} tenantName={snapshot.tenant_name} current="entities-sites" />
      <section className="work-card task-page" aria-labelledby="entities-sites-title">
        <p className="eyebrow">بيانات الشركة</p>
        <h1 id="entities-sites-title">الجهات القانونية والفروع</h1>
        <p className="intro">كل جهة قانونية لها اسم مستقل، ويمكن أن تتبعها فروع أو مواقع عمل متعددة.</p>
        <div className="usage-line"><strong>{siteLimitText}</strong></div>
        {feedback.error && <p className="form-message form-error" role="alert">{feedback.error}</p>}
        {feedback.info && <p className="form-message" role="status">{feedback.info}</p>}
        {!entities.some((entity) => entity.is_active && entity.is_default) &&
          <p className="form-message" role="status">لا توجد جهة افتراضية نشطة؛ اختر جهة نشطة من تفاصيلها.</p>}

        {entities.length === 0 ? <div className="empty-state">
          <h2>لا توجد جهات مسجلة</h2>
          <p>{canEntities ? 'أضف جهة قانونية للبدء بإعداد الفروع والمواقع.' : 'اطلب من مسؤول الجهات القانونية إضافة جهة.'}</p>
        </div> : <ul className="record-list">
          {entities.map((entity) => <li className="record-card" key={entity.id}>
            <div className="record-main">
              <div className="record-title-row">
                <h2>{entity.display_name}</h2>
                <span className={`entity-status ${entity.is_active ? 'is-active' : 'is-inactive'}`}>{entity.is_active ? 'نشط' : 'غير نشط'}</span>
              </div>
              {entity.legal_name && <p className="record-meta">الاسم القانوني: <bdi>{entity.legal_name}</bdi></p>}
              <p className="record-meta">{entity.is_default ? 'الجهة الافتراضية' : 'جهة قانونية'} · الفروع والمواقع النشطة: {Number(entity.active_site_count ?? 0)}</p>
            </div>
            <Link className="secondary-button" href={`/tenant/${tenantId}/entities-sites/${entity.id}`}>تفاصيل الجهة والفروع</Link>
          </li>)}
        </ul>}
        {canEntities && <details className="task-disclosure">
          <summary className="secondary-button">إضافة جهة قانونية</summary>
          <form action={manageLegalEntityAction} className="auth-form compact-form">
            <input type="hidden" name="tenantId" value={tenantId} />
            <input type="hidden" name="action" value="create" />
            <label htmlFor="entity-display-name">اسم الجهة داخل المنصة</label>
            <input id="entity-display-name" name="displayName" required maxLength={160} />
            <label htmlFor="entity-legal-name">الاسم القانوني (اختياري)</label>
            <input id="entity-legal-name" name="legalName" maxLength={200} />
            <p className="field-hint">اسم هذه الجهة مستقل عن اسم الشركة الظاهر في مساحة العمل.</p>
            <label htmlFor="entity-create-reason">سبب الإضافة</label>
            <input id="entity-create-reason" name="reason" required minLength={3} maxLength={500} />
            <button className="primary-button" type="submit">إضافة الجهة</button>
          </form>
        </details>}
      </section>
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
  return <PageFrame><TenantNavigation tenantId={tenantId} tenantName="الشركة" current="entities-sites" />
    <section className="auth-card"><h1>{title}</h1><p className="intro">{detail}</p>
      <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link></section></PageFrame>;
}
