'use client';

import Image from 'next/image';
import Link, { useLinkStatus } from 'next/link';
import { usePathname, useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useId, useRef, useState } from 'react';
import { useFormStatus } from 'react-dom';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { signOutAction } from '@/app/auth/actions';
import { ThemePreferenceControl } from '@/components/theme-preference';
import { Icon, type IconName } from '@/components/ui/icon';
import { currentWorkspaceLocation, payrollDestination, workspaceMenu, type WorkspaceLink, type WorkspaceMenu } from './navigation-model';
import { guideHref } from './guide-navigation';
import styles from './workspace-navigation.module.css';

export type WorkspaceNavigationProps = {
  homeHref: string; homeLabel: string; contextLabel: string; links: WorkspaceLink[];
  businessLinks: WorkspaceLink[]; mode: 'operator' | 'tenant'; logoUrl?: string | null;
  switchHref?: string; switchLabel?: string;
};

function Progress() {
  const { pending } = useLinkStatus();
  return pending ? <span className="workspace-link-loading" role="status" aria-label="جارٍ فتح الصفحة" /> : null;
}

function SignOutMenuItem() {
  const { pending } = useFormStatus();
  // Keep the form mounted until its native submission reaches the server.
  return <DropdownMenu.Item asChild onSelect={event => event.preventDefault()} disabled={pending}>
    <button type="submit" disabled={pending} aria-busy={pending}>
      {pending ? 'جارٍ الخروج…' : 'تسجيل الخروج'}
    </button>
  </DropdownMenu.Item>;
}

function NavLink({ item, current, icon, closeCurrent }: { item: WorkspaceLink; current: boolean; icon?: IconName; closeCurrent?: () => void }) {
  return <Link className={styles.navLink} href={item.href} prefetch={/^\/tenant\/[^/]+\/attendance(?:\?|$)/.test(item.href) ? false : undefined} aria-current={current ? 'page' : undefined} onNavigate={() => {
    if (new URL(item.href, window.location.href).href === window.location.href) closeCurrent?.();
  }}>
    {icon && <Icon name={icon} size={20} />}<span>{item.label}</span><Progress />
  </Link>;
}

function NavigationTree({menu,activeHref,activeArea,closeCurrent,settingsHref,settingsCurrent=false}:{menu:WorkspaceMenu;activeHref?:string;activeArea?:string;closeCurrent:()=>void;settingsHref?:string;settingsCurrent?:boolean}) {
  const link=(item:WorkspaceLink,icon?:IconName)=><NavLink key={item.href} item={item} icon={icon} current={activeHref===item.href} closeCurrent={closeCurrent}/>;
  return <>
    {link({...menu.areas[0].destination,label:menu.areas[0].label},menu.areas[0].icon)}
    {menu.areas.length>1 && <p className={styles.sectionLabel}>العمل اليومي</p>}
    {menu.areas.slice(1).map(area=><NavLink key={area.key} item={{...area.destination,label:area.label}} icon={area.icon} current={activeArea===area.key} closeCurrent={closeCurrent}/>)}
    {settingsHref ? <section className={styles.personal}><NavLink item={{href:settingsHref,label:'الإعدادات'}} icon="settings" current={settingsCurrent||menu.settings.some(item=>item.href===activeHref)} closeCurrent={closeCurrent}/></section> : menu.settings.length>0&&<section className={styles.personal}>{menu.settings.map(item=>link(item,'settings'))}</section>}
    {menu.personal.length>0 && <section className={styles.personal}><h3 className={styles.sectionLabel}>حسابي</h3>{menu.personal.map(item=>link(item))}</section>}
  </>;
}

export function WorkspaceNavigation(props: WorkspaceNavigationProps) {
  return <Suspense fallback={<WorkspaceNavigationView {...props} employer={null} query="" />}><NavigationWithContext {...props} /></Suspense>;
}

function NavigationWithContext(props: WorkspaceNavigationProps) {
  const search = useSearchParams();
  return <WorkspaceNavigationView {...props} employer={search.get('employer')} query={search.toString()} />;
}

