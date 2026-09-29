import Link from 'next/link';
import { redirect } from 'next/navigation';
import { TenantNavigation } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { BrandingEditor } from './BrandingEditor';

export const dynamic = 'force-dynamic';
type Params = Promise<{ tenantId: string }>;
type Query = Promise<{ state?: string }>;
type Branding = {
  tenant_id: string; tenant_name: string; display_name_override: string | null;
  primary_color_key: 'teal' | 'blue' | 'violet' | 'emerald'; logo_object_path: string | null; can_manage_branding: boolean;
};

export default async function TenantBrandingPage({ params, searchParams }: { params: Params; searchParams: Query }) {
  const { tenantId } = await params;
  const query = await searchParams;
  if (!isUuid(tenantId)) redirect('/tenant/select?state=invalid');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Status tenantId={tenantId} title="إعداد الاتصال غير مكتمل" />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/branding`)}`);
  const { data, error } = await supabase.rpc('tenant_branding_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Status tenantId={tenantId} title="مساحة الشركة غير متاحة" />;
  const branding = data as Branding;
  const { data: tenantData } = await supabase.rpc('tenant_membership_snapshot', { p_tenant_id: tenantId });
  const tenant = tenantData && typeof tenantData === 'object' && !Array.isArray(tenantData)
    ? tenantData as Record<string, unknown> : null;
  let logoUrl: string | null = null;
  if (branding.logo_object_path) {
    const { data: signedData } = await supabase.storage.from('tenant-branding').createSignedUrl(branding.logo_object_path, 60);
    logoUrl = signedData?.signedUrl ?? null;
  }

  return <main className="app-shell">
    {query.state === 'saved' && <FeedbackToast key={crypto.randomUUID()} message={stateText('saved')} />}
    <TenantNavigation tenantId={tenantId} tenantName={branding.tenant_name} current="branding" />
    <section className="work-card" aria-labelledby="branding-title">
      <p className="eyebrow">إعداد الهوية</p><h1 id="branding-title"><bdi>{branding.tenant_name}</bdi></h1>
      <p className="intro">اسم العرض والشعار واللون الرئيسي لمساحة الشركة.</p>
      {query.state && query.state !== 'saved' && <p className="form-message form-error" role="alert">{stateText(query.state)}</p>}
      <BrandingEditor tenantId={tenantId} initialName={branding.display_name_override ?? ''}
        baseName={String(tenant?.tenant_name ?? branding.tenant_name)} colorKey={branding.primary_color_key} logoUrl={logoUrl}
        hasStoredLogo={Boolean(branding.logo_object_path)} canManage={branding.can_manage_branding} />
    </section><footer className="footer">منصة الأعمال · هوية الشركة</footer>
  </main>;
}

function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function stateText(state: string) {
  const messages: Record<string, string> = {
    saved: 'تم حفظ هوية الشركة وتسجيل التغيير.',
    invalid: 'تحقق من الاسم واللون والصورة المختارة.', reason: 'اكتب سببًا من 3 إلى 500 حرف.', setup: 'إعداد الاتصال غير مكتمل.',
    forbidden: 'تغيير الهوية متاح لمسؤول الشركة فقط.', unavailable: 'الشركة غير متاحة حاليًا.',
    file: 'اختر صورة PNG أو JPG أو WebP لا يتجاوز حجمها 2MB.',
    'upload-failed': 'تعذر رفع الصورة. لم يتغير إعداد الهوية.',
    'save-failed': 'تعذر حفظ الهوية. لم يتغير الإعداد الحالي. يمكنك المحاولة مرة أخرى.',
    logo: 'تعذر التحقق من الصورة الحالية. يمكنك استبدالها بصورة جديدة أو إزالة الشعار من العرض.',
  };
  return messages[state] ?? 'تعذر حفظ الهوية.';
}
function Status({ tenantId, title }: { tenantId: string; title: string }) { return <main className="app-shell"><header className="topbar"><Link className="brand" href={`/tenant/${tenantId}`}>مساحة الشركة</Link></header><section className="auth-card"><h1>{title}</h1><p className="intro">تحقق من العضوية والصلاحية ثم أعد المحاولة.</p><Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة للشركة</Link></section></main>; }
