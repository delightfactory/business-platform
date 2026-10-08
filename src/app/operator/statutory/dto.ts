import type { NumericRules } from './NumericRules';
import type { Source } from './DraftForm';
import type { ReleaseStatus } from './comparisons/IssuanceStatus';

export const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
const text = (value: unknown): value is string => typeof value === 'string';
const integer = (value: unknown, minimum = 0): value is number =>
  typeof value === 'number' && Number.isSafeInteger(value) && value >= minimum;
const id = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const sameId = (a: unknown, b: string) => id(a) && a.toLowerCase() === b.toLowerCase();
const date = (value: unknown): value is string => text(value) && value.length <= 64 && Number.isFinite(Date.parse(value));
const strings = (value: Record<string, unknown>, keys: string[]) => keys.every(key => text(value[key]));
const sources = (value: unknown): value is Source[] => Array.isArray(value) &&
  value.every(item => record(item) && strings(item, ['title', 'url']));

export function numericRules(value: unknown): value is NumericRules | null {
  if (value === null) return true;
  if (!record(value) || !record(value.tax) || !record(value.insurance) || typeof value.base_taxable !== 'boolean') return false;
  const { tax, insurance } = value;
  return strings(tax, ['treatment', 'exemption']) && (tax.column_basis === 'annual_raw' || tax.column_basis === 'annual_floor10') &&
    Array.isArray(tax.columns) && tax.columns.every(column => record(column) && text(column.through) &&
      Array.isArray(column.bands) && column.bands.every(band => record(band) && strings(band, ['upper', 'rate']))) &&
    strings(insurance, ['category', 'minimum', 'maximum']) && Array.isArray(insurance.branches) &&
    insurance.branches.every(branch => record(branch) && strings(branch, ['branch', 'employee', 'employer']) && typeof branch.deductible === 'boolean') &&
    (value.earning_partition_rounding === undefined || text(value.earning_partition_rounding)) &&
    (value.labour_deduction_adapter === undefined || text(value.labour_deduction_adapter));
}

export type DraftHead = { id: string; version: string; revision: number; created_at: string };
export type DraftVersion = { head_id: string; revision: number; effective_from: string; effective_until: string | null; source_references: Source[]; reason: string; created_at: string; numeric_rules: NumericRules | null };
export type SelectedWorkspace = { head: DraftHead; current: DraftVersion; history: DraftVersion[]; next_before_revision: number | null };
export type ListWorkspace = { items: (DraftHead & Pick<DraftVersion, 'effective_from' | 'effective_until'>)[]; next: { created: string; id: string } | null };
const head = (value: unknown): value is DraftHead => record(value) && id(value.id) &&
  text(value.version) && integer(value.revision, 1) && date(value.created_at);
const dates = (value: Record<string, unknown>) => date(value.effective_from) &&
  (value.effective_until === null || date(value.effective_until));
const version = (value: unknown): value is DraftVersion => record(value) && id(value.head_id) &&
  integer(value.revision, 1) && dates(value) && date(value.created_at) && text(value.reason) &&
  sources(value.source_references) && numericRules(value.numeric_rules);

export function selectedWorkspace(value: unknown, requested: string): { value: SelectedWorkspace | null; stale: boolean } {
  if (!record(value) || !head(value.head) || !sameId(value.head.id, requested) || !version(value.current) ||
      !sameId(value.current.head_id, requested) || !Array.isArray(value.history) ||
      !value.history.every(item => version(item) && sameId(item.head_id, requested)) ||
      !(value.next_before_revision === null || integer(value.next_before_revision, 1))) return { value: null, stale: false };
  const currentRevision = value.head.revision;
  if (value.current.revision !== currentRevision || value.history.some(item => item.revision > currentRevision)) return { value: null, stale: true };
  return { value: value as SelectedWorkspace, stale: false };
}

export function listWorkspace(value: unknown): ListWorkspace | null {
  if (!record(value) || !Array.isArray(value.items) || !value.items.every(item => head(item) && dates(item)) ||
      !(value.next === null || (record(value.next) && date(value.next.created) && id(value.next.id)))) return null;
  return value as ListWorkspace;
}

export function releaseStatus(value: unknown, revision: number): ReleaseStatus | null {
  if (!record(value) || value.revision !== revision || !text(value.evidence_stamp) || !/^[a-f0-9]{32}$/.test(value.evidence_stamp) ||
      typeof value.ready !== 'boolean' || !Array.isArray(value.blockers) || !value.blockers.every(text) ||
      !Array.isArray(value.missing_coverage) || !value.missing_coverage.every(item => record(item) && integer(item.year) && text(item.scenario)) ||
      !integer(value.total) || !integer(value.official) || value.official > value.total ||
      !(value.issued_pack === null || id(value.issued_pack)) || value.qualification_scope !== 'tax_insurance' || value.financially_qualified !== false) return null;
  if (value.ready && (value.blockers.length || value.missing_coverage.length)) return null;
  return value as ReleaseStatus;
}

export type ComparisonRow = { id: number; revision: number; created_at: string; case_data: unknown; result: unknown };
export type ComparisonHistory = { rows: ComparisonRow[]; next: number | null; current_revision: number };
export function comparisonHistory(value: unknown): ComparisonHistory | null {
  if (!record(value) || !integer(value.current_revision, 1) || !Array.isArray(value.rows) ||
      !value.rows.every(row => record(row) && integer(row.id, 1) && integer(row.revision, 1) && date(row.created_at)) ||
      !(value.next === null || integer(value.next, 1))) return null;
  return value as ComparisonHistory;
}

export function draftReceipt(value: unknown, capturedHead: string, capturedRevision: number): value is { head: string; revision: number; state: 'unqualified' } {
  return record(value) && id(value.head) && integer(value.revision, 1) && value.state === 'unqualified' &&
    (!capturedHead || (sameId(value.head, capturedHead) && value.revision > capturedRevision));
}

export function issueReceipt(value: unknown, capturedRevision: number): boolean {
  return record(value) && id(value.pack) && value.revision === capturedRevision &&
    value.qualification_scope === 'tax_insurance' && value.financially_qualified === false;
}

export function safeSourceUrl(value: string): boolean {
  try { return new URL(value).protocol === 'https:'; } catch { return false; }
}
