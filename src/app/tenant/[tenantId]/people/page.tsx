import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
const MAX_PAGE = 1000;
type Employee = { id: string; code: string; name: string; status: string; employer: string | null; site: string | null; start_date: string | null };
type DirectoryPage = { items: Employee[]; has_more: boolean; page: number };
type Access = { can_manage: boolean; can_manage_employment: boolean; can_manage_compensation: boolean };
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
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people`)}`);
  const accessResult = await supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId });
  if (accessResult.error || !accessResult.data) return <Unavailable tenantId={tenantId} />;
  const access = accessResult.data as unknown as Access;
  const canAdd = access.can_manage && access.can_manage_employment && access.can_manage_compensation;
  const directoryResult = invalidQuery || invalidPage ? null : await supabase.rpc('people_directory_page', {
    p_tenant_id: tenantId, p_query: query || null, p_page: page,
  });
  const result = directoryResult?.data as unknown as DirectoryPage | null;
  const failed = Boolean(directoryResult?.error || !result || !Array.isArray(result.items));
  const employees = failed || !result ? [] : result.items;
  return <PageFrame footer="الموارد البشرية">
    <header className="workspace-page-heading"><div><p className="eyebrow">الموارد البشرية</p>
      <h1>الموظفون</h1><p>ملفات الموظفين وتفاصيل عملهم في الشركة.</p></div>
      {canAdd && <Link className="primary-button" href={`/tenant/${tenantId}/people/new`}>إضافة موظف</Link>}
    </header>
    <section className="workspace-records-panel" aria-label="دليل الموظفين">
      <form method="get" role="search" className="people-search-form">
        <label htmlFor="people-query">ابحث بالاسم أو رمز الموظف</label>
        <div><input id="people-query" name="q" type="search" maxLength={100} defaultValue={query} placeholder="مثال: أحمد أو EMP-12" />
          <button className="secondary-button" type="submit">بحث</button></div>
      </form>
      {invalidQuery ? <p className="form-message" role="alert">يجب ألا يتجاوز البحث 100 حرف.</p>
        : invalidPage ? <p className="form-message" role="alert">رقم الصفحة غير صالح.</p>
        : failed ? <div className="empty-state" role="alert"><h2>تعذر تحميل دليل الموظفين</h2>
          <p>تحقق من الاتصال والصلاحية، ثم أعد المحاولة.</p>
          <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>إعادة المحاولة</Link></div>
        : employees.length === 0 ? <div className="empty-state"><h2>{query ? 'لا توجد نتائج مطابقة' : 'لا يوجد موظفون بعد'}</h2>
          <p>{query ? 'جرّب اسمًا أو رمز موظف مختلفًا.' : canAdd ? 'أضف أول موظف لتبدأ سجل العاملين.' : 'لم تُسجّل ملفات موظفين في هذه الشركة بعد.'}</p>
          {page > 1 && <Link className="secondary-button" href={pageHref(tenantId, query, page - 1)}>العودة إلى الصفحة السابقة</Link>}
        </div>
        : <>
          <ul className="record-list">{employees.map((employee) => <li className="record-card" key={employee.id}>
            <div className="record-main"><div className="record-title-row"><h2>{employee.name}</h2>
              <span className={`entity-status ${employee.status === 'active' ? 'is-active' : 'is-inactive'}`}>
                {employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'سيبدأ قريبًا' : employee.status === 'ended' ? 'انتهت خدمته' : 'غير نشط'}</span></div>
              <p className="record-meta">رمز الموظف: <bdi>{employee.code}</bdi></p>
              <p className="record-meta">{[employee.employer, employee.site].filter(Boolean).join(' · ') || 'لم يبدأ العمل بعد'}
                {employee.status === 'scheduled' && employee.start_date && <> · يبدأ في <bdi>{employee.start_date}</bdi></>}</p>
            </div><Link className="secondary-button" href={`/tenant/${tenantId}/people/${employee.id}`}>عرض الملف</Link>
          </li>)}</ul>
          <nav className="people-pagination" aria-label="صفحات دليل الموظفين">
            <span>الصفحة {page}</span>
            {page > 1 && <Link className="secondary-button" href={pageHref(tenantId, query, page - 1)}>السابق</Link>}
            {result?.has_more && page < MAX_PAGE && <Link className="secondary-button" href={pageHref(tenantId, query, page + 1)}>التالي</Link>}
          </nav>
        </>}
    </section>
  </PageFrame>;
}

function pageHref(tenantId: string, query: string, page: number) {
  const params = new URLSearchParams({ page: String(page) });
  if (query) params.set('q', query);
  return `/tenant/${tenantId}/people?${params.toString()}`;
}

function Unavailable({ tenantId }: { tenantId: string }) {
  return <PageFrame><section className="auth-card"><h1>الموظفون غير متاحين</h1>
    <p className="intro">تحقق من تفعيل الموارد البشرية وصلاحيتك في هذه الشركة، ثم أعد المحاولة.</p>
    <Link className="secondary-button" href={`/tenant/${tenantId}`}>العودة إلى مساحة الشركة</Link>
  </section></PageFrame>;
}
