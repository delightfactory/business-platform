import Link from 'next/link';
import { redirect } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { manageLegalEntityAction, manageSiteAction } from './actions';

export const dynamic = 'force-dynamic';

type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string }>;
type Site = { id: string; display_name: string; is_active: boolean; is_default: boolean };
type LegalEntity = {
  id: string;
  display_name: string;
  legal_name: string | null;
  is_active: boolean;
  is_default: boolean;
  active_site_count: number;
  sites: Site[];
};
type Snapshot = {
  tenant_id: string;
  tenant_name: string;
  site_limit: { mode: 'limited' | 'unlimited'; value: number | null };
  site_usage: number;
  can_manage_legal_entities: boolean;
  can_manage_sites: boolean;
  entities: LegalEntity[];
};

export default async function TenantEntitiesSitesPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) return <Status title="المساحة غير متاحة" detail="تعذر العثور على الشركة المطلوبة." />;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="إعداد الاتصال غير مكتمل" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}`)}`);
  const { data, error } = await supabase.rpc('tenant_entities_sites_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) {
    return <Status tenantId={tenantId} title="المساحة غير متاحة" detail="لا تملك هذه العضوية صلاحية الاطلاع على الكيانات والمواقع، أو أن الشركة غير متاحة." />;
  }
  const snapshot = data as unknown as Snapshot;
  const entities = Array.isArray(snapshot.entities) ? snapshot.entities : [];
  const activeSites = Number(snapshot.site_usage ?? 0);
  const unlimited = snapshot.site_limit?.mode === 'unlimited';
  const limit = Number(snapshot.site_limit?.value ?? 0);
  const full = !unlimited && activeSites >= limit;
  const hasDefaultEntity = entities.some((entity) => entity.is_active && entity.is_default);
  const hasDefaultSite = entities.some((entity) => entity.sites.some((site) => site.is_active && site.is_default));
  const canEntities = snapshot.can_manage_legal_entities === true;
  const canSites = snapshot.can_manage_sites === true;
  const activeEntityCount = entities.filter((entity) => entity.is_active).length;

  return (
    <main className="app-shell">
      <header className="topbar">
        <Link className="brand" href={`/tenant/${tenantId}`}>{snapshot.tenant_name}</Link>
        <nav className="topbar-actions" aria-label="إجراءات الحساب">
          <Link className="secondary-button" href={`/tenant/${tenantId}`}>مساحة الشركة</Link>
          <Link className="secondary-button" href="/tenant/select">تبديل الشركة</Link>
          <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
        </nav>
      </header>

      <section className="work-card" aria-labelledby="entities-sites-title">
        <p className="eyebrow">إعداد مساحة الشركة</p>
        <h1 id="entities-sites-title">الكيانات والمواقع</h1>
        <p className="intro">تُستخدم بيانات الكيانات والمواقع المشتركة في مساحة الشركة. لا يؤدي تغيير الاسم هنا إلى تغيير اسم الشركة.</p>
        <div className="success-panel" aria-label="استخدام المواقع">
          <strong>{unlimited ? `${activeSites} موقعًا نشطًا · بلا حد أقصى` : `${activeSites} من ${limit} مواقع نشطة`}</strong>
          <span>يُحتسب الموقع النشط فقط، وتُحفظ بيانات المواقع المعطلة.</span>
        </div>
        {query.state && <p className="form-message" role="status">{statusMessage(query.state)}</p>}
        {!hasDefaultEntity && <p className="form-message" role="status">لا يوجد كيان افتراضي نشط. أنشئ كيانًا أو اختر كيانًا نشطًا واجعله افتراضيًا.</p>}
        {!hasDefaultSite && <p className="form-message" role="status">لا يوجد موقع افتراضي نشط. أنشئ موقعًا أو اختر موقعًا نشطًا واجعله افتراضيًا.</p>}
        {full && <p className="form-message capacity-message" role="status">اكتمل حد المواقع الحالي. عطّل موقعًا غير مستخدم أو تواصل مع مسؤول اشتراك الشركة أو دعم المنصة لرفع الحد.</p>}
        {canSites && !canEntities && activeEntityCount === 0 && <p className="form-message" role="status">لا يوجد كيان نشط لربط موقع به. اطلب من مسؤول الكيانات إعادة تفعيل كيان أو إضافة كيان جديد.</p>}
      </section>

      {canEntities && <section className="work-card" aria-labelledby="new-entity-title">
        <h2 id="new-entity-title">إضافة كيان</h2>
        <p className="field-hint">اسم العرض للاستخدام داخل المنصة. الاسم القانوني اختياري ومستقل عنه.</p>
        <form action={manageLegalEntityAction} className="auth-form entities-sites-form">
          <input type="hidden" name="tenantId" value={tenantId} />
          <input type="hidden" name="action" value="create" />
          <label htmlFor="entity-display-name">اسم العرض</label>
          <input id="entity-display-name" name="displayName" required maxLength={160} />
          <label htmlFor="entity-legal-name">الاسم القانوني (اختياري)</label>
          <input id="entity-legal-name" name="legalName" maxLength={200} />
          <label htmlFor="entity-create-reason">سبب الإضافة</label>
          <input id="entity-create-reason" name="reason" required minLength={3} maxLength={500} />
          <button className="primary-button" type="submit">إضافة الكيان</button>
        </form>
      </section>}

      {entities.length === 0 ? <section className="work-card"><h2>لا توجد كيانات</h2>
        <p className="intro">{canEntities ? 'أضف كيانًا لبدء إعداد مواقع الشركة.' : 'اطلب من مسؤول الكيانات إضافة كيان لبدء إعداد المواقع.'}</p>
        <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
      </section> : entities.map((entity) => {
        const activeEntitySites = Number(entity.active_site_count ?? entity.sites.filter((site) => site.is_active).length);
        return (
          <section className="work-card entity-card" key={entity.id} aria-labelledby={`entity-${entity.id}`}>
            <div className="entity-heading">
              <div>
                <p className="eyebrow">{entity.is_default ? 'الكيان الافتراضي' : 'كيان الشركة'}</p>
                <h2 id={`entity-${entity.id}`}>{entity.display_name}</h2>
                {entity.legal_name && <p className="field-hint">الاسم القانوني: <bdi>{entity.legal_name}</bdi></p>}
              </div>
              <span className={`entity-status ${entity.is_active ? 'is-active' : 'is-inactive'}`}>{entity.is_active ? 'نشط' : 'غير نشط'}</span>
            </div>

            {canEntities && <div className="entity-actions">
              <details className="entity-action-panel">
                <summary className="secondary-button">تعديل الأسماء</summary>
                <form action={manageLegalEntityAction} className="auth-form compact-form">
                  <input type="hidden" name="tenantId" value={tenantId} />
                  <input type="hidden" name="entityId" value={entity.id} />
                  <input type="hidden" name="action" value="update" />
                  <label htmlFor={`entity-name-${entity.id}`}>اسم العرض</label>
                  <input id={`entity-name-${entity.id}`} name="displayName" defaultValue={entity.display_name} required maxLength={160} />
                  <label htmlFor={`entity-legal-${entity.id}`}>الاسم القانوني (اختياري)</label>
                  <input id={`entity-legal-${entity.id}`} name="legalName" defaultValue={entity.legal_name ?? ''} maxLength={200} />
                  <label htmlFor={`entity-update-reason-${entity.id}`}>سبب التعديل</label>
                  <input id={`entity-update-reason-${entity.id}`} name="reason" required minLength={3} maxLength={500} />
                  <button className="primary-button" type="submit">حفظ الأسماء</button>
                </form>
              </details>
              {entity.is_active && !entity.is_default && <details className="entity-action-panel">
                <summary className="secondary-button">اختيار كافتراضي</summary>
                <form action={manageLegalEntityAction} className="auth-form compact-form">
                  <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="entityId" value={entity.id} />
                  <input type="hidden" name="action" value="default" />
                  <p className="field-hint">سيصبح «{entity.display_name}» الكيان الافتراضي للشركة.</p>
                  <label htmlFor={`entity-default-reason-${entity.id}`}>سبب التغيير</label>
                  <input id={`entity-default-reason-${entity.id}`} name="reason" required minLength={3} maxLength={500} />
                  <button className="primary-button" type="submit">تأكيد الاختيار</button>
                </form>
              </details>}
              {entity.is_active ? activeEntitySites === 0 ? <details className="entity-action-panel">
                <summary className="secondary-button">تعطيل الكيان</summary>
                <form action={manageLegalEntityAction} className="auth-form compact-form">
                  <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="entityId" value={entity.id} />
                  <input type="hidden" name="action" value="deactivate" />
                  <p className="field-hint">سيبقى سجل الكيان محفوظًا، ويمكن إعادة تفعيله لاحقًا.</p>
                  <label htmlFor={`entity-deactivate-reason-${entity.id}`}>سبب التعطيل</label>
                  <input id={`entity-deactivate-reason-${entity.id}`} name="reason" required minLength={3} maxLength={500} />
                  <button className="primary-button" type="submit">تأكيد التعطيل</button>
                </form>
              </details> : <p className="field-hint">عطّل المواقع النشطة التابعة لهذا الكيان قبل تعطيله.</p> : <EntityActionForm tenantId={tenantId} entityId={entity.id} action="reactivate" label="إعادة تفعيل الكيان" />}
            </div>}

            <div className="entity-sites">
              <div className="section-heading"><h3>المواقع</h3><span>{activeEntitySites} نشط</span></div>
              {!canSites ? <p className="field-hint">لدى هذا الكيان {activeEntitySites} موقعًا نشطًا. تفاصيل المواقع تتطلب صلاحية إدارة المواقع.</p>
                : entity.sites.length === 0 ? <p className="field-hint">لا توجد مواقع مسجلة لهذا الكيان.</p> : <ul className="entity-site-list">
                {entity.sites.map((site) => <li className="entity-site-card" key={site.id}>
                  <div className="entity-heading">
                    <div><h4>{site.display_name}</h4><p className="field-hint">{site.is_default ? 'الموقع الافتراضي' : 'موقع'} · {site.is_active ? 'نشط' : 'غير نشط'}</p></div>
                    {site.is_active && site.is_default && <span className="entity-status is-active">افتراضي</span>}
                  </div>
                  {canSites && <div className="entity-actions">
                    <details className="entity-action-panel">
                      <summary className="secondary-button">تعديل الاسم</summary>
                      <form action={manageSiteAction} className="auth-form compact-form">
                        <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="siteId" value={site.id} />
                        <input type="hidden" name="action" value="update" />
                        <label htmlFor={`site-name-${site.id}`}>اسم الموقع</label><input id={`site-name-${site.id}`} name="displayName" defaultValue={site.display_name} required maxLength={160} />
                        <label htmlFor={`site-update-reason-${site.id}`}>سبب التعديل</label><input id={`site-update-reason-${site.id}`} name="reason" required minLength={3} maxLength={500} />
                        <button className="primary-button" type="submit">حفظ الاسم</button>
                      </form>
                    </details>
                    {site.is_active && !site.is_default && <SiteActionForm tenantId={tenantId} siteId={site.id} action="default" label="اختيار كافتراضي" reasonLabel="سبب التغيير" />}
                    {site.is_active ? <SiteActionForm tenantId={tenantId} siteId={site.id} action="deactivate" label="تعطيل الموقع" reasonLabel="سبب التعطيل" />
                      : entity.is_active && (unlimited || !full) ? <SiteActionForm tenantId={tenantId} siteId={site.id} action="reactivate" label="إعادة تفعيل الموقع" reasonLabel="سبب إعادة التفعيل" />
                      : !entity.is_active ? <p className="field-hint">أعد تفعيل الكيان قبل إعادة تفعيل الموقع.</p>
                      : <p className="field-hint">اكتمل حد المواقع. عطّل موقعًا غير مستخدم أو اطلب رفع الحد.</p>}
                  </div>}
                </li>)}
              </ul>}

              {canSites && entity.is_active && <div className="site-create-area">
                <h4>إضافة موقع</h4>
                {full ? <p className="form-message capacity-message">اكتمل حد المواقع الحالي. عطّل موقعًا غير مستخدم أو تواصل مع مسؤول اشتراك الشركة أو دعم المنصة لرفع الحد.</p> : <form action={manageSiteAction} className="auth-form entities-sites-form">
                  <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="legalEntityId" value={entity.id} />
                  <input type="hidden" name="action" value="create" />
                  <label htmlFor={`new-site-${entity.id}`}>اسم الموقع</label><input id={`new-site-${entity.id}`} name="displayName" required maxLength={160} />
                  <label htmlFor={`new-site-reason-${entity.id}`}>سبب الإضافة</label><input id={`new-site-reason-${entity.id}`} name="reason" required minLength={3} maxLength={500} />
                  <button className="primary-button" type="submit">إضافة موقع</button>
                </form>}
              </div>}
            </div>
          </section>
        );
      })}
      <footer className="footer"><Link href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link></footer>
    </main>
  );
}

