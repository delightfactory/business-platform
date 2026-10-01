import { MAX_REASON_LENGTH, MIN_REASON_LENGTH, isObject, isUuid } from '../rules';

export const PAGE_SIZE = 50;
export const MIN_QUERY_LENGTH = 2;
export const MAX_QUERY_LENGTH = 80;
export const MIN_SOURCE_LENGTH = 1;
export const MAX_SOURCE_LENGTH = 300;

export const MIN_REASON = MIN_REASON_LENGTH;
export const MAX_REASON = MAX_REASON_LENGTH;

// leave.ledger_entries.delta_days is numeric(8,2): six integer digits and two decimals.
export const MAX_DELTA_MAGNITUDE = '999999.99';

export type PostingKind = 'opening' | 'annual_grant' | 'adjustment';

export const POSTING_KINDS: readonly PostingKind[] = ['opening', 'annual_grant', 'adjustment'];

export function isPostingKind(value: string): value is PostingKind {
  return value === 'opening' || value === 'annual_grant' || value === 'adjustment';
}

function isTextOrNull(value: unknown): value is string | null {
  return value === null || typeof value === 'string';
}

function isNumberOrNull(value: unknown): value is number | null {
  return value === null || (typeof value === 'number' && Number.isFinite(value));
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function isDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = Date.parse(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed) && new Date(parsed).toISOString().slice(0, 10) === value;
}

export type BalanceAccess = {
  canView: boolean;
  canAdjust: boolean;
  newWorkEnabled: boolean;
};

// leave_access_snapshot is only a render hint here. It exposes the raw leave_balance.adjust
// flag that the shared leave rules reader intentionally omits, and never replaces the
// authoritative RPC authorization performed by every read and by the posting command.
export function readBalanceAccess(value: unknown): BalanceAccess | null {
  if (!isObject(value)) return null;
  if (typeof value.can_view !== 'boolean' || typeof value.can_adjust !== 'boolean'
    || typeof value.new_work_enabled !== 'boolean') return null;
  return { canView: value.can_view || value.can_adjust, canAdjust: value.can_adjust, newWorkEnabled: value.new_work_enabled };
}

export type BalancePair = {
  employeeId: string;
  employeeCode: string;
  employeeName: string;
  employerId: string;
  employerName: string;
  employerIsActive: boolean;
  hasActiveEmployment: boolean;
  newWorkEnabled: boolean;
  canAdjust: boolean;
  canPost: boolean;
  postingBlockedReason: string | null;
};

function readPair(value: unknown): BalancePair | null {
  if (!isObject(value) || !isUuid(value.employee_id) || typeof value.employee_code !== 'string'
    || typeof value.employee_name !== 'string' || !isUuid(value.employer_entity_id)
    || typeof value.employer_name !== 'string' || typeof value.employer_is_active !== 'boolean'
    || typeof value.has_active_employment !== 'boolean' || typeof value.new_work_enabled !== 'boolean'
    || typeof value.can_adjust !== 'boolean' || typeof value.can_post !== 'boolean'
    || !isTextOrNull(value.posting_blocked_reason)) return null;
  return {
    employeeId: value.employee_id,
    employeeCode: value.employee_code,
    employeeName: value.employee_name,
    employerId: value.employer_entity_id,
    employerName: value.employer_name,
    employerIsActive: value.employer_is_active,
    hasActiveEmployment: value.has_active_employment,
    newWorkEnabled: value.new_work_enabled,
    canAdjust: value.can_adjust,
    canPost: value.can_post,
    postingBlockedReason: value.posting_blocked_reason,
  };
}

export type SearchCursor = { code: string; employee: string; employer: string };
export type StartCursor = { start: string; id: string };
export type CodeCursor = { code: string; id: string };
export type LedgerCursor = { createdAt: string; entryId: string };

type CursorRead<T> = { ok: boolean; cursor: T | null };

function readSearchCursor(hasMore: boolean, code: unknown, employee: unknown, employer: unknown): CursorRead<SearchCursor> {
  if (!hasMore) return { ok: true, cursor: null };
  if (typeof code !== 'string' || code === '' || code.length > 120
    || !isUuid(employee) || !isUuid(employer)) return { ok: false, cursor: null };
  return { ok: true, cursor: { code, employee, employer } };
}

function readStartCursor(hasMore: boolean, start: unknown, id: unknown, dateOnly: boolean): CursorRead<StartCursor> {
  if (!hasMore) return { ok: true, cursor: null };
  if (typeof start !== 'string' || (dateOnly ? !isDate(start) : start === '') || !isUuid(id)) {
    return { ok: false, cursor: null };
  }
  return { ok: true, cursor: { start, id } };
}

function readCodeCursor(hasMore: boolean, code: unknown, id: unknown): CursorRead<CodeCursor> {
  if (!hasMore) return { ok: true, cursor: null };
  if (typeof code !== 'string' || code === '' || code.length > 120 || !isUuid(id)) {
    return { ok: false, cursor: null };
  }
  return { ok: true, cursor: { code, id } };
}

