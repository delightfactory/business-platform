import { Badge, Button, ButtonLink, EmptyState, Input, Message, PageHeader, Panel, RecordCard } from '@/components/ui';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { PageFrame } from '@/components/context-navigation';
import { FeedbackToast } from '@/components/feedback-toast';
import { getWorkspaceClient as createSupabaseServerClient, getWorkspaceUser } from '@/lib/workspace-access';
import styles from '../people-management.module.css';

export const dynamic = 'force-dynamic';
const MAX_PAGE = 1000;
type Kind = 'departments' | 'jobs';
type CatalogRow = {
  id: string; code: string; name: string; is_active: boolean; effectively_active: boolean;
  parent_id?: string | null; parent_name?: string | null; department_id?: string | null; department_name?: string | null;
};
type CatalogResult = { items: CatalogRow[]; has_more: boolean; page: number };
type Query = Promise<{ kind?: string | string[]; q?: string | string[]; page?: string | string[]; state?: string }>;

export default async function PeopleOrganizationPage({ params, searchParams }: { params: Promise<{ tenantId: string }>; searchParams: Query }) {
  const { tenantId } = await params;
  const queryParams = await searchParams;
  const kind: Kind = queryParams.kind === 'jobs' ? 'jobs' : 'departments';
  const rawQuery = typeof queryParams.q === 'string' ? queryParams.q.trim() : '';
  const rawPage = typeof queryParams.page === 'string' ? queryParams.page : '1';
  const page = /^\d+$/.test(rawPage) ? Number(rawPage) : Number.NaN;
  const invalidQuery = rawQuery.length > 100 || Array.isArray(queryParams.q);
  const invalidPage = !Number.isInteger(page) || page < 1 || page > MAX_PAGE;
  const supabase = await createSupabaseServerClient();
  if (!supabase) return <Unavailable tenantId={tenantId} title="الاتصال غير متاح" detail="تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا." />;
  const { data: { user } } = await getWorkspaceUser(supabase);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/people/organization`)}`);
  const [accessResult, catalogResult] = await Promise.all([
    supabase.rpc('people_access_snapshot', { p_tenant_id: tenantId }),
    invalidQuery || invalidPage ? Promise.resolve({ data: null, error: null }) :
      supabase.rpc('people_org_catalog', { p_tenant_id: tenantId, p_kind: kind, p_query: rawQuery || null, p_page: page }),
  ]);
  if (accessResult.error || !accessResult.data) return <Unavailable tenantId={tenantId} title="دليل الأقسام والوظائف غير متاح" detail="تحقق من صلاحيتك في هذه الشركة ثم أعد المحاولة." />;
  const canManage = (accessResult.data as { can_manage_org?: boolean }).can_manage_org === true;
  const result = catalogResult.data as unknown as CatalogResult | null;
  const failed = Boolean(catalogResult.error || !result || !Array.isArray(result.items));
  const items = result?.items ?? [];
  const success = successText(queryParams.state);
  const nextHref = listingHref(tenantId,kind,rawQuery,page+1);
  const previousHref = listingHref(tenantId,kind,rawQuery,page-1);
  const base = `/tenant/${tenantId}/people/organization`;
  const noun = kind === 'departments' ? 'القسم' : 'الوظيفة';

  return <PageFrame footer="الموارد البشرية">
    {success && <FeedbackToast key={queryParams.state} message={success} />}
    <PageHeader title={<>الأقسام والوظائف</>} eyebrow={<>الموارد البشرية</>} description={<>رتّب أقسام الشركة ووظائفها للاستخدام في ملفات الموظفين وتكليفاتهم.</>} action={<>{canManage && <ButtonLink variant="solid"  href={`${base}/${kind}/new`}>إضافة {noun}</ButtonLink>}</>} />
    <nav className="workspace-view-tabs" aria-label="نوع السجل">
      <Link href={`${base}?kind=departments`} aria-current={kind==='departments'?'page':undefined}>الأقسام</Link>
      <Link href={`${base}?kind=jobs`} aria-current={kind==='jobs'?'page':undefined}>الوظائف</Link>
    </nav>
    <Panel className="org-catalog-panel" aria-label={kind==='departments'?'دليل الأقسام':'دليل الوظائف'}>
      <form method="get" role="search" className="people-search-form">
        <input type="hidden" name="kind" value={kind} />
        <label htmlFor="org-catalog-query">ابحث بالاسم أو الرمز</label>
        <div><Input id="org-catalog-query" name="q" type="search" maxLength={100} defaultValue={rawQuery} />
          <Button variant="ghost"  type="submit">بحث</Button></div>
      </form>
      {invalidQuery ? <Message tone="bad"  role="alert">يجب ألا يتجاوز البحث 100 حرف.</Message>
        : invalidPage ? <Message tone="bad"  role="alert">رقم الصفحة غير صالح.</Message>
          : failed ? <div role="alert"><EmptyState title={<>تعذر تحميل القائمة</>} description={<>تحقق من الاتصال والصلاحية، ثم أعد المحاولة.</>} action={<><ButtonLink variant="ghost"  href={listingHref(tenantId,kind,rawQuery,page)}>إعادة المحاولة</ButtonLink></>} /></div>
            : items.length === 0 ? <div ><EmptyState title={<>{rawQuery ? 'لا توجد نتائج مطابقة' : kind==='departments'?'لا توجد أقسام مسجلة':'لا توجد وظائف مسجلة'}</>} description={<>{rawQuery ? 'جرّب اسمًا أو رمزًا مختلفًا.' : canManage ? `أضف ${kind==='departments'?'قسمًا':'وظيفة'} لتظهر في ملفات الموظفين.` : 'اطلب من مسؤول الموارد البشرية إضافة السجلات المطلوبة.'}</>} action={<>{canManage && !rawQuery && <ButtonLink variant="ghost"  href={`${base}/${kind}/new`}>إضافة {noun}</ButtonLink>}</>} /></div>
              : <>
                <ul className={styles.catalogGrid}>{items.map((item) => <RecordCard  key={item.id}>
                  <div className="record-main"><div className="record-title-row"><h2>{item.name}</h2>
                    <Badge className={`entity-status ${item.effectively_active?'is-active':'is-inactive'}`}>
                      {item.effectively_active?'نشط':item.is_active?'غير متاح للتعيين':'غير نشط'}</Badge></div>
                    <p className="record-meta">الرمز: <bdi>{item.code}</bdi></p>
                    {kind==='departments' && item.parent_name && <p className="record-meta">القسم الأعلى: {item.parent_name}</p>}
                    {kind==='jobs' && item.department_name && <p className="record-meta">القسم: {item.department_name}</p>}
                    {item.is_active && !item.effectively_active && <p className="record-meta">تعطّل هذا الاختيار لأن القسم المرتبط به غير نشط.</p>}
                  </div>
                  {canManage && <ButtonLink variant="ghost"  href={`${base}/${kind}/${item.id}`}>تعديل</ButtonLink>}
                </RecordCard>)}</ul>
                <nav className="people-pagination" aria-label="صفحات القائمة">
                  <span>الصفحة {page}</span>
                  {page>1 && <ButtonLink variant="ghost"  href={previousHref}>السابق</ButtonLink>}
                  {result?.has_more && page<MAX_PAGE && <ButtonLink variant="ghost"  href={nextHref}>التالي</ButtonLink>}
                </nav>
              </>}
    </Panel>
    <p className="org-catalog-back"><ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى دليل الموظفين</ButtonLink></p>
  </PageFrame>;
}

