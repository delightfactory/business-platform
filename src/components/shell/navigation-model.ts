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
