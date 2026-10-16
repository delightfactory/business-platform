import { uuid } from './rules';

/** Only a same-tenant employee profile can be the payroll return destination. */
export function payrollProfileReturn(value: string | undefined, tenant: string): string | undefined {
 if (!value || value.length > 500 || !uuid(tenant) || !value.startsWith(`/tenant/${tenant}/people/`)) return undefined;
 try {
  const url = new URL(value, 'https://workspace.invalid');
  if (url.origin !== 'https://workspace.invalid' || url.hash || url.username || url.password) return undefined;
  const prefix = `/tenant/${tenant}/people/`, employee = url.pathname.slice(prefix.length);
  if (!url.pathname.startsWith(prefix) || !uuid(employee)) return undefined;
  const tab = url.searchParams.get('tab');
  if (tab && !['overview', 'work', 'compensation', 'account', 'employment', 'attendance', 'leave', 'payroll', 'advances', 'history'].includes(tab)) return undefined;
  const activityAfter = url.searchParams.get('activityAfter');
  if (activityAfter && !uuid(activityAfter)) return undefined;
  const query = new URLSearchParams({ ...(tab ? { tab } : {}), ...(activityAfter ? { activityAfter } : {}) });
  return url.pathname + (query.size ? `?${query}` : '');
 } catch { return undefined; }
}
