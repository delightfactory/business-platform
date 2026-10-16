import { ButtonLink, Disclosure, PageHeader, Panel } from '@/components/ui';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import { WorkforceImportForm } from './WorkforceImportForm';
import styles from '../people-management.module.css';

export const dynamic = 'force-dynamic';

type Access = { can_manage: boolean; can_manage_employment: boolean; can_view_compensation: boolean;
  can_manage_compensation: boolean; can_import: boolean };

export default async function WorkforceImportPage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/import`)}`);
  const { data, error } = await supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Unavailable tenantId={tenantId} />;
  const access = data as unknown as Access;
  if (!(access.can_manage && access.can_manage_employment && access.can_view_compensation
    && access.can_manage_compensation && access.can_import)) return <Unavailable tenantId={tenantId} />;
  return <PageFrame footer="الموارد البشرية"><div className="workspace-form-page">
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</ButtonLink>
    <PageHeader title={<>استيراد الموظفين</>} eyebrow={<>الموارد البشرية</>} description={<>افحص الملف كاملًا، راجع الصفوف، ثم أضف الصفوف التي وافقت عليها دفعة واحدة.</>} />
    <p className="field-hint">الاستيراد لا يعيّن سياسات الدوام أو أرصدة الإجازات؛ تابع من جاهزية كل موظف بعد إضافته.</p>
    <Panel  aria-label="استيراد ملف الموظفين">
      <div className={styles.importGuide}><h2>ابدأ بالقالب المعتمد</h2>
        <p>نزّل القالب بعناوين عربية واملأ بيانات الموظفين، ثم اختر الملف أدناه لفحصه قبل الإضافة.</p>
        <a className="ui-button ui-button-ghost ui-button-md" href="/templates/workforce-import.csv" download="workforce-import.csv">تنزيل قالب CSV</a>
        <Disclosure  summary={<>صيغة الملف والقيم المقبولة</>}>
          <p className={styles.formatHelp}>احفظ الملف بصيغة CSV بترميز UTF-8. احتفظ بالأعمدة العشرة وعناوينها؛ يمكنك تغيير ترتيبها، وما زال القالب الإنجليزي السابق مقبولًا. لا تجمع عمودين للمعلومة نفسها بالعربية والإنجليزية.</p>
          <p className={styles.formatHelp}>«تاريخ بدء العمل» مثل <bdi>2026-10-16</bdi>. «طريقة الأجر»: <bdi>monthly</bdi> للشهري أو <bdi>daily</bdi> لليومي. «مشمول بالرواتب»: <bdi>true</bdi> لنعم أو <bdi>false</bdi> للا. «الأجر الأساسي» بالجنيه المصري. أدخل «رمز القسم» و«رمز الوظيفة» الموجودين عند الحاجة؛ لا ينشئ الاستيراد عناصر تنظيمية جديدة.</p>
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
