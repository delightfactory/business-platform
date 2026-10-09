'use client';

import Image from 'next/image';
import Link, { useLinkStatus } from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect, useId, useRef, useState } from 'react';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { signOutAction } from '@/app/auth/actions';
import { ThemePreferenceControl } from '@/components/theme-preference';
import { Icon, type IconName } from '@/components/ui/icon';
import { matchesDestination, workspaceAreas, type WorkspaceLink, type NavArea } from './navigation-model';

export type WorkspaceNavigationProps = {
  homeHref: string; homeLabel: string; contextLabel: string; links: WorkspaceLink[];
  businessLinks: WorkspaceLink[]; mode: 'operator' | 'tenant'; logoUrl?: string | null;
  switchHref?: string; switchLabel?: string;
};

function Progress() {
  const { pending } = useLinkStatus();
  return pending ? <span className="workspace-link-loading" role="status" aria-label="جارٍ فتح الصفحة" /> : null;
}

function NavLink({ item, current, close, icon }: { item: WorkspaceLink; current: boolean; close?: () => void; icon?: IconName }) {
  return <Link href={item.href} aria-current={current ? 'page' : undefined} onClick={close}>
    {icon && <Icon name={icon} size={20} />}<span>{item.label}</span><Progress />
  </Link>;
}

export function WorkspaceNavigation({ homeHref, homeLabel, contextLabel, links, businessLinks, mode, logoUrl, switchHref, switchLabel }: WorkspaceNavigationProps) {
  const pathname = usePathname();
  const areas = workspaceAreas(homeHref, businessLinks, links, mode);
  const allLinks = [{ href: homeHref, label: mode === 'tenant' ? 'اليوم' : 'نظرة عامة' }, ...businessLinks, ...links];
  const active = allLinks.filter(item => matchesDestination(pathname, item.href)).sort((a,b) => b.href.length-a.href.length)[0];
  const activeArea = areas.find(area => area.links.some(item => matchesDestination(pathname, item.href)))
    ?? (pathname === homeHref ? areas[0] : undefined);
  const localLinks = activeArea?.links ?? [];
  const dialog = useRef<HTMLDialogElement>(null);
  const id = useId();
  const [open, setOpen] = useState(false);
  const [offline, setOffline] = useState(false);
  const previousOverflow = useRef('');
  const ownsLock = useRef(false);

  useEffect(() => {
    const sync = () => setOffline(!navigator.onLine);
    sync();
    window.addEventListener('online', sync); window.addEventListener('offline', sync);
    return () => { window.removeEventListener('online', sync); window.removeEventListener('offline', sync); };
  }, []);
  useEffect(() => { dialog.current?.close(); }, [pathname]);
  useEffect(() => () => { if (ownsLock.current) document.body.style.overflow = previousOverflow.current; }, []);

  function showMore() {
    if (!dialog.current || dialog.current.open) return;
    previousOverflow.current = document.body.style.overflow;
    dialog.current.showModal(); document.body.style.overflow = 'hidden'; ownsLock.current = true; setOpen(true);
  }
  function closed() {
    if (ownsLock.current) document.body.style.overflow = previousOverflow.current;
    ownsLock.current = false; setOpen(false);
  }
  const identity = <>
    {logoUrl ? <Image src={logoUrl} alt="" width={36} height={36} unoptimized className="workspace-logo" />
      : <span className="workspace-logo workspace-monogram" aria-hidden="true">{contextLabel.trim().slice(0,1) || 'م'}</span>}
    <span className="workspace-identity-text"><strong>منصة الأعمال</strong><small><bdi>{contextLabel}</bdi></small></span>
  </>;
  const areaLink = (area: NavArea) => <NavLink key={area.key} item={{ ...area.destination, label: area.label }} icon={area.icon} current={activeArea?.key === area.key} />;

  return <div className="workspace-navigation">
    <a className="workspace-skip-link" href="#workspace-content">تخطَّ إلى المحتوى</a>
    <header className="workspace-topbar">
      <Link className="workspace-identity" href={homeHref} aria-label={`${homeLabel}، الرئيسية`}>{identity}</Link>
      <nav className="workspace-primary-nav" aria-label="التنقل الرئيسي">{areas.map(areaLink)}
        <button type="button" onClick={showMore} aria-haspopup="dialog" aria-expanded={open} aria-controls={id}><Icon name={'more'} size={20} /><span>المزيد</span></button>
      </nav>
      <DropdownMenu.Root><DropdownMenu.Trigger className="workspace-account-trigger" aria-label="الحساب والمظهر">
        <span className="workspace-account-avatar" aria-hidden="true"><Icon name={'user'} size={20} /></span><span className="workspace-account-caption">حسابي</span>
      </DropdownMenu.Trigger><DropdownMenu.Portal><DropdownMenu.Content className="workspace-account-menu" sideOffset={10} align="end">
        <DropdownMenu.Label className="workspace-account-label"><bdi>{contextLabel}</bdi><small>{mode === 'operator' ? 'تشغيل المنصة' : 'مساحة الشركة'}</small></DropdownMenu.Label>
        {switchHref && switchLabel && <DropdownMenu.Item asChild><Link href={switchHref}>{switchLabel}</Link></DropdownMenu.Item>}
        <ThemePreferenceControl />
        <DropdownMenu.Separator />
        <form action={signOutAction}><DropdownMenu.Item asChild><button type="submit">تسجيل الخروج</button></DropdownMenu.Item></form>
      </DropdownMenu.Content></DropdownMenu.Portal></DropdownMenu.Root>
    </header>
    {offline && <div className="workspace-offline-banner" role="status">الاتصال منقطع. يمكنك مراجعة ما هو ظاهر؛ أعد الاتصال قبل إرسال أي إجراء.</div>}
    {localLinks.length > 1 && <nav className="workspace-area-tabs" aria-label={`أقسام ${activeArea?.label}`}>
      {localLinks.map(item => <NavLink key={item.href} item={item} current={active?.href === item.href} />)}
    </nav>}
    <nav className="workspace-bottom-tabs" aria-label="التنقل السريع">{areas.map(areaLink)}
      <button type="button" onClick={showMore} aria-label="عرض كل الأقسام" aria-haspopup="dialog" aria-expanded={open} aria-controls={id}><Icon name={'more'} size={22} /><span>المزيد</span></button>
    </nav>
    <dialog ref={dialog} id={id} className="workspace-more-dialog" aria-label="كل أقسام مساحة العمل" onClose={closed} onClick={event => { if (event.target === event.currentTarget) dialog.current?.close(); }}>
      <div className="workspace-dialog-heading"><h2>أقسام مساحة العمل</h2><button type="button" onClick={() => dialog.current?.close()} aria-label="إغلاق القائمة">×</button></div>
      <nav aria-label="كل الأقسام"><NavLink item={allLinks[0]} current={pathname === homeHref} close={() => dialog.current?.close()} />
        {businessLinks.length > 0 && <section><h3>العمل وخدماتي</h3>{businessLinks.map(item => <NavLink key={item.href} item={item} current={active?.href === item.href} close={() => dialog.current?.close()} />)}</section>}
        {links.length > 0 && <section><h3>{mode === 'operator' ? 'تشغيل المنصة' : 'إدارة الشركة'}</h3>{links.map(item => <NavLink key={item.href} item={item} current={active?.href === item.href} close={() => dialog.current?.close()} />)}</section>}
      </nav>
    </dialog>
  </div>;
}