function readLedgerCursor(hasMore: boolean, createdAt: unknown, entryId: unknown): CursorRead<LedgerCursor> {
  if (!hasMore) return { ok: true, cursor: null };
  if (typeof createdAt !== 'string' || createdAt === '' || !isUuid(entryId)) {
    return { ok: false, cursor: null };
  }
  return { ok: true, cursor: { createdAt, entryId } };
}

export type OptionsPage = {
  items: BalancePair[];
  hasMore: boolean;
  next: SearchCursor | null;
};

export function readOptionsPage(value: unknown): OptionsPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  if (value.items.length > PAGE_SIZE) return null;
  const items: BalancePair[] = [];
  for (const entry of value.items) {
    const pair = readPair(entry);
    if (!pair) return null;
    items.push(pair);
  }
  const next = readSearchCursor(value.has_more, value.next_after_code,
    value.next_after_employee, value.next_after_employer);
  if (!next.ok) return null;
  return { items, hasMore: value.has_more, next: next.cursor };
}

export type BalanceAccount = {
  accountId: string;
  employeeId: string;
  employerId: string;
  leaveTypeId: string;
  typeCode: string;
  typeName: string;
  typeIsActive: boolean;
  periodId: string;
  periodLabel: string;
  startsOn: string;
  endsOn: string;
  balanceDays: number;
  hasOpening: boolean;
  hasAnnualGrant: boolean;
};

export type AccountsPage = {
  pair: BalancePair;
  items: BalanceAccount[];
  hasMore: boolean;
  next: StartCursor | null;
};

export function readAccountsPage(value: unknown): AccountsPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  if (value.items.length > PAGE_SIZE) return null;
  const pair = readPair(value.employee);
  if (!pair) return null;
  const items: BalanceAccount[] = [];
  for (const entry of value.items) {
    if (!isObject(entry) || !isUuid(entry.account_id) || !isUuid(entry.employee_id)
      || !isUuid(entry.employer_entity_id) || !isUuid(entry.leave_type_id)
      || typeof entry.type_code !== 'string' || typeof entry.type_name !== 'string'
      || typeof entry.type_is_active !== 'boolean' || !isUuid(entry.period_id)
      || typeof entry.period_label !== 'string' || typeof entry.starts_on !== 'string'
      || typeof entry.ends_on !== 'string' || !isFiniteNumber(entry.balance_days)
      || typeof entry.has_opening !== 'boolean' || typeof entry.has_annual_grant !== 'boolean') return null;
    items.push({
      accountId: entry.account_id,
      employeeId: entry.employee_id,
      employerId: entry.employer_entity_id,
      leaveTypeId: entry.leave_type_id,
      typeCode: entry.type_code,
      typeName: entry.type_name,
      typeIsActive: entry.type_is_active,
      periodId: entry.period_id,
      periodLabel: entry.period_label,
      startsOn: entry.starts_on,
      endsOn: entry.ends_on,
      balanceDays: entry.balance_days,
      hasOpening: entry.has_opening,
      hasAnnualGrant: entry.has_annual_grant,
    });
  }
  const next = readStartCursor(value.has_more, value.next_after_period_start, value.next_after_account, true);
  if (!next.ok) return null;
  return { pair, items, hasMore: value.has_more, next: next.cursor };
}

export type LedgerAccount = {
  accountId: string;
  leaveTypeId: string;
  typeName: string;
  periodId: string;
  periodLabel: string;
  startsOn: string;
  endsOn: string;
  balanceDays: number;
};

export type TypeVersionInfo = {
  id: string;
  leaveTypeId: string;
  version: number;
  effectiveFrom: string;
  effectiveUntil: string | null;
  balanceMode: string;
  payEffect: string;
  source: string;
};

export type RequestConsumption = {
  requestId: string;
  requestState: string;
  requestVersion: number;
  employmentId: string | null;
  previewVersion: number;
  leaveDate: string;
  units: number;
  ledgerEntryId: string | null;
  typeVersionId: string | null;
  calendarVersionId: string | null;
  yearPeriodId: string | null;
};

export type ReversalEntry = {
  entryId: string;
  entryKind: string;
  deltaDays: number;
  correctionId: string | null;
};

export type CorrectionLink = {
  correctionId: string;
  originalRequestId: string | null;
  replacementRequestId: string | null;
  reason: string;
  actorUserId: string | null;
  createdAt: string;
};

export type LedgerEntry = {
  entryId: string;
  accountId: string;
  entryKind: string;
  deltaDays: number;
  createdAt: string;
  actorUserId: string | null;
  reason: string;
  sourceReference: string;
  sourceVersionId: string | null;
  typeVersion: TypeVersionInfo | null;
  reversalOfEntryId: string | null;
  reversedSourceDeltaDays: number | null;
  correctionId: string | null;
  requestConsumption: RequestConsumption | null;
  reversalEntries: ReversalEntry[];
  correctionLinks: CorrectionLink[];
};

