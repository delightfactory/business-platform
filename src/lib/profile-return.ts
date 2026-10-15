import { safeReturn } from './return-to';

export function workPolicyCatalogUrl(tenantId: string, employeeId: unknown, rawReturn: unknown): string {
  const path = `/tenant/${tenantId}/people/work-policies`;
  if (typeof employeeId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(employeeId)) return path;
  const query = new URLSearchParams({ employeeId });
  const returnTo = safeReturn(tenantId, rawReturn);
  if (returnTo) query.set('profileReturn', returnTo);
  return `${path}?${query}`;
}

/** Carry navigation context only to this profile; destination permissions remain authoritative. */
export function profileReturnUrl(tenantId: string, employeeId: string, destination: string, rawReturn: unknown): string {
  const returnTo = safeReturn(tenantId, rawReturn);
  if (!returnTo) return destination;
  const origin = 'https://workspace.invalid', profile = `/tenant/${tenantId}/people/${employeeId}`;
  const target = new URL(destination, origin);
  if (target.origin !== origin) return destination;
  if (target.pathname === '/auth/login') {
    const next = target.searchParams.get('next');
    if (!next) return destination;
    const nested = new URL(next, origin);
    if (nested.origin !== origin || nested.pathname !== profile) return destination;
    nested.searchParams.set('return', returnTo);
    target.searchParams.set('next', nested.pathname + nested.search + nested.hash);
  } else {
    if (target.pathname !== profile) return destination;
    target.searchParams.set('return', returnTo);
  }
  return target.pathname + target.search + target.hash;
}
