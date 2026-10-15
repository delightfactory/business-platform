import type { SupabaseClient } from '@supabase/supabase-js';

type Period = { id: string; starts_on: string; ends_on: string };

// A period outside the first page can be valid historical context. Verify it through
// the existing actor-scoped workspace and seek its bounded period-list page.
export async function validatePayrollPeriod(client: SupabaseClient, tenant: string, employer: string,
  requested: string, listed: readonly Period[], mode: 'run' | 'input' = 'run'): Promise<'valid' | 'invalid' | 'unavailable'> {
  if (listed.some(period => period.id === requested)) return 'valid';
  const scope = { p_tenant: tenant, p_employer: employer };
  const candidate = await client.rpc(mode === 'input' ? 'payroll_input_workspace' : 'payroll_run_workspace', {
    ...scope, p_period: requested, p_limit: 1,
  });
  if (candidate.error) return ['42501','22023'].includes(candidate.error.code) ? 'invalid' : 'unavailable';
  const period = candidate.data?.period;
  if (period?.id !== requested || typeof period.ends_on !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(period.ends_on)) return 'unavailable';
  const end = new Date(`${period.ends_on}T00:00:00Z`);
  if (!Number.isFinite(end.getTime())) return 'unavailable';
  end.setUTCDate(end.getUTCDate() + 1);
  const page = await client.rpc(mode === 'input' ? 'payroll_input_periods' : 'payroll_run_periods', {
    ...scope, p_before: end.toISOString().slice(0,10),
  });
  if (page.error || !Array.isArray(page.data)) return 'unavailable';
  return page.data.some(item => item.id === requested) ? 'valid' : 'invalid';
}
