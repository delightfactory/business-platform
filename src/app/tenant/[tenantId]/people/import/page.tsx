import { ButtonLink, Disclosure, PageHeader, Panel } from '@/components/ui';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { WorkforceImportForm } from './WorkforceImportForm';
import styles from '../people-management.module.css';

export const dynamic = 'force-dynamic';

type Access = { can_manage: boolean; can_manage_employment: boolean; can_view_compensation: boolean;
  can_manage_compensation: boolean; can_import: boolean };

export default async function WorkforceImportPage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/import`)}`);
  const { data, error } = await supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Unavailable tenantId={tenantId} />;
  const access = data as unknown as Access;
  if (!(access.can_manage && access.can_manage_employment && access.can_view_compensation
    && access.can_manage_compensation && access.can_import)) return <Unavailable tenantId={tenantId} />;
  return <PageFrame footer="الموارد البشرية"><div className="workspace-form-page">
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink>
    <PageHeader title={<>استيراد الموظفين</>} eyebrow={<>الموارد البشرية</>} description={<>افحص الملف كاملًا، راجع الصفوف، ثم أضف الصفوف التي وافقت عليها دفعة واحدة.</>} />
    <Panel  aria-label="استيراد ملف الموظفين">
      <div className={styles.importGuide}><h2>ابدأ بالقالب المعتمد</h2>
        <p>نزّل القالب واملأ بيانات الموظفين، ثم اختر الملف أدناه لفحصه قبل الإضافة.</p>
        <a className="ui-button ui-button-ghost ui-button-md" href="/templates/workforce-import.csv" download="workforce-import.csv">تنزيل قالب CSV</a>
        <Disclosure  summary={<>صيغة الملف والقيم المقبولة</>}>
          <p className={styles.formatHelp}>استخدم UTF-8، واحتفظ بأسماء الأعمدة كما هي. التاريخ بصيغة <bdi>YYYY-MM-DD</bdi>، وطريقة الأجر <bdi>monthly</bdi> أو <bdi>daily</bdi>، والرواتب <bdi>true</bdi> أو <bdi>false</bdi>. المبلغ بالجنيه المصري. أدخل القسم والوظيفة برمزهما؛ لا ينشئ الاستيراد عناصر تنظيمية جديدة.</p>
        </Disclosure>
      </div>
      <WorkforceImportForm tenantId={tenantId} />
    </Panel>
  </div></PageFrame>;
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><Panel ><h1>الاستيراد غير متاح</h1>
    <p className="intro">تحتاج إلى صلاحيات إدارة الموظفين والتوظيف والأجور واستيراد القوى العاملة، وإلى تفعيل الموارد البشرية لهذه الشركة.</p>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink>
  </Panel></PageFrame>;
}