function EntityActionForm({ tenantId, entityId, action, label }: { tenantId: string; entityId: string; action: 'reactivate'; label: string }) {
  return <form action={manageLegalEntityAction} className="inline-action-form">
    <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="entityId" value={entityId} />
    <input type="hidden" name="action" value={action} /><ReasonInput id={`entity-reactivate-${entityId}`} label="سبب إعادة التفعيل" />
    <button className="secondary-button" type="submit">{label}</button>
  </form>;
}

function SiteActionForm({ tenantId, siteId, action, label, reasonLabel }: { tenantId: string; siteId: string; action: 'default'|'deactivate'|'reactivate'; label: string; reasonLabel: string }) {
  return <details className="entity-action-panel">
    <summary className="secondary-button">{label}</summary>
    <form action={manageSiteAction} className="auth-form compact-form">
      <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="siteId" value={siteId} />
      <input type="hidden" name="action" value={action} />
      <label htmlFor={`site-reason-${action}-${siteId}`}>{reasonLabel}</label>
      <input id={`site-reason-${action}-${siteId}`} name="reason" required minLength={3} maxLength={500} />
      <button className="primary-button" type="submit">تأكيد {label}</button>
    </form>
  </details>;
}

function ReasonInput({ id, label }: { id: string; label: string }) {
  return <><label htmlFor={id}>{label}</label><input id={id} name="reason" required minLength={3} maxLength={500} /></>;
}

