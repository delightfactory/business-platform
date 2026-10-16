import type { IconName } from '@/components/ui/icon';
export type WorkspaceLink = { href: string; label: string; mobilePriority?: number };
export type NavArea = { key: string; label: string; icon: IconName; destination: WorkspaceLink; links: WorkspaceLink[] };

export function hasTeamWorkspace(links: WorkspaceLink[]) {
  return links.some(item => /\/(people|attendance|leave|payroll)(?:\/|\?|$)/.test(item.href) && !item.href.includes('/me/'));
}

const timeOrder = ['attendance', 'attendance/calendar', 'attendance/review', 'leave', 'leave/balances', 'attendance/sources', 'leave/settings'];
const payrollOrder = ['payroll', 'payroll/runs', 'payroll/inputs', 'payroll/setup', 'payroll/advances', 'payroll/reports'];
const setupOrder = ['entities-sites', 'users', 'people/organization', 'people/work-policies', 'attendance/sources', 'leave/settings', 'payroll/setup', 'branding'];
function ordered(links: WorkspaceLink[], order: string[]) {
  const rank = (href: string) => {
    const route = href.split(/[?#]/)[0].replace(/^\/tenant\/[^/]+\//, '');
    const index = order.indexOf(route);
    return index < 0 ? order.length : index;
  };
  return links.sort((a, b) => rank(a.href) - rank(b.href));
}

// Group only links already authorized by the server. No destination is invented.
export function workspaceAreas(homeHref: string, business: WorkspaceLink[], admin: WorkspaceLink[], mode: 'tenant' | 'operator'): NavArea[] {
  const areas: NavArea[] = [{ key: 'today', label: mode === 'tenant' ? 'اليوم' : 'نظرة عامة', icon: 'home', destination: { href: homeHref, label: 'اليوم' }, links: [] }];
  const add = (key: string, label: string, icon: IconName, links: WorkspaceLink[]) => {
    if (links.length) areas.push({ key, label, icon, destination: links[0], links });
  };
  if (mode === 'operator') {
    add('companies', 'الشركات', 'building', admin.filter(item => /\/(companies|tenants|commercial|entitlements)(?:\/|$)/.test(item.href)));
    add('invitations', 'الدعوات', 'mail', admin.filter(item => /\/(onboarding|invitations)(?:\/|$)/.test(item.href)));
    add('team', 'فريق التشغيل', 'users', admin.filter(item => /\/(team|operators)(?:\/|$)/.test(item.href)));
    add('statutory', 'قواعد الرواتب', 'shield', admin.filter(item => /\/statutory(?:\/|$)/.test(item.href)));
  } else {
    const team = hasTeamWorkspace(business);
    if (team) {
      add('people', 'الموظفون', 'users', business.filter(item => item.href.includes('/people')));
      add('time', 'الحضور والإجازات', 'clock', ordered(business.filter(item => !item.href.includes('/me/') && /\/(attendance|leave)(?:\/|$)/.test(item.href)), timeOrder));
      add('payroll', 'الرواتب', 'wallet', ordered(business.filter(item => item.href.includes('/payroll')), payrollOrder));
    } else {
      // Self-service destinations remain available even when the employee has no HR access.
      const attendance = business.filter(item => item.href.endsWith('/me/attendance'));
      const profile = business.find(item => item.href.endsWith('/me'));
      if (profile) areas[0] = { key: 'today', label: 'يومي', icon: 'home', destination: profile, links: [] };
      add('leave', 'إجازاتي', 'calendar', business.filter(item => item.href.includes('/me/leave')));
      add('record', 'سجلي', 'clock', attendance);
    }
  }
  return areas;
}

export type WorkspaceMenu = { areas: NavArea[]; settings: WorkspaceLink[]; personal: WorkspaceLink[] };

/** Classify the authorized set without inventing or dropping a destination. */
export function workspaceMenu(homeHref: string, business: WorkspaceLink[], admin: WorkspaceLink[], mode: 'tenant' | 'operator'): WorkspaceMenu {
  const isSetup = (href: string) => /\/(?:people\/(?:organization|work-policies)|attendance\/sources|leave\/settings|payroll\/setup|operator\/statutory)(?:\/|$)/.test(href.split(/[?#]/)[0]);
  const settings = business.filter(item => isSetup(item.href));
  const areas = workspaceAreas(homeHref, business, admin, mode).flatMap((area, index) => {
    if (index === 0) return [area];
    const links = area.links.filter(item => !isSetup(item.href));
    return links.length ? [{ ...area, destination: links[0], links }] : [];
  });
  const grouped = new Set(areas.flatMap(area => [area.destination.href, ...area.links.map(item => item.href)]));
  settings.push(...admin.filter(item => !grouped.has(item.href)));
  const settingsHrefs = new Set(settings.map(item => item.href));
  return { areas, settings: ordered(settings, setupOrder), personal: business.filter(item => !grouped.has(item.href) && !settingsHrefs.has(item.href)) };
}

export function matchesDestination(path: string, href: string) {
  const target = href.split(/[?#]/)[0];
  return path === target || path.startsWith(`${target}/`);
}

/** Resolve the deepest destination; the workspace root is never a catch-all. */
export function currentWorkspaceLocation(pathname: string, homeHref: string, menu: WorkspaceMenu, mode: 'tenant' | 'operator') {
  const candidates = [...menu.areas.flatMap(area => [area.destination, ...area.links]), ...menu.settings, ...menu.personal];
  const active = candidates.filter(item => item.href.split(/[?#]/)[0] === homeHref
    ? pathname === homeHref : matchesDestination(pathname, item.href))
    .sort((a, b) => b.href.split(/[?#]/)[0].length - a.href.split(/[?#]/)[0].length)[0];
  const isSetting = menu.settings.some(item => item.href === active?.href);
  const area = isSetting ? undefined : menu.areas.find(item => item.destination.href === active?.href || item.links.some(link => link.href === active?.href));
  if (!active && mode === 'operator' && /^\/operator\/(tenants|commercial|entitlements)(?:\/|$)/.test(pathname)) {
    const companies = menu.areas.find(item => item.key === 'companies');
    return { active: companies?.destination, area: companies };
  }
  return { active, area };
}

/** Carry explicit employer/period context; each destination still validates its own scope. */
export function payrollDestination(pathname: string, href: string, employer: string | null, period: string | null = null) {
  if (!employer || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(employer)) return href;
  const base = pathname.match(/^(\/tenant\/[^/]+\/payroll)(?:\/|$)/)?.[1];
  const [destination, hash] = href.split('#', 2);
  const [target, query] = destination.split('?', 2);
  if (!base || (target !== base && !target.startsWith(`${base}/`))) return href;
  const params = new URLSearchParams(query);
  if (params.has('employer') && params.get('employer') !== employer) return href;
  params.set('employer', employer);
  if ([base,`${base}/setup`,`${base}/inputs`,`${base}/runs`].includes(target)
    && !params.has('period') && period && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(period)) params.set('period',period);
  return `${target}?${params}${hash === undefined ? '' : `#${hash}`}`;
}
