'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { signOutAction } from '@/app/auth/actions';

export type ContextLink = { href: string; label: string; current?: boolean };

export function ContextNavigationClient({
  homeHref, homeLabel, contextLabel, links, switchHref, switchLabel, deriveContext = false, showContextTitle = true,
}: {
  homeHref: string; homeLabel: string; contextLabel: string; links: ContextLink[];
  switchHref?: string; switchLabel?: string; deriveContext?: boolean; showContextTitle?: boolean;
}) {
  const pathname = usePathname();
  const allLinks = [...links, ...(switchHref && switchLabel ? [{ href: switchHref, label: switchLabel }] : [])];
  const activeLink = allLinks.find((item) => pathname === item.href || pathname.startsWith(`${item.href}/`));
  const title = deriveContext ? activeLink?.label ?? (pathname === homeHref ? 'المهام' : contextLabel) : contextLabel;

  return (
    <header className="context-header">
      <div className="context-identity">
        <Link className="context-home" href={homeHref} aria-label={homeLabel} aria-current={pathname === homeHref ? 'page' : undefined}>
          <span className="brand-mark" aria-hidden="true">م</span>
          <span>{homeLabel}</span>
        </Link>
        {showContextTitle && <><span className="context-divider" aria-hidden="true">/</span><bdi className="context-title">{title}</bdi></>}
      </div>

      <nav className="context-desktop-nav" aria-label="التنقل في المنصة">
        {allLinks.map((item) => <Link key={item.href} href={item.href} aria-current={pathname === item.href || pathname.startsWith(`${item.href}/`) ? 'page' : undefined}>{item.label}</Link>)}
        <form action={signOutAction}><button type="submit">خروج</button></form>
      </nav>

      <details className="context-mobile-nav">
        <summary aria-label="فتح قائمة التنقل">القائمة</summary>
        <nav aria-label="التنقل في المنصة">
          {allLinks.map((item) => <Link key={item.href} href={item.href} aria-current={pathname === item.href || pathname.startsWith(`${item.href}/`) ? 'page' : undefined}>{item.label}</Link>)}
          <form action={signOutAction}><button type="submit">تسجيل الخروج</button></form>
        </nav>
      </details>
    </header>
  );
}