export type LedgerPage = {
  pair: BalancePair;
  account: LedgerAccount;
  items: LedgerEntry[];
  hasMore: boolean;
  next: LedgerCursor | null;
};

function readTypeVersion(value: unknown): TypeVersionInfo | null {
  if (!isObject(value) || !isUuid(value.id) || !isUuid(value.leave_type_id)
    || !isFiniteNumber(value.version) || typeof value.effective_from !== 'string'
    || !isTextOrNull(value.effective_until) || typeof value.balance_mode !== 'string'
    || typeof value.pay_effect !== 'string' || typeof value.source !== 'string') return null;
  return {
    id: value.id,
    leaveTypeId: value.leave_type_id,
    version: value.version,
    effectiveFrom: value.effective_from,
    effectiveUntil: value.effective_until,
    balanceMode: value.balance_mode,
    payEffect: value.pay_effect,
    source: value.source,
  };
}

function readConsumption(value: unknown): RequestConsumption | null {
  if (value === null) return null;
  if (!isObject(value) || !isUuid(value.request_id) || typeof value.request_state !== 'string'
    || !isFiniteNumber(value.request_version) || !isFiniteNumber(value.preview_version)
    || typeof value.leave_date !== 'string' || !isFiniteNumber(value.units)) return null;
  return {
    requestId: value.request_id,
    requestState: value.request_state,
    requestVersion: value.request_version,
    employmentId: typeof value.employment_id === 'string' && isUuid(value.employment_id) ? value.employment_id : null,
    previewVersion: value.preview_version,
    leaveDate: value.leave_date,
    units: value.units,
    ledgerEntryId: typeof value.ledger_entry_id === 'string' && isUuid(value.ledger_entry_id) ? value.ledger_entry_id : null,
    typeVersionId: typeof value.type_version_id === 'string' && isUuid(value.type_version_id) ? value.type_version_id : null,
    calendarVersionId: typeof value.calendar_version_id === 'string' && isUuid(value.calendar_version_id) ? value.calendar_version_id : null,
    yearPeriodId: typeof value.year_period_id === 'string' && isUuid(value.year_period_id) ? value.year_period_id : null,
  };
}

function readReversals(value: unknown): ReversalEntry[] | null {
  if (!Array.isArray(value)) return null;
  const items: ReversalEntry[] = [];
  for (const entry of value) {
    if (!isObject(entry) || !isUuid(entry.entry_id) || typeof entry.entry_kind !== 'string'
      || !isFiniteNumber(entry.delta_days) || !isTextOrNull(entry.correction_id)
      || (entry.correction_id !== null && !isUuid(entry.correction_id))) return null;
    items.push({
      entryId: entry.entry_id,
      entryKind: entry.entry_kind,
      deltaDays: entry.delta_days,
      correctionId: entry.correction_id,
    });
  }
  return items;
}

function readCorrections(value: unknown): CorrectionLink[] | null {
  if (!Array.isArray(value)) return null;
  const items: CorrectionLink[] = [];
  for (const entry of value) {
    if (!isObject(entry) || !isUuid(entry.correction_id) || typeof entry.reason !== 'string'
      || typeof entry.created_at !== 'string'
      || !(entry.original_request_id === null
        || (typeof entry.original_request_id === 'string' && isUuid(entry.original_request_id)))
      || !(entry.replacement_request_id === null
        || (typeof entry.replacement_request_id === 'string' && isUuid(entry.replacement_request_id)))
      || !(entry.actor_user_id === null
        || (typeof entry.actor_user_id === 'string' && isUuid(entry.actor_user_id)))) return null;
    items.push({
      correctionId: entry.correction_id,
      originalRequestId: entry.original_request_id,
      replacementRequestId: entry.replacement_request_id,
      reason: entry.reason,
      actorUserId: entry.actor_user_id,
      createdAt: entry.created_at,
    });
  }
  return items;
}

function readLedgerEntry(value: unknown): LedgerEntry | null {
  if (!isObject(value) || !isUuid(value.entry_id) || !isUuid(value.account_id)
    || typeof value.entry_kind !== 'string' || !isFiniteNumber(value.delta_days)
    || typeof value.created_at !== 'string' || !isTextOrNull(value.actor_user_id)
    || (value.actor_user_id !== null && !isUuid(value.actor_user_id))
    || typeof value.reason !== 'string' || typeof value.source_reference !== 'string'
    || !isTextOrNull(value.source_version_id)
    || (value.source_version_id !== null && !isUuid(value.source_version_id))
    || !isTextOrNull(value.reversal_of_entry_id)
    || (value.reversal_of_entry_id !== null && !isUuid(value.reversal_of_entry_id))
    || !isNumberOrNull(value.reversed_source_delta_days)
    || !isTextOrNull(value.correction_id)
    || (value.correction_id !== null && !isUuid(value.correction_id))) return null;
  if (value.type_version !== null && readTypeVersion(value.type_version) === null) return null;
  if (value.request_consumption !== null && readConsumption(value.request_consumption) === null) return null;
  const reversals = readReversals(value.reversal_entries);
  const corrections = readCorrections(value.correction_links);
  if (reversals === null || corrections === null) return null;
  return {
    entryId: value.entry_id,
    accountId: value.account_id,
    entryKind: value.entry_kind,
    deltaDays: value.delta_days,
    createdAt: value.created_at,
    actorUserId: value.actor_user_id,
    reason: value.reason,
    sourceReference: value.source_reference,
    sourceVersionId: value.source_version_id,
    typeVersion: value.type_version === null ? null : readTypeVersion(value.type_version),
    reversalOfEntryId: value.reversal_of_entry_id,
    reversedSourceDeltaDays: value.reversed_source_delta_days,
    correctionId: value.correction_id,
    requestConsumption: value.request_consumption === null ? null : readConsumption(value.request_consumption),
    reversalEntries: reversals,
    correctionLinks: corrections,
  };
}

