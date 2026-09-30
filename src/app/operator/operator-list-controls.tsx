import Link from 'next/link';

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
        <input id={inputId} name="q" type="search" defaultValue={search} maxLength={120} />
        <button className="secondary-button" type="submit">بحث</button>
      </div>
    </form>
    <nav className="topbar-actions" aria-label="صفحات النتائج">
      {page > pageCount ? <>
        <span>هذه الصفحة لم تعد متاحة · {matchingCount} نتيجة</span>
        <Link className="secondary-button" href={pageUrl(pageCount)}>عرض آخر صفحة</Link>
      </> : <>
        {page > 1 && <Link className="secondary-button" href={pageUrl(page - 1)}>السابق</Link>}
        <span>صفحة {page} من {pageCount} · {matchingCount} نتيجة</span>
        {page < pageCount && <Link className="secondary-button" href={pageUrl(page + 1)}>التالي</Link>}
      </>}
    </nav>
  </>;
}
