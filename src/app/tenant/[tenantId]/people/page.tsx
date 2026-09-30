import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
type Employee = { id: string; code: string; name: string; status: string; employer: string | null; site: string | null; start_date: string | null };
type Access = { can_manage: boolean; can_manage_employment: boolean; can_manage_compensation: boolean };

export default async function PeoplePage({ params }: { params: Promise<{ tenantId: string }> }) {
  const { tenantId } = await params;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people`)}`);
  const [accessResult, directoryResult] = await Promise.all([
    supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId }),
    supabase.rpc('people_directory', { p_tenant_id: tenantId }),
  ]);
  if (accessResult.error || directoryResult.error || !accessResult.data || !Array.isArray(directoryResult.data)) {
    return <Unavailable tenantId={tenantId} />;
  }
  const access = accessResult.data as unknown as Access;
  const employees = directoryResult.data as Employee[];
  const canAdd = access.can_manage && access.can_manage_employment && access.can_manage_compensation;
  return <PageFrame footer="الموارد البشرية">
    <header className="workspace-page-heading"><div><p className="eyebrow">الموارد البشرية</p>
      <h1>الموظفون</h1><p>ملفات الموظفين وتفاصيل عملهم في الشركة.</p></div>
      {canAdd && <Link className="primary-button" href={`/tenant/${tenantId}/people/new`}>إضافة موظف</Link>}
    </header>
    <section className="workspace-records-panel" aria-label="دليل الموظفين">
      {employees.length === 0 ? <div className="empty-state"><h2>لا يوجد موظفون بعد</h2>
        <p>{canAdd ? 'أضف أول موظف لتبدأ سجل العاملين.' : 'لم تُسجّل ملفات موظفين في هذه الشركة بعد.'}</p></div>
      : <ul className="record-list">{employees.map((employee) => <li className="record-card" key={employee.id}>
        <div className="record-main"><div className="record-title-row"><h2>{employee.name}</h2>
          <span className={`entity-status ${employee.status === 'active' ? 'is-active' : 'is-inactive'}`}>
            {employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'سيبدأ قريبًا' : employee.status === 'ended' ? 'انتهت خدمته' : 'غير نشط'}</span></div>
          <p className="record-meta">رمز الموظف: <bdi>{employee.code}</bdi></p>
          <p className="record-meta">{[employee.employer, employee.site].filter(Boolean).join(' · ') || 'لم يبدأ العمل بعد'}
            {employee.status === 'scheduled' && employee.start_date && <> · يبدأ في <bdi>{employee.start_date}</bdi></>}</p>
        </div><Link className="secondary-button" href={`/tenant/${tenantId}/people/${employee.id}`}>عرض الملف</Link>
      </li>)}</ul>}
    </section>
  </PageFrame>;
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>الموظفون غير متاحين</h1>
    <p className="intro">تحقق من تفعيل الموارد البشرية وصلاحيتك في هذه الشركة، ثم أعد المحاولة.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
  </section></PageFrame>;
}
