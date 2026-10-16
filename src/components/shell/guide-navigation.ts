import type { WorkspaceLink } from './navigation-model';

/** Resolve fresh task recommendations only when help is opened. */
export function guideHref(mode: 'operator' | 'tenant', links: WorkspaceLink[], homeHref?: string) {
  if (mode === 'operator') return '/guide?workspace=operator';
  const tenant = [homeHref, ...links.map(link => link.href)].map(href => /^\/tenant\/([0-9a-f-]{36})(?:\/|$)/i.exec(href ?? '')?.[1]).find(Boolean);
  return tenant ? `/guide?tenant=${tenant}` : '/user-guide.html';
}