export function readLedgerPage(value: unknown): LedgerPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  if (value.items.length > PAGE_SIZE) return null;
  const pair = readPair(value.employee);
  if (!pair) return null;
  const rawAccount = value.account;
  if (!isObject(rawAccount) || !isUuid(rawAccount.account_id) || !isUuid(rawAccount.leave_type_id)
    || typeof rawAccount.type_name !== 'string' || !isUuid(rawAccount.period_id)
    || typeof rawAccount.period_label !== 'string' || typeof rawAccount.starts_on !== 'string'
    || typeof rawAccount.ends_on !== 'string' || !isFiniteNumber(rawAccount.balance_days)) return null;
  const items: LedgerEntry[] = [];
  for (const entry of value.items) {
    const parsed = readLedgerEntry(entry);
    if (!parsed) return null;
    items.push(parsed);
  }
  const next = readLedgerCursor(value.has_more, value.next_before_created_at, value.next_before_entry);
  if (!next.ok) return null;
  return {
    pair,
    account: {
      accountId: rawAccount.account_id,
      leaveTypeId: rawAccount.leave_type_id,
      typeName: rawAccount.type_name,
      periodId: rawAccount.period_id,
      periodLabel: rawAccount.period_label,
      startsOn: rawAccount.starts_on,
      endsOn: rawAccount.ends_on,
      balanceDays: rawAccount.balance_days,
    },
    items,
    hasMore: value.has_more,
    next: next.cursor,
  };
}

export type PostingPeriod = {
  periodId: string;
  label: string;
  startsOn: string;
  endsOn: string;
  calendarId: string;
};

export type PeriodsPage = {
  pair: BalancePair;
  items: PostingPeriod[];
  hasMore: boolean;
  next: StartCursor | null;
};

export function readPeriodsPage(value: unknown): PeriodsPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  if (value.items.length > PAGE_SIZE) return null;
  const pair = readPair(value.employee);
  if (!pair) return null;
  const items: PostingPeriod[] = [];
  for (const entry of value.items) {
    if (!isObject(entry) || !isUuid(entry.period_id) || typeof entry.label !== 'string'
      || typeof entry.starts_on !== 'string' || typeof entry.ends_on !== 'string'
      || !isUuid(entry.calendar_id)) return null;
    items.push({
      periodId: entry.period_id,
      label: entry.label,
      startsOn: entry.starts_on,
      endsOn: entry.ends_on,
      calendarId: entry.calendar_id,
    });
  }
  const next = readStartCursor(value.has_more, value.next_after_start, value.next_after_period, true);
  if (!next.ok) return null;
  return { pair, items, hasMore: value.has_more, next: next.cursor };
}

export type PostingType = {
  leaveTypeId: string;
  code: string;
  name: string;
  isActive: boolean;
  typeVersionId: string;
  typeVersion: number;
  effectiveFrom: string;
  effectiveUntil: string | null;
  policySource: string;
  policyDate: string;
  accountId: string | null;
  balanceDays: number;
  alreadyPosted: boolean;
  canPost: boolean;
  postingBlockedReason: string | null;
};

export type TypesPage = {
  pair: BalancePair;
  periodId: string;
  kind: string;
  policyDate: string;
  items: PostingType[];
  hasMore: boolean;
  next: CodeCursor | null;
};