function listingHref(tenantId:string,kind:Kind,query:string,page:number) {
  const params=new URLSearchParams({kind,page:String(page)}); if(query) params.set('q',query);
  return `/tenant/${tenantId}/people/organization?${params.toString()}`;
}
function successText(state?:string) {
  const messages:Record<string,string>={
    'department-created':'تمت إضافة القسم.','department-updated':'تم تحديث القسم.',
    'department-deactivated':'تم تعطيل القسم مع حفظ سجل التكليفات السابقة.','department-reactivated':'تمت إعادة تفعيل القسم.',
    'department-unchanged':'لم تتغير بيانات القسم.','job-created':'تمت إضافة الوظيفة.','job-updated':'تم تحديث الوظيفة.',
    'job-deactivated':'تم تعطيل الوظيفة مع حفظ سجل التكليفات السابقة.','job-reactivated':'تمت إعادة تفعيل الوظيفة.',
    'job-unchanged':'لم تتغير بيانات الوظيفة.',
  };
  return state?messages[state]:null;
}
function Unavailable({tenantId,title,detail}:{tenantId:string;title:string;detail:string}) {
  return <PageFrame><Panel ><h1>{title}</h1><p className="intro">{detail}</p>
    <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>العودة إلى دليل الموظفين</ButtonLink></Panel></PageFrame>;
}