function WorkspaceNavigationView({ homeHref, homeLabel, contextLabel, links: originalLinks, businessLinks: originalBusinessLinks, mode, logoUrl, switchHref, switchLabel, employer, query }: WorkspaceNavigationProps & { employer: string | null; query: string }) {
  const pathname = usePathname();
  const contextual = (item: WorkspaceLink) => ({ ...item, href: payrollDestination(pathname, item.href, employer, new URLSearchParams(query).get('period')) });
  const links = originalLinks.map(contextual);
  const businessLinks = originalBusinessLinks.map(contextual);
  const profile = mode === 'tenant' ? businessLinks.find(item => item.href.endsWith('/me')) : undefined;
  const menu = workspaceMenu(homeHref, businessLinks, links, mode);
  const areas = menu.areas;
  const personalHome = mode === 'tenant' && homeHref.endsWith('/me');
  const { active, area: activeArea } = currentWorkspaceLocation(pathname, homeHref, menu, mode);
  const settingsHref = mode==='tenant' && menu.settings.length>0 ? `${homeHref.replace(/\/me$/,'')}/settings` : undefined;
  const settingsCurrent = pathname===settingsHref;
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
  useEffect(() => { dialog.current?.close(); }, [pathname, query]);
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
    {logoUrl ? <Image src={logoUrl} alt="" width={36} height={36} unoptimized className={styles.logo} />
      : <span className={`${styles.logo} ${styles.monogram}`} aria-hidden="true">{contextLabel.trim().slice(0,1) || 'م'}</span>}
    <span className={styles.identityText}><strong>منصة الأعمال</strong><small><bdi>{contextLabel}</bdi></small></span>
  </>;
  const tree = <NavigationTree menu={menu} activeHref={active?.href} activeArea={activeArea?.key} closeCurrent={() => dialog.current?.close()} settingsHref={settingsHref} settingsCurrent={settingsCurrent}/>;
  const manual = guideHref(mode, [...originalLinks, ...originalBusinessLinks], homeHref);

  return <div className={styles.navigation}>
    <a className="workspace-skip-link" href="#workspace-content">تخطَّ إلى المحتوى</a>
    <aside className={styles.sidebar} aria-label="قائمة مساحة العمل">
      <Link className={styles.identity} href={homeHref} aria-label={`${homeLabel}، الرئيسية`}>{identity}</Link>
      <nav className={styles.tree} aria-label="التنقل الرئيسي">{tree}</nav>
      <a className={styles.guide} href={manual} target="_blank" rel="noopener"><Icon name="help" size={18}/>دليل الاستخدام والتدريب<Icon name="arrowLeft" size={16}/></a>
    </aside>
    <header className={styles.header}>
      <button className={styles.menuTrigger} type="button" onClick={showMore} aria-label="فتح قائمة مساحة العمل" aria-haspopup="dialog" aria-expanded={open} aria-controls={id}><Icon name="menu"/></button>
      <div className={styles.context}><span>{mode === 'operator' ? 'إدارة المنصة' : <bdi>{contextLabel}</bdi>}</span><Icon name="chevronLeft" size={14}/><strong>{settingsCurrent?'الإعدادات':activeArea?.label??active?.label??'مساحة العمل'}</strong></div>
      <DropdownMenu.Root><DropdownMenu.Trigger className="workspace-account-trigger" aria-label="الحساب والمظهر">
        <span className="workspace-account-avatar" aria-hidden="true"><Icon name={'user'} size={20} /></span><span className="workspace-account-caption">حسابي</span>
      </DropdownMenu.Trigger><DropdownMenu.Portal><DropdownMenu.Content className="workspace-account-menu" sideOffset={10} align="end">
        <DropdownMenu.Label className="workspace-account-label"><bdi>{contextLabel}</bdi><small>{mode === 'operator' ? 'تشغيل المنصة' : 'مساحة الشركة'}</small></DropdownMenu.Label>
        {switchHref && switchLabel && <DropdownMenu.Item asChild><Link href={switchHref}>{switchLabel}</Link></DropdownMenu.Item>}
        {profile && <>
          {!personalHome && <DropdownMenu.Item asChild><Link href={profile.href}>يومي</Link></DropdownMenu.Item>}
          <DropdownMenu.Item asChild><Link href={`${profile.href}#my-employee-heading`}>ملفي</Link></DropdownMenu.Item>
        </>}
        {mode === 'operator' && <DropdownMenu.Item asChild><Link href="/">مساحات العمل</Link></DropdownMenu.Item>}
        <DropdownMenu.Item asChild><a href={manual} target="_blank" rel="noopener">دليل الاستخدام والتدريب</a></DropdownMenu.Item>
        <ThemePreferenceControl menu />
        <DropdownMenu.Separator />
        <form action={signOutAction}><SignOutMenuItem /></form>
      </DropdownMenu.Content></DropdownMenu.Portal></DropdownMenu.Root>
    </header>
    {offline && <div className={styles.offline} role="status">الاتصال منقطع. يمكنك مراجعة ما هو ظاهر؛ أعد الاتصال قبل إرسال أي إجراء.</div>}
    <nav className={styles.bottomTabs} aria-label="التنقل السريع">{areas.slice(0,4).map(area => <NavLink key={area.key} item={{...area.destination,label:area.label}} icon={area.icon} current={activeArea?.key===area.key}/>)}
      <button type="button" onClick={showMore} aria-label="عرض قائمة مساحة العمل" aria-haspopup="dialog" aria-expanded={open} aria-controls={id}><Icon name="menu" size={22}/><span>القائمة</span></button>
    </nav>
    <dialog ref={dialog} id={id} className={styles.menuDialog} aria-label="قائمة مساحة العمل" onClose={closed} onClick={event => {if(event.target===event.currentTarget)dialog.current?.close();}}>
      <div className={styles.dialogHeading}><div><small>{mode==='operator'?'تشغيل المنصة':'مساحة الشركة'}</small><h2><bdi>{contextLabel}</bdi></h2></div><button type="button" onClick={() => dialog.current?.close()} aria-label="إغلاق القائمة"><Icon name="close"/></button></div>
      <nav className={styles.tree} aria-label="كل الأقسام"><NavigationTree menu={menu} activeHref={active?.href} activeArea={activeArea?.key} closeCurrent={() => dialog.current?.close()} settingsHref={settingsHref} settingsCurrent={settingsCurrent}/></nav>
      <a className={styles.guide} href={manual} target="_blank" rel="noopener"><Icon name="help" size={18}/>دليل الاستخدام والتدريب</a>
    </dialog>
  </div>;
}