export function readTypesPage(value: unknown): TypesPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  if (value.items.length > PAGE_SIZE) return null;
  const pair = readPair(value.employee);
  if (!pair) return null;
  if (!isUuid(value.period_id) || typeof value.kind !== 'string' || typeof value.policy_date !== 'string') return null;
  const items: PostingType[] = [];
  for (const entry of value.items) {
    if (!isObject(entry) || !isUuid(entry.leave_type_id) || typeof entry.code !== 'string'
      || typeof entry.name !== 'string' || typeof entry.is_active !== 'boolean'
      || !isUuid(entry.type_version_id) || !isFiniteNumber(entry.type_version)
      || typeof entry.effective_from !== 'string' || !isTextOrNull(entry.effective_until)
      || typeof entry.policy_source !== 'string' || typeof entry.policy_date !== 'string'
      || !(entry.account_id === null || (typeof entry.account_id === 'string' && isUuid(entry.account_id)))
      || !isFiniteNumber(entry.balance_days) || typeof entry.already_posted !== 'boolean'
      || typeof entry.can_post !== 'boolean' || !isTextOrNull(entry.posting_blocked_reason)) return null;
    items.push({
      leaveTypeId: entry.leave_type_id,
      code: entry.code,
      name: entry.name,
      isActive: entry.is_active,
      typeVersionId: entry.type_version_id,
      typeVersion: entry.type_version,
      effectiveFrom: entry.effective_from,
      effectiveUntil: entry.effective_until,
      policySource: entry.policy_source,
      policyDate: entry.policy_date,
      accountId: entry.account_id,
      balanceDays: entry.balance_days,
      alreadyPosted: entry.already_posted,
      canPost: entry.can_post,
      postingBlockedReason: entry.posting_blocked_reason,
    });
  }
  const next = readCodeCursor(value.has_more, value.next_after_code, value.next_after_type);
  if (!next.ok) return null;
  return {
    pair,
    periodId: value.period_id,
    kind: value.kind,
    policyDate: value.policy_date,
    items,
    hasMore: value.has_more,
    next: next.cursor,
  };
}

export type BalanceParams = {
  q: string;
  sc: string;
  se: string;
  so: string;
  employee: string;
  employer: string;
  acs: string;
  aca: string;
  kind: string;
  period: string;
  type: string;
  pcs: string;
  pcp: string;
  tcs: string;
  tct: string;
};

export type QueryErrors = {
  q: string;
  searchCursor: string;
  pair: string;
  accountsCursor: string;
  kind: string;
  period: string;
  type: string;
  periodsCursor: string;
  typesCursor: string;
};

export type ParsedBalanceQuery = { params: BalanceParams; errors: QueryErrors };

function param(raw: Record<string, string | string[] | undefined>, key: string): string {
  const value = raw[key];
  return typeof value === 'string' ? value.trim() : '';
}

export function parseBalanceQuery(raw: Record<string, string | string[] | undefined>): ParsedBalanceQuery {
  const errors: QueryErrors = {
    q: '', searchCursor: '', pair: '', accountsCursor: '',
    kind: '', period: '', type: '', periodsCursor: '', typesCursor: '',
  };

  const q = param(raw, 'q');
  if (q !== '' && (q.length < MIN_QUERY_LENGTH || q.length > MAX_QUERY_LENGTH)) {
    errors.q = `اكتب من ${MIN_QUERY_LENGTH} إلى ${MAX_QUERY_LENGTH} حرفًا للبحث عن موظف بالاسم أو الرمز.`;
  }

  const params: BalanceParams = {
    q: errors.q === '' ? q : '',
    sc: param(raw, 'sc'),
    se: param(raw, 'se'),
    so: param(raw, 'so'),
    employee: param(raw, 'employee'),
    employer: param(raw, 'employer'),
    acs: param(raw, 'acs'),
    aca: param(raw, 'aca'),
    kind: param(raw, 'kind'),
    period: param(raw, 'period'),
    type: param(raw, 'type'),
    pcs: param(raw, 'pcs'),
    pcp: param(raw, 'pcp'),
    tcs: param(raw, 'tcs'),
    tct: param(raw, 'tct'),
  };

  const searchCursorParts = [params.sc, params.se, params.so];
  if (searchCursorParts.some((part) => part !== '')) {
    if (params.sc === '' || params.se === '' || params.so === ''
      || params.sc.length > 120 || !isUuid(params.se) || !isUuid(params.so)) {
      errors.searchCursor = 'مؤشر صفحة البحث غير مكتمل أو غير صالح. عُد إلى أول صفحة للنتائج.';
      params.sc = '';
      params.se = '';
      params.so = '';
    }
  }

  if (params.employee !== '' || params.employer !== '') {
    if (params.employee === '' || params.employer === ''
      || !isUuid(params.employee) || !isUuid(params.employer)) {
      errors.pair = 'زوج الموظف وجهة العمل غير مكتمل أو غير صالح. اختر الموظف من جديد.';
      params.employee = '';
      params.employer = '';
      params.acs = '';
      params.aca = '';
      params.kind = '';
      params.period = '';
      params.type = '';
      params.pcs = '';
      params.pcp = '';
      params.tcs = '';
      params.tct = '';
    }
  }

  if ((params.acs !== '' || params.aca !== '')
    && (params.acs === '' || params.aca === '' || !isDate(params.acs) || !isUuid(params.aca))) {
    errors.accountsCursor = 'مؤشر قائمة الحسابات غير صالح. عُد إلى أول صفحة.';
    params.acs = '';
    params.aca = '';
  }

  if (params.kind !== '' && !isPostingKind(params.kind)) {
    errors.kind = 'نوع القيد المحدد غير صالح. اختر نوع القيد من جديد.';
    params.kind = '';
  }
  if (params.kind === '') {
    params.period = '';
    params.type = '';
  }
  if (params.period !== '' && !isUuid(params.period)) {
    errors.period = 'فترة الإجازات المحددة غير صالحة. اختر الفترة من جديد.';
    params.period = '';
    params.type = '';
  }
  if (params.period === '') {
    params.type = '';
  }
  if (params.type !== '' && !isUuid(params.type)) {
    errors.type = 'نوع الإجازة المحدد غير صالح. اختر النوع من جديد.';
    params.type = '';
  }

  if ((params.pcs !== '' || params.pcp !== '')
    && (params.pcs === '' || params.pcp === '' || !isDate(params.pcs) || !isUuid(params.pcp))) {
    errors.periodsCursor = 'مؤشر قائمة الفترات غير صالح. عُد إلى أول صفحة.';
    params.pcs = '';
    params.pcp = '';
  }
  if ((params.tcs !== '' || params.tct !== '')
    && (params.tcs === '' || params.tct === '' || params.tcs.length > 120 || !isUuid(params.tct))) {
    errors.typesCursor = 'مؤشر قائمة الأنواع غير صالح. عُد إلى أول صفحة.';
    params.tcs = '';
    params.tct = '';
  }

  return { params, errors };
}

