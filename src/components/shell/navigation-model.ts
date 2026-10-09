import type { IconName } from '@/components/ui/icon';
export type WorkspaceLink = { href: string; label: string; mobilePriority?: number };
export type NavArea = { key: string; label: string; icon: IconName; destination: WorkspaceLink; links: WorkspaceLink[] };

// Group only links already authorized by the server. No destination is invented.
export function workspaceAreas(homeHref: string, business: WorkspaceLink[], admin: WorkspaceLink[], mode: 'tenant' | 'operator'): NavArea[] {
  const areas: NavArea[] = [{ key: 'today', label: mode === 'tenant' ? 'اليوم' : 'نظرة عامة', icon: 'home', destination: { href: homeHref, label: 'اليوم' }, links: [] }];
  const add = (key: string, label: string, icon: IconName, links: WorkspaceLink[]) => {
    if (links.length) areas.push({ key, label, icon, destination: links[0], links });
  };
  if (mode === 'operator') {
    add('companies', 'الشركات', 'building', admin.filter(item => /\/tenants(?:\/|$)/.test(item.href)));
    add('onboarding', 'إعداد الشركات', 'users', admin.filter(item => /\/(onboarding|invitations)(?:\/|$)/.test(item.href)));
    add('commercial', 'الاشتراكات', 'wallet', admin.filter(item => /\/(commercial|entitlements)(?:\/|$)/.test(item.href)));
  } else {
    const team = business.some(item => /\/(people|attendance|leave|payroll)(?:\/|\?|$)/.test(item.href) && !item.href.includes('/me/'));
    if (team) {
      add('people', 'الناس', 'users', business.filter(item => item.href.includes('/people')));
      add('time', 'الوقت', 'clock', business.filter(item => !item.href.includes('/me/') && /\/(attendance|leave)(?:\/|$)/.test(item.href)).sort((a,b) => a.href.length-b.href.length));
      add('payroll', 'الرواتب', 'wallet', business.filter(item => item.href.includes('/payroll')).sort((a,b) => a.href.length-b.href.length));
    } else {
      // Self-service destinations remain available even when the employee has no HR access.
      const attendance = business.filter(item => item.href.endsWith('/me/attendance'));
      if (attendance.length) areas[0] = { key: 'today', label: 'يومي', icon: 'home', destination: attendance[0], links: attendance };
      add('leave', 'إجازاتي', 'calendar', business.filter(item => item.href.includes('/me/leave')));
      add('profile', 'ملفي', 'user', business.filter(item => item.href.endsWith('/me')));
    }
  }
  return areas;
}

export function matchesDestination(path: string, href: string) {
  const target = href.split(/[?#]/)[0];
  return path === target || path.startsWith(`${target}/`);
}

/** Carry only the selected employer between authorized links in the same payroll workspace. */
export function payrollDestination(pathname: string, href: string, employer: string | null) {
  if (!employer || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(employer)) return href;
  const base = pathname.match(/^(\/tenant\/[^/]+\/payroll)(?:\/|$)/)?.[1];
  const [destination, hash] = href.split('#', 2);
  const [target, query] = destination.split('?', 2);
  if (!base || (target !== base && !target.startsWith(`${base}/`))) return href;
  const params = new URLSearchParams(query);
  if (params.has('employer')) return href;
  params.set('employer', employer);
  return `${target}?${params}${hash === undefined ? '' : `#${hash}`}`;
}
