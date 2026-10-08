import { uuid } from './rules';

export type OvertimeCursor = { operational_date: string; employee_code: string; work_instance_id: string };
export type OvertimeItem = OvertimeCursor & { unclassified_count: number; unclassified_minutes: number; reconciliation_required: boolean };
export type OvertimeNoticeData = {
  totals: { instances: number; minutes: number; reconciliation_required: number };
  items: OvertimeItem[]; has_more: boolean; next_cursor: OvertimeCursor | null;
};
type Period = { id: string; starts_on: string; ends_on: string };
const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const integer = (value: unknown): value is number => typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
function date(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
}
function cursor(value: unknown, period: Period): value is OvertimeCursor {
  return object(value) && date(value.operational_date) && value.operational_date >= period.starts_on && value.operational_date <= period.ends_on && typeof value.employee_code === 'string' && value.employee_code.length > 0 && value.employee_code.length <= 64 && typeof value.work_instance_id === 'string' && uuid(value.work_instance_id);
}
export function readOvertimeCursor(query: Record<string, string | undefined>, period: Period): OvertimeCursor | null | 'invalid' {
  const values = [query.overtime_date, query.overtime_code, query.overtime_instance];
  if (values.every(value => value === undefined)) return null;
  const value = { operational_date: values[0], employee_code: values[1], work_instance_id: values[2] };
  return cursor(value, period) ? value : 'invalid';
}
export function readOvertimeNotice(value: unknown, period: Period): OvertimeNoticeData | null {
  if (!object(value) || value.contract_version !== 1 || !object(value.period) || value.period.id !== period.id || value.period.starts_on !== period.starts_on || value.period.ends_on !== period.ends_on || !object(value.totals) || !Array.isArray(value.items) || value.items.length > 20 || typeof value.has_more !== 'boolean') return null;
  const totals = value.totals;
  if (!integer(totals.instances) || !integer(totals.minutes) || !integer(totals.reconciliation_required) || totals.reconciliation_required > totals.instances || totals.instances < value.items.length) return null;
  const items: OvertimeItem[] = [];
  const ids = new Set<string>();
  for (const item of value.items) {
    if (!object(item)) return null;
    const { unclassified_count, unclassified_minutes, reconciliation_required } = item;
    if (!integer(unclassified_count) || unclassified_count === 0 || !integer(unclassified_minutes) || typeof reconciliation_required !== 'boolean' || !cursor(item, period) || ids.has(item.work_instance_id)) return null;
    ids.add(item.work_instance_id);
    items.push({ ...item, unclassified_count, unclassified_minutes, reconciliation_required });
  }
  const last = items.at(-1);
  if (value.has_more && (!last || !cursor(value.next_cursor, period) || value.next_cursor.work_instance_id !== last.work_instance_id || value.next_cursor.employee_code !== last.employee_code || value.next_cursor.operational_date !== last.operational_date)) return null;
  if (!value.has_more && value.next_cursor !== null) return null;
  if (totals.instances === 0 && (totals.minutes !== 0 || totals.reconciliation_required !== 0 || items.length > 0 || value.has_more)) return null;
  return { totals: { instances: totals.instances, minutes: totals.minutes, reconciliation_required: totals.reconciliation_required }, items, has_more: value.has_more, next_cursor: value.has_more ? value.next_cursor as OvertimeCursor : null };
}