export type LedgerParams = {
  employee: string;
  employer: string;
  cursor: LedgerCursor | null;
  error: string;
};

// The ledger is ordered newest first, so its keyset walks backwards only: complete tuples
// or nothing, with no synthetic offsets and no partial cursor halves.
export function parseLedgerQuery(raw: Record<string, string | string[] | undefined>): LedgerParams {
  const employee = param(raw, 'employee');
  const employer = param(raw, 'employer');
  const lc = param(raw, 'lc');
  const le = param(raw, 'le');

  if (employee === '' || employer === '' || !isUuid(employee) || !isUuid(employer)) {
    return {
      employee: '',
      employer: '',
      cursor: null,
      error: 'زوج الموظف وجهة العمل غير مكتمل أو غير صالح. عُد إلى قائمة أرصدة الإجازات واختر الموظف من جديد.',
    };
  }

  if (lc === '' && le === '') return { employee, employer, cursor: null, error: '' };
  if (lc === '' || le === '' || lc.length > 40 || !isUuid(le)) {
    return {
      employee,
      employer,
      cursor: null,
      error: 'مؤشر صفحة سجل الحساب غير مكتمل أو غير صالح. عُد إلى أحدث القيود.',
    };
  }
  return { employee, employer, cursor: { createdAt: lc, entryId: le }, error: '' };
}

export function balancesHref(tenantId: string, values: Partial<BalanceParams>): string {
  const search = new URLSearchParams();
  for (const key of Object.keys(values) as (keyof BalanceParams)[]) {
    const value = values[key];
    if (typeof value === 'string' && value !== '') search.set(key, value);
  }
  const suffix = search.toString();
  return `/tenant/${tenantId}/leave/balances${suffix ? `?${suffix}` : ''}`;
}

export function ledgerHref(tenantId: string, accountId: string, values: {
  employee: string;
  employer: string;
  lc?: string;
  le?: string;
}): string {
  const search = new URLSearchParams();
  if (values.employee) search.set('employee', values.employee);
  if (values.employer) search.set('employer', values.employer);
  if (values.lc) search.set('lc', values.lc);
  if (values.le) search.set('le', values.le);
  const suffix = search.toString();
  return `/tenant/${tenantId}/leave/balances/${accountId}${suffix ? `?${suffix}` : ''}`;
}

export type DeltaOutcome =
  | { ok: true; value: string }
  | { ok: false; reason: 'format' | 'range' | 'zero' | 'sign' };

// Parses the operator entry as an exact decimal string. No floating point arithmetic is
// involved, so the value sent to leave_post_balance never drifts from what was typed.
export function normalizeDelta(raw: string, kind: PostingKind): DeltaOutcome {
  const trimmed = raw.trim();
  const match = /^([+-]?)(\d+)(?:\.(\d*))?$/.exec(trimmed);
  if (!match) return { ok: false, reason: 'format' };
  const negative = match[1] === '-';
  const whole = (match[2] ?? '').replace(/^0+(?=\d)/, '');
  const fraction = match[3] ?? '';
  if (fraction.length > 2) return { ok: false, reason: 'format' };
  if (whole.length > 6) return { ok: false, reason: 'range' };
  const decimals = (fraction + '00').slice(0, 2);
  if (`${whole.padStart(6, '0')}.${decimals}` > MAX_DELTA_MAGNITUDE) return { ok: false, reason: 'range' };
  if (whole === '0' && decimals === '00') return { ok: false, reason: 'zero' };
  if (negative && kind !== 'adjustment') return { ok: false, reason: 'sign' };
  return { ok: true, value: `${negative ? '-' : ''}${whole}.${decimals}` };
}

