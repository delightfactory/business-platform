import type { WorkspaceLink } from './navigation-model';

/** Personalize public training material from destinations already authorized by the server. */
export function guideHref(mode: 'operator' | 'tenant', links: WorkspaceLink[]) {
  const topics = new Set<string>();
  if (mode === 'operator') topics.add('operator');
  else for (const { href } of links) {
    const route = href.split(/[?#]/)[0].replace(/^\/tenant\/[^/]+\/?/, '');
    if (/^(users|entities-sites|branding)(\/|$)/.test(route)) topics.add('company');
    if (/^people(\/|$)/.test(route)) topics.add('people');
    if (/^attendance(\/|$)/.test(route)) topics.add('attendance');
    if (/^leave(\/|$)/.test(route)) topics.add('leave');
    if (/^payroll(\/|$)/.test(route)) topics.add('payroll');
    if (route === 'me') topics.add('profile');
    if (route === 'me/attendance') topics.add('self-attendance');
    if (/^me\/leave(\/|$)/.test(route)) topics.add('self-leave');
  }
  // An account awaiting services still needs first-login and help instructions.
  return `/user-guide.html?topics=${[...topics].join(',') || 'profile'}`;
}
