'use client';

import Image from 'next/image';
import Link, { useLinkStatus } from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useId, useRef, useState } from 'react';
import { signOutAction } from '@/app/auth/actions';
import { ThemePreferenceControl } from '@/components/theme-preference';

export type ContextLink = { href: string; label: string; mobilePriority?: number };

type Props = {
  homeHref: string;
  homeLabel: string;
  contextLabel: string;
  links: ContextLink[];
  businessLinks: ContextLink[];
  mode: 'operator' | 'tenant';
  logoUrl?: string | null;
  switchHref?: string;
  switchLabel?: string;
};

function LinkProgress() {
  const { pending } = useLinkStatus();
  return <>
    <span className={`workspace-link-progress${pending ? ' is-pending' : ''}`} aria-hidden="true" />
    {pending && <span className="workspace-link-loading" role="status" aria-label="جارٍ فتح الصفحة" />}
  </>;
}

function WorkspaceLink({ item, pathname, currentHref, onClick, exact = false }: {
  item: ContextLink;
  pathname: string;
  currentHref?: string;
  onClick?: () => void;
  exact?: boolean;
}) {
  const current = currentHref ? currentHref === item.href : pathname === item.href || (!exact && pathname.startsWith(`${item.href}/`));
  return <Link href={item.href} aria-current={current ? 'page' : undefined} onClick={onClick}>
    <span>{item.label}</span><LinkProgress />
  </Link>;
}

