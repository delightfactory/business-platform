import { Button, ButtonLink, Input } from '@/components/ui';

type QueryParams = { page?: string | string[]; q?: string | string[] };

export function operatorListQuery(params: QueryParams) {
  const rawPage = typeof params.page === 'string' ? params.page : '';
  return {
    page: /^[1-9]\d{0,5}$/.test(rawPage) ? Math.min(Number(rawPage), 100000) : 1,
    search: (typeof params.q === 'string' ? params.q : '').trim().slice(0, 120),
  };
}

export function OperatorListControls({ basePath, search, page, matchingCount, searchLabel, inputId }: {
  basePath: string; search: string; page: number; matchingCount: number; searchLabel: string; inputId: string;
}) {
  const pageCount = Math.max(1, Math.ceil(matchingCount / 25));
  const pageUrl = (target: number) => {
    const query = new URLSearchParams();
    if (search) query.set('q', search);
    if (target > 1) query.set('page', String(target));
    const suffix = query.toString();
    return suffix ? `${basePath}?${suffix}` : basePath;
  };
  return <>
    <form action={basePath} method="get" role="search" className="workspace-form-panel">
      <label htmlFor={inputId}>{searchLabel}</label>
      <div className="topbar-actions">
        <Input id={inputId} name="q" type="search" defaultValue={search} maxLength={120} />
        <Button variant="ghost"  type="submit">بحث</Button>
      </div>
    </form>
    <nav className="topbar-actions" aria-label="صفحات النتائج">
      {page > pageCount ? <>
        <span>هذه الصفحة لم تعد متاحة · {matchingCount} نتيجة</span>
        <ButtonLink variant="ghost"  href={pageUrl(pageCount)}>عرض آخر صفحة</ButtonLink>
      </> : <>
        {page > 1 && <ButtonLink variant="ghost"  href={pageUrl(page - 1)}>السابق</ButtonLink>}
        <span>صفحة {page} من {pageCount} · {matchingCount} نتيجة</span>
        {page < pageCount && <ButtonLink variant="ghost"  href={pageUrl(page + 1)}>التالي</ButtonLink>}
      </>}
    </nav>
  </>;
}