export function deltaErrorText(reason: 'format' | 'range' | 'zero' | 'sign'): string {
  if (reason === 'format') {
    return `أدخل عدد أيام صالحًا بمنزلتين عشريتين كحد أقصى، مثل 2 أو 2.5. القيم غير المحدودة والكسر الأعمى غير مقبولة.`;
  }
  if (reason === 'range') return `القيمة خارج النطاق المسموح: القيمة المطلقة لا تتجاوز ${MAX_DELTA_MAGNITUDE} يومًا.`;
  if (reason === 'zero') return 'لا يمكن تسجيل قيد بصفر يوم.';
  return 'الرصيد الافتتاحي والمنحة السنوية يجب أن يكونا موجبين. استخدم قيد تعديل موجبًا أو سالبًا بدلًا من ذلك.';
}

export function entryKindLabel(kind: string): string {
  if (kind === 'opening') return 'رصيد افتتاحي';
  if (kind === 'annual_grant') return 'منحة سنوية';
  if (kind === 'adjustment') return 'تعديل يدوي';
  if (kind === 'leave_consumption') return 'استهلاك باعتماد طلب';
  if (kind === 'cancellation_reversal') return 'إعادة رصيد بإلغاء الاعتماد';
  if (kind === 'correction_reversal') return 'إعادة رصيد ضمن تصحيح';
  return 'قيد غير محدد';
}

export function postingKindLabel(kind: PostingKind): string {
  if (kind === 'opening') return 'رصيد افتتاحي';
  if (kind === 'annual_grant') return 'منحة سنوية';
  return 'تعديل يدوي';
}

export function postingKindSummary(kind: PostingKind): string {
  if (kind === 'opening') {
    return 'أدخل الرصيد الافتتاحي لهذا النوع في الفترة المختارة. يجب أن يكون القدر موجبًا أكبر من صفر.';
  }
  if (kind === 'annual_grant') {
    return 'أدخل مقدار المنحة السنوية يدويًا كما هو مقرر داخليًا. الواجهة لا تحسب منحة نظامية ولا تقترح مقدارًا ولا تفترض أسلوب منح مبكر أو متدرج.';
  }
  return 'أدخل قدرًا موجبًا أو سالبًا (لا يقبل الصفر) لتصحيح الرصيد. الرصيد بعد التعديل لا يقبل أن يصبح سالبًا.';
}

export function blockedReasonLabel(reason: string | null, canPost: boolean): string {
  if (canPost) return '';
  if (reason === 'adjust_permission_required') return 'تحتاج إلى صلاحية تعديل أرصدة الإجازات.';
  if (reason === 'new_work_disabled') return 'خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، فلا تُقبل قيود رصيد جديدة.';
  if (reason === 'employer_inactive') return 'جهة العمل غير نشطة، فلا يُقبل قيد جديد لها.';
  if (reason === 'active_employment_required') return 'لا توجد فترة عمل سارية اليوم بين الموظف وجهة العمل.';
  if (reason !== null && reason.endsWith('_already_posted')) {
    return 'سُجّل هذا القيد لهذا الحساب مسبقًا؛ يبقى قيد واحد لكل من الرصيد الافتتاحي والمنحة السنوية حتى لو تغيّرت النسخة السياسية.';
  }
  return 'لا يقبل هذا القيد حاليًا. راجع بيانات الموظف وجهة العمل والإعدادات.';
}

export function employmentStatusLabel(pair: BalancePair): string {
  return pair.hasActiveEmployment ? 'فترة عمل سارية اليوم' : 'لا توجد فترة عمل سارية اليوم';
}

export function employerStatusLabel(pair: BalancePair): string {
  return pair.employerIsActive ? 'جهة العمل نشطة' : 'جهة العمل غير نشطة';
}

export function typeStatus(isActive: boolean): string {
  return isActive ? 'النوع مفعّل' : 'النوع غير مفعّل';
}

export function formatDays(value: number): string {
  const fixed = Math.abs(value).toFixed(2);
  if (fixed.endsWith('.00')) return fixed.slice(0, -3);
  if (fixed.endsWith('0')) return fixed.slice(0, -1);
  return fixed;
}

export function formatSignedDays(value: number): string {
  if (value === 0) return '0';
  return `${value > 0 ? '+' : '-'}${formatDays(value)}`;
}

export type PostErrorCode =
  | 'input'
  | 'reason'
  | 'source'
  | 'delta'
  | 'forbidden'
  | 'access'
  | 'session'
  | 'setup'
  | 'new-work-disabled'
  | 'employee'
  | 'employment'
  | 'employer'
  | 'scope'
  | 'version'
  | 'untracked'
  | 'key-conflict'
  | 'grant-exists'
  | 'balance'
  | 'failed'
  | 'unknown';

export type PostBalanceState = {
  error: string;
  attempt: number;
  accountId: string | null;
  entryId: string | null;
  replay: boolean;
};

export const EMPTY_POST_STATE: PostBalanceState = {
  error: '',
  attempt: 0,
  accountId: null,
  entryId: null,
  replay: false,
};