function statusMessage(state: string) {
  const messages: Record<string, string> = {
    'entity-created': 'تمت إضافة الكيان.', 'entity-updated': 'تم حفظ أسماء الكيان.',
    'entity-default': 'تم تحديث الكيان الافتراضي.', 'entity-deactivate': 'تم تعطيل الكيان مع حفظ سجله.',
    'entity-reactivate': 'تمت إعادة تفعيل الكيان.', 'entity-unchanged': 'لم يتغير سجل الكيان.',
    'site-created': 'تمت إضافة الموقع.', 'site-updated': 'تم حفظ اسم الموقع.',
    'site-default': 'تم تحديث الموقع الافتراضي.', 'site-deactivate': 'تم تعطيل الموقع مع حفظ سجله.',
    'site-reactivate': 'تمت إعادة تفعيل الموقع.', 'site-unchanged': 'لم يتغير سجل الموقع.',
    capacity: 'اكتمل حد المواقع الحالي. عطّل موقعًا غير مستخدم أو تواصل مع مسؤول اشتراك الشركة أو دعم المنصة لرفع الحد.',
    'entity-has-sites': 'لا يمكن تعطيل الكيان قبل تعطيل جميع المواقع النشطة التابعة له.',
    'entity-unavailable': 'أعد تفعيل الكيان قبل إضافة موقع أو إعادة تفعيله.',
    inactive: 'لا يمكن اختيار سجل غير نشط كافتراضي.', 'not-found': 'تعذر العثور على السجل المطلوب داخل هذه الشركة.',
    forbidden: 'لا تسمح صلاحيتك الحالية بهذا الإجراء.', reason: 'أدخل سببًا من 3 إلى 500 حرف.',
    name: 'تحقق من الاسم؛ اسم العرض مطلوب والحد الأقصى 160 حرفًا.',
    limit: 'تعذر التحقق من حد المواقع الحالي؛ لم يُحفظ أي تغيير.',
    move: 'لا يمكن نقل موقع إلى كيان آخر بعد إنشائه.',
    unavailable: 'الشركة غير نشطة أو أن بياناتها غير متاحة.',
    failed: 'تعذر حفظ التغيير. لم يُعتمد أي تغيير دون سجل التدقيق.',
    invalid: 'تحقق من المدخلات ثم أعد المحاولة.', setup: 'إعداد الاتصال غير مكتمل.',
  };
  return messages[state] ?? 'تم تحديث البيانات.';
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function Status({ title, detail, tenantId }: { title: string; detail: string; tenantId?: string }) {
  return <main className="app-shell">
    <header className="topbar"><Link className="brand" href={tenantId ? `/tenant/${tenantId}` : '/'}>منصة الأعمال</Link>
      <nav className="topbar-actions" aria-label="إجراءات الحساب">
        {tenantId && <><Link className="secondary-button" href={`/tenant/${tenantId}`}>مساحة الشركة</Link><Link className="secondary-button" href="/tenant/select">تبديل الشركة</Link></>}
        <form action={signOutAction}><button className="secondary-button" type="submit">تسجيل الخروج</button></form>
      </nav>
    </header>
    <section className="auth-card" aria-labelledby="entities-sites-status"><p className="eyebrow">الكيانات والمواقع</p><h1 id="entities-sites-status">{title}</h1><p className="intro">{detail}</p></section>
  </main>;
}
