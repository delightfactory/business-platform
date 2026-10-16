import { employeeDirectoryLinks } from '@/lib/profile-return';
import { Avatar, ButtonLink, DataTable, Disclosure, EmptyState, Message, PageHeader, Panel, StatusBadge } from '@/components/ui';

import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import styles from './people.module.css';
import { DirectorySearch } from './DirectorySearch';
import { EmployeePreview } from './EmployeePreview';

export const dynamic = 'force-dynamic';
const MAX_PAGE = 1000;
type Employee = { id: string; code: string; name: string; status: string; employer: string | null; site: string | null; start_date: string | null };
type DirectoryPage = { items: Employee[]; has_more: boolean; page: number };
type Access = { can_manage: boolean; can_manage_employment: boolean; can_manage_compensation: boolean;
  can_view_compensation: boolean; can_import: boolean; can_manage_org: boolean };
type SearchParams = Promise<{ q?: string | string[]; page?: string | string[] }>;

export default async function PeoplePage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: SearchParams }) {
  const { tenantId } = await params;
  const search = await searchParams;
  const query = typeof search.q === 'string' ? search.q.trim() : '';
  const rawPage = typeof search.page === 'string' ? search.page : '1';
  const page = /^\d+$/.test(rawPage) ? Number(rawPage) : Number.NaN;
  const invalidQuery = query.length > 100;
  const invalidPage = !Number.isInteger(page) || page < 1 || page > MAX_PAGE;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people`)}`);
  const accessResult = await supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId });
  if (accessResult.error || !accessResult.data) return <Unavailable tenantId={tenantId} />;
  const access = accessResult.data as unknown as Access;
  const policyResult = await supabase.rpc('time_work_policy_catalog', { p_tenant_id: tenantId });
  const canManagePolicies = !policyResult.error && policyResult.data && typeof policyResult.data === 'object'
    && !Array.isArray(policyResult.data) && (policyResult.data as { can_manage?: boolean }).can_manage === true;
  const canAdd = access.can_manage && access.can_manage_employment && access.can_manage_compensation;
  const canImport = canAdd && access.can_view_compensation && access.can_import;
  const directoryResult = invalidQuery || invalidPage ? null : await supabase.rpc('people_directory_page', {
    p_tenant_id: tenantId, p_query: query || null, p_page: page,
  });
  const result = directoryResult?.data as unknown as DirectoryPage | null;
  const failed = Boolean(directoryResult?.error || !result || !Array.isArray(result.items));
  const employees = failed || !result ? [] : result.items;
  return <PageFrame footer="الموارد البشرية">
    <PageHeader title="الموظفون" description="ملف واحد لكل موظف: العمل والراتب والحضور والإجازات." action={<>
      {canImport && <ButtonLink variant="ghost" icon="upload" href={`/tenant/${tenantId}/people/import`}>استيراد</ButtonLink>}
      {canAdd && <ButtonLink icon="plus" href={`/tenant/${tenantId}/people/new`}>إضافة موظف</ButtonLink>}
    </>} />
    {(access.can_manage_org || canManagePolicies) && <Disclosure summary="إعدادات الموظفين"><nav className={styles.settingsLinks} aria-label="إعدادات الموارد البشرية">
      {access.can_manage_org && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/organization`}>الأقسام والوظائف</ButtonLink>}
      {canManagePolicies && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people/work-policies`}>قوالب الدوام</ButtonLink>}
    </nav></Disclosure>}
    <Panel className={`${styles.directoryPanel}`} aria-label="دليل الموظفين">
      <DirectorySearch href={`/tenant/${tenantId}/people`} query={query} page={page} />
      {query && !invalidQuery && !invalidPage && <p className="record-meta">نتائج البحث عن: <bdi>{query}</bdi></p>}
      {invalidQuery ? <Message tone="info"  role="alert">يجب ألا يتجاوز البحث 100 حرف.</Message>
        : invalidPage ? <Message tone="info"  role="alert">رقم الصفحة غير صالح.</Message>
        : failed ? <div role="alert"><EmptyState title={<>تعذر تحميل دليل الموظفين</>} description={<>تحقق من الاتصال والصلاحية، ثم أعد المحاولة.</>} action={<><ButtonLink variant="ghost"  href={pageHref(tenantId, query, invalidPage ? 1 : page)}>إعادة المحاولة</ButtonLink></>} /></div>
        : employees.length === 0 ? <div ><EmptyState title={<>{query ? 'لا توجد نتائج مطابقة' : 'لا يوجد موظفون بعد'}</>} description={<>{query ? 'جرّب اسمًا أو رمز موظف مختلفًا.' : canAdd ? 'أضف أول موظف لتبدأ سجل العاملين.' : 'لم تُسجّل ملفات موظفين في هذه الشركة بعد.'}</>} action={<>{page > 1 && <ButtonLink variant="ghost"  href={pageHref(tenantId, query, page - 1)}>العودة إلى الصفحة السابقة</ButtonLink>}</>} /></div>
        : <>
          <div className="workspace-table-wrap"><DataTable className="workspace-record-table"><caption>الموظفون — الصفحة {page}</caption><thead><tr><th scope="col">الموظف</th><th scope="col">مكان العمل</th><th scope="col">الحالة</th><th scope="col">الملف</th></tr></thead><tbody>{employees.map((employee) => {
            const links = employeeDirectoryLinks(tenantId, employee.id, query || page > 1 ? pageHref(tenantId, query, page) : null);
            return <tr key={employee.id}>
            <th scope="row"><div className={styles.employeeIdentity}><Avatar name={employee.name} size={40} status={employee.status === 'active' ? 'ok' : 'neutral'} /><div><strong>{employee.name}</strong>
              <p className="record-meta"><bdi>{employee.code}</bdi></p></div></div></th>
            <td>{[employee.employer, employee.site].filter(Boolean).join(' · ') || 'لم يبدأ العمل بعد'}
              {employee.status === 'scheduled' && employee.start_date && <> · يبدأ في <bdi>{employee.start_date}</bdi></>}</td>
              <td><StatusBadge tone={employee.status === 'active' ? 'ok' : 'neutral'} label={employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'سيبدأ قريبًا' : employee.status === 'ended' ? 'انتهت خدمته' : 'غير نشط'} /></td>
            <td><div className={styles.rowActions}><ButtonLink variant="ghost" href={links.href} aria-label={`فتح الملف: ${employee.name}`}>فتح الملف</ButtonLink>
              <EmployeePreview href={links.href} previewHref={links.previewHref} employeeId={employee.id} name={employee.name} code={employee.code} />
            </div></td>
          </tr>;
          })}</tbody></DataTable></div>
          <nav className="people-pagination" aria-label="صفحات دليل الموظفين">
            <span>الصفحة {page}</span>
            {page > 1 && <ButtonLink variant="ghost"  href={pageHref(tenantId, query, page - 1)}>السابق</ButtonLink>}
            {result?.has_more && page < MAX_PAGE && <ButtonLink variant="ghost"  href={pageHref(tenantId, query, page + 1)}>التالي</ButtonLink>}
          </nav>
        </>}
    </Panel>
  </PageFrame>;
}

function pageHref(tenantId: string, query: string, page: number) {
  const params = new URLSearchParams({ page: String(page) });
  if (query) params.set('q', query);
  return `/tenant/${tenantId}/people?${params.toString()}`;
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><Panel ><h1>الموظفون غير متاحين</h1>
    <p className="intro">تحقق من تفعيل الموارد البشرية وصلاحيتك في هذه الشركة، ثم أعد المحاولة.</p>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</ButtonLink>
  </Panel></PageFrame>;
}
