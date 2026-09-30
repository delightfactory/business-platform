import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { NewEmployeeForm, type OnboardingOptions } from './NewEmployeeForm';

export const dynamic = 'force-dynamic';

export default async function NewEmployeePage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/new`)}`);
  const { data, error } = await supabase.rpc('people_onboarding_options', { p_tenant_id: tenantId });
  if (error || !data || typeof data !== 'object' || Array.isArray(data)) return <Unavailable tenantId={tenantId} />;
  const options = data as unknown as OnboardingOptions;
  return <PageFrame footer="الموارد البشرية"><div className="workspace-form-page">
    <Link className="back-link" href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</Link>
    <header className="workspace-page-heading"><div><p className="eyebrow">الموارد البشرية</p>
      <h1>إضافة موظف</h1><p>سجّل الموظف وجهة عمله وفرعه وأجره الأساسي في خطوة واحدة.</p></div></header>
    <section className="workspace-form-panel" aria-label="بيانات الموظف">
      <NewEmployeeForm tenantId={tenantId} options={options} />
    </section>
  </div></PageFrame>;
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>لا يمكن إضافة موظف</h1>
    <p className="intro">تحتاج إلى صلاحية إدارة الموظفين والتوظيف والأجور، وإلى تفعيل الموارد البشرية لهذه الشركة.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>العودة إلى الموظفين</Link>
  </section></PageFrame>;
}