export function ContextNavigationClient({
  homeHref, homeLabel, contextLabel, links, businessLinks, mode, logoUrl, switchHref, switchLabel,
}: Props) {
  const pathname = usePathname();
  const mobileDialog = useRef<HTMLDialogElement>(null);
  const mobileDialogId = useId();
  const [menuOpen, setMenuOpen] = useState(false);
  const previousOverflow = useRef('');
  const menuOwnsScrollLock = useRef(false);
  const homeLink = { href: homeHref, label: 'الرئيسية' };
  const allLinks = [...businessLinks, ...links];
  const activeLink = allLinks.filter((item) => pathname === item.href || pathname.startsWith(`${item.href}/`))
    .sort((left, right) => right.href.length - left.href.length)[0];
  const currentHref = pathname === homeHref ? homeHref : activeLink?.href;
  const pageTitle = pathname === homeHref ? 'الرئيسية' : activeLink?.label ?? contextLabel;
  const primaryLinks = [...(mode === 'tenant' && businessLinks.length > 0 ? businessLinks : links)]
    .sort((left, right) => (left.mobilePriority ?? 100) - (right.mobilePriority ?? 100)).slice(0, 2);

  useEffect(() => {
    if (mobileDialog.current?.open) mobileDialog.current.close();
  }, [pathname]);
  useEffect(() => {
    const mobile = window.matchMedia('(max-width: 900px)');
    const closeForDesktop = () => {
      if (!mobile.matches && mobileDialog.current?.open) mobileDialog.current.close();
    };
    mobile.addEventListener('change', closeForDesktop);
    return () => mobile.removeEventListener('change', closeForDesktop);
  }, []);
  useEffect(() => () => {
    if (menuOwnsScrollLock.current) document.body.style.overflow = previousOverflow.current;
  }, []);

  function openMobileMenu() {
    const dialog = mobileDialog.current;
    if (!dialog || dialog.open) return;
    previousOverflow.current = document.body.style.overflow;
    dialog.showModal();
    document.body.style.overflow = 'hidden';
    menuOwnsScrollLock.current = true;
    setMenuOpen(true);
  }

  function closeMobileMenu() {
    mobileDialog.current?.close();
  }

  function handleMobileMenuClose() {
    if (menuOwnsScrollLock.current) document.body.style.overflow = previousOverflow.current;
    menuOwnsScrollLock.current = false;
    setMenuOpen(false);
  }

  const identity = <>
    {logoUrl ? <Image src={logoUrl} alt="" width={36} height={36} unoptimized className="workspace-logo" />
      : <span className="workspace-logo workspace-monogram" aria-hidden="true">م</span>}
    <span className="workspace-identity-text"><small>{mode === 'operator' ? 'إدارة المنصة' : homeLabel}</small><bdi>{mode === 'operator' ? homeLabel : contextLabel}</bdi></span>
  </>;

  return <div className="workspace-navigation">
    <aside className="workspace-sidebar" aria-label="التنقل الرئيسي">
      <Link className="workspace-identity" href={homeHref} aria-label={`${homeLabel}، الرئيسية`}>{identity}</Link>
      {mode === 'operator' && <span className="workspace-mode">وضع المشغّل</span>}
      <nav className="workspace-sidebar-links" aria-label="أقسام مساحة العمل">
        <WorkspaceLink item={homeLink} pathname={pathname} currentHref={currentHref} exact />
        {businessLinks.length > 0 && <div className="workspace-nav-group">
          <p>مجالات العمل</p>
          {businessLinks.map((item) => <WorkspaceLink key={item.href} item={item} pathname={pathname} currentHref={currentHref} />)}
        </div>}
        {links.length > 0 && <div className="workspace-nav-group">
          <p>{mode === 'operator' ? 'تشغيل المنصة' : 'إدارة الشركة'}</p>
          {links.map((item) => <WorkspaceLink key={item.href} item={item} pathname={pathname} currentHref={currentHref} />)}
        </div>}
      </nav>
      <div className="workspace-sidebar-footer">
        <ThemePreferenceControl />
        {switchHref && switchLabel && <WorkspaceLink item={{ href: switchHref, label: switchLabel }} pathname={pathname} currentHref={currentHref} />}
        <form action={signOutAction}><button type="submit">تسجيل الخروج</button></form>
      </div>
    </aside>

    <header className="workspace-mobile-header">
      <Link className="workspace-mobile-identity" href={homeHref} aria-label={`${homeLabel}، الرئيسية`}>{identity}</Link>
      <span className="workspace-mobile-location"><bdi>{pageTitle}</bdi></span>
      <button type="button" className="workspace-mobile-menu-button" onClick={openMobileMenu}
        aria-label="فتح قائمة التنقل" aria-haspopup="dialog" aria-expanded={menuOpen} aria-controls={mobileDialogId}>
        <span aria-hidden="true">☰</span>
      </button>
    </header>

    <nav className="workspace-mobile-tabs" aria-label="التنقل السريع">
      <WorkspaceLink item={homeLink} pathname={pathname} currentHref={currentHref} exact />
      {primaryLinks.map((item) => <WorkspaceLink key={item.href} item={item} pathname={pathname} currentHref={currentHref} />)}
      <button type="button" onClick={openMobileMenu} aria-label="عرض كل الأقسام" aria-haspopup="dialog" aria-expanded={menuOpen} aria-controls={mobileDialogId}>
        <span aria-hidden="true">☰</span><span>المزيد</span>
      </button>
    </nav>

    <dialog className="workspace-mobile-dialog" id={mobileDialogId} ref={mobileDialog} aria-label="قائمة أقسام المنصة"
      onClose={handleMobileMenuClose}
      onClick={(event) => {
        if (event.target === event.currentTarget) closeMobileMenu();
      }}>
      <div className="workspace-dialog-heading">
        <span>{mode === 'operator' ? 'تشغيل المنصة' : contextLabel}</span>
        <button type="button" onClick={closeMobileMenu} aria-label="إغلاق القائمة">×</button>
      </div>
      <nav aria-label="كل الأقسام">
        <WorkspaceLink item={homeLink} pathname={pathname} currentHref={currentHref} onClick={closeMobileMenu} exact />
        {businessLinks.length > 0 && <div className="workspace-dialog-group"><p>مجالات العمل</p>
          {businessLinks.map((item) => <WorkspaceLink key={item.href} item={item} pathname={pathname} currentHref={currentHref} onClick={closeMobileMenu} />)}
        </div>}
        {links.length > 0 && <div className="workspace-dialog-group"><p>{mode === 'operator' ? 'تشغيل المنصة' : 'إدارة الشركة'}</p>
          {links.map((item) => <WorkspaceLink key={item.href} item={item} pathname={pathname} currentHref={currentHref} onClick={closeMobileMenu} />)}
        </div>}
        {switchHref && switchLabel && <WorkspaceLink item={{ href: switchHref, label: switchLabel }} pathname={pathname} currentHref={currentHref} onClick={closeMobileMenu} />}
        <ThemePreferenceControl />
        <form action={signOutAction}><button type="submit">تسجيل الخروج</button></form>
      </nav>
    </dialog>
  </div>;
}