export function postErrorText(code: PostErrorCode): string {
  switch (code) {
    case 'input':
      return 'راجع بيانات القيد المختارة (النوع والفترة والنوع المحدد) ثم أعد المحاولة. لم يُرسل أي قيد.';
    case 'reason':
      return `اكتب سببًا للقيد من ${MIN_REASON} إلى ${MAX_REASON} حرفًا. لم يُرسل أي قيد.`;
    case 'source':
      return `اكتب مرجع تدقيق يدويًا من ${MIN_SOURCE_LENGTH} إلى ${MAX_SOURCE_LENGTH} حرفًا. لم يُرسل أي قيد.`;
    case 'delta':
      return 'راجع عدد الأيام المكتوب ثم أعد المحاولة. لم يُرسل أي قيد.';
    case 'new-work-disabled':
      return 'خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا. هذه المحاولة لم تُنفّذ؛ راجع سجل الحساب للتحقق من أي محاولة سابقة.';
    case 'employee':
      return 'ملف الموظف لم يعد متاحًا في هذه الشركة. رُفضت هذه المحاولة؛ راجع سجل أي محاولة سابقة.';
    case 'employment':
      return 'لا توجد فترة عمل سارية اليوم بين الموظف وجهة العمل. رُفضت هذه المحاولة؛ راجع سجل أي محاولة سابقة.';
    case 'employer':
      return 'جهة العمل غير نشطة أو لم تعد متاحة. رُفضت هذه المحاولة؛ راجع سجل أي محاولة سابقة.';
    case 'scope':
      return 'نوع الإجازة أو الفترة لا تنتمي إلى هذا الموظف وجهة عمله أو لم تعد متاحة. رُفضت هذه المحاولة؛ راجع سجل أي محاولة سابقة.';
    case 'version':
      return 'نسخة السياسة المحفوظة لم تعد سارية في تاريخ القيد. رُفضت هذه المحاولة. راجع سجل الحساب أولًا، ثم استخدم «بدء محاولة جديدة» إذا أردت استخدام النسخة الحالية.';
    case 'untracked':
      return 'نوع الإجازة المختار لا يُدار رصيده، فلا يقبل قيدًا. اختر نوعًا متتبع الرصيد.';
    case 'key-conflict':
      return 'استُخدم مفتاح التنفيذ نفسه سابقًا ببيانات مختلفة. رُفضت هذه المحاولة. راجع سجل الحساب قبل استخدام «بدء محاولة جديدة».';
    case 'grant-exists':
      return 'سُجّلت منحة سنوية واحدة لهذا الحساب مسبقًا ويبقى واحدة حتى لو تغيّرت النسخة السياسية. لم يُسجَّل قيد جديد.';
    case 'balance':
      return 'رصيد الحساب لا يكفي لهذا الخفض. رُفضت هذه المحاولة؛ راجع سجل الحساب قبل تعديل عدد الأيام.';
    case 'forbidden':
      return 'ليست لديك صلاحية تسجيل قيود أرصدة الإجازات في هذه الشركة. راجع إدارة الموارد البشرية.';
    case 'access':
      return 'تعذّر التحقق من صلاحيتك الآن. أعد المحاولة لاحقًا.';
    case 'session':
      return 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة بنفس البيانات.';
    case 'setup':
      return 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.';
    case 'failed':
      return 'تعذّر تأكيد نتيجة التسجيل. راجع سجل الحساب، أو أعد المحاولة بنفس البيانات والمفتاح.';
    default:
      return 'تعذّر تأكيد نتيجة المحاولة؛ قد نُفّذ أو لم يُنفذ. أعد المحاولة بنفس المفتاح والسبب والمرجع والقدر دون تغيير، ثم حدّث الصفحة لعرض الرصيد الفعلي.';
  }
}

export function mapPostError(message: string, code?: string): PostErrorCode {
  if (message.includes('leave_balance_input_invalid')) return 'input';
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_annual_grant_exists')) return 'grant-exists';
  if (message.includes('leave_balance_insufficient')) return 'balance';
  if (message.includes('leave_type_version_unavailable')) return 'version';
  if (message.includes('leave_untracked_has_no_balance')) return 'untracked';
  if (message.includes('leave_positive_growth_disabled') || message.includes('leave_new_work_disabled')) {
    return 'new-work-disabled';
  }
  if (message.includes('leave_active_employment_required')) return 'employment';
  if (message.includes('leave_employer_unavailable')) return 'employer';
  if (message.includes('leave_employee_unavailable')) return 'employee';
  if (message.includes('leave_account_scope_invalid')) return 'scope';
  if (message.includes('leave_forbidden')) return 'forbidden';
  if (code === '42501') return 'forbidden';
  if (code === '22023') return 'input';
  if (code === '' || code === undefined) return 'unknown';
  return 'failed';
}

export type ReadFailure = 'denied' | 'scope' | 'input' | 'failed';

export function readFailure(code: string | undefined): ReadFailure {
  if (code === '42501') return 'denied';
  if (code === 'P0002') return 'scope';
  if (code === '22023') return 'input';
  return 'failed';
}
