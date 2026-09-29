'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useRef } from 'react';
import { signOutAction } from '@/app/auth/actions';

export type ContextLink = { href: string; label: string; current?: boolean };

export function ContextNavigationClient({
  homeHref, homeLabel, contextLabel, links, switchHref, switchLabel, deriveContext = false, showContextTitle = true,
}: {
  homeHref: string; homeLabel: string; contextLabel: string; links: ContextLink[];
  switchHref?: string; switchLabel?: string; deriveContext?: boolean; showContextTitle?: boolean;
}) {
  const pathname = usePathname();
  const mobileDialog = useRef<HTMLDialogElement>(null);
  const previousOverflow = useRef('');
  const menuOwnsScrollLock = useRef(false);
  const allLinks = [...links, ...(switchHref && switchLabel ? [{ href: switchHref, label: switchLabel }] : [])];
  const activeLink = allLinks.find((item) => pathname === item.href || pathname.startsWith(`${item.href}/`));
  const title = deriveContext ? activeLink?.label ?? (pathname === homeHref ? 'المهام' : contextLabel) : contextLabel;

  useEffect(() => {
    if (mobileDialog.current?.open) mobileDialog.current.close();
  }, [pathname]);
  useEffect(() => () => {
    if (menuOwnsScrollLock.current) document.body.style.overflow = previousOverflow.current;
  }, []);

  function openMobileMenu() {
    if (!mobileDialog.current) return;
    previousOverflow.current = document.body.style.overflow;
    mobileDialog.current.showModal();
    document.body.style.overflow = 'hidden';
    menuOwnsScrollLock.current = true;
  }

  function closeMobileMenu() {
    mobileDialog.current?.close();
  }

  function handleMobileMenuClose() {
    if (!menuOwnsScrollLock.current) return;
    document.body.style.overflow = previousOverflow.current;
    menuOwnsScrollLock.current = false;
  }

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

      <div className="context-mobile-nav">
        <button className="context-menu-trigger" type="button" aria-haspopup="dialog" onClick={openMobileMenu}>القائمة <span aria-hidden="true">☰</span></button>
        <dialog className="context-mobile-dialog" ref={mobileDialog} aria-label="قائمة التنقل"
          onClose={handleMobileMenuClose}
          onClick={(event) => {
            const bounds = event.currentTarget.getBoundingClientRect();
            if (event.clientX < bounds.left || event.clientX > bounds.right) closeMobileMenu();
          }}>
          <div className="context-dialog-heading"><strong>التنقل</strong><button type="button" autoFocus onClick={closeMobileMenu} aria-label="إغلاق القائمة">×</button></div>
          <nav aria-label="التنقل في المنصة">
            <Link href={homeHref} aria-current={pathname === homeHref ? 'page' : undefined} onClick={closeMobileMenu}>{homeLabel}</Link>
            {allLinks.map((item) => <Link key={item.href} href={item.href} aria-current={pathname === item.href || pathname.startsWith(`${item.href}/`) ? 'page' : undefined}
              onClick={closeMobileMenu}>{item.label}</Link>)}
            <form action={signOutAction}><button type="submit">تسجيل الخروج</button></form>
          </nav>
        </dialog>
      </div>
    </header>
  );
}
