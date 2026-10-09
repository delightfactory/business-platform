import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const MIN_REASON_LENGTH = 3;
export const MAX_REASON_LENGTH = 500;

export const PAGE_SIZE = 50;
const RPC_P_OFFSET_MAX = 2147483647;
export const MAX_PAGE = Math.floor(RPC_P_OFFSET_MAX / PAGE_SIZE) + 1;

export type DayCountBasis = 'working_days' | 'calendar_days';

export type ReviewIntent =
  | 'refresh'
  | 'approve'
  | 'reject'
  | 'replacement'
  | 'cancellation-request'
  | 'cancellation-accept'
  | 'cancellation-reject';

export type ReviewActionState = { error: string; attempt: number };

export const EMPTY_REVIEW_STATE: ReviewActionState = { error: '', attempt: 0 };

export type LeaveAccess = {
  canView: boolean;
  canManage: boolean;
  canApprove: boolean;
  newWorkEnabled: boolean;
};

export type RequestDay = {
  date: string;
  units: number;
  eligible: boolean;
  isWeeklyRest: boolean;
  holidayName: string | null;
  dayCountBasis: DayCountBasis;
  payEffect: string;
  balanceMode: string;
  isHalfDay: boolean;
  halfDayPart: string | null;
  mappingState: string | null;
};

export type RequestPayload = {
  id: string;
  employeeCode: string;
  employeeName: string;
  leaveTypeName: string;
  startDate: string;
  endDate: string;
  totalUnits: number;
  isHalfDay: boolean;
  halfDayPart: string | null;
  state: string;
  version: number;
  previewVersion: number;
  requestSource: string;
  reason: string;
  ownerQueue: string;
  submittedAt: string | null;
  createdAt: string;
  approvedAt: string | null;
  cancelledAt: string | null;
  approvedPreviewVersion: number | null;
  days: RequestDay[];
  consumedUnits: number;
  consumptionCount: number;
};

type RequestSummary = Pick<RequestPayload, 'id' | 'employeeCode' | 'employeeName' | 'leaveTypeName'
  | 'startDate' | 'endDate' | 'totalUnits' | 'isHalfDay' | 'state' | 'submittedAt'>;
export type RequestQueuePage = { items: RequestSummary[]; hasMore: boolean };

export type CancellationRow = {
  cancellationId: string;
  requestId: string;
  requesterKind: string;
  requestedAt: string;
  reason: string;
  cancellationVersion: number;
  requestVersion: number;
  employeeCode: string;
  employeeName: string;
  leaveTypeName: string;
  startDate: string;
  endDate: string;
  isHalfDay: boolean;
};

export type CancellationQueuePage = { items: CancellationRow[]; hasMore: boolean };

export type CancellationEvent = {
  id: string;
  cancellationId: string | null;
  eventKey: string;
  fromState: string | null;
  toState: string;
  toVersion: number;
  reason: string;
  timeReconciliationRequired: boolean;
  createdAt: string;
  result: Record<string, unknown> | null;
};

export type CancellationHistory = {
  items: CancellationEvent[];
  hasMore: boolean;
  latest: CancellationEvent | null;
};

export type PendingCancellation = {
  id: string;
  version: number;
  reason: string;
  requestedAt: string;
  requesterKind: string;
};

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function isInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value);
}

function isTextOrNull(value: unknown): value is string | null {
  return value === null || typeof value === 'string';
}

function text(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

function textOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function integerOrNull(value: unknown): number | null {
  return isInteger(value) ? value : null;
}

export function readAccess(value: unknown): LeaveAccess | null {
  if (!isObject(value)) return null;
  if (typeof value.can_view !== 'boolean' || typeof value.can_manage !== 'boolean'
    || typeof value.can_approve !== 'boolean' || typeof value.new_work_enabled !== 'boolean') return null;
  return {
    canView: value.can_view,
    canManage: value.can_manage,
    canApprove: value.can_approve,
    newWorkEnabled: value.new_work_enabled,
  };
}

export function readRequest(value: unknown): RequestPayload | null {
  if (!isObject(value)) return null;
  if (!isUuid(value.id) || typeof value.employee_code !== 'string'
    || typeof value.employee_name !== 'string' || typeof value.leave_type_name !== 'string'
    || typeof value.start_date !== 'string' || typeof value.end_date !== 'string'
    || typeof value.total_units !== 'number' || typeof value.is_half_day !== 'boolean'
    || typeof value.state !== 'string' || !isInteger(value.version) || !isInteger(value.preview_version)
    || typeof value.request_source !== 'string' || typeof value.owner_queue !== 'string'
    || typeof value.created_at !== 'string'
    || !isTextOrNull(value.reason) || !isTextOrNull(value.submitted_at)
    || !isTextOrNull(value.approved_at) || !isTextOrNull(value.cancelled_at)
    || !isTextOrNull(value.half_day_part)
    || !(value.approved_preview_version === null || isInteger(value.approved_preview_version))
    || !Array.isArray(value.days) || !Array.isArray(value.consumptions)) return null;

  const days: RequestDay[] = [];
  for (const entry of value.days) {
    const day = readRequestDay(entry);
    if (!day) return null;
    days.push(day);
  }

  let consumedUnits = 0;
  for (const entry of value.consumptions) {
    if (!isObject(entry) || typeof entry.date !== 'string' || typeof entry.units !== 'number') return null;
    consumedUnits += entry.units;
  }

  return {
    id: value.id,
    employeeCode: value.employee_code,
    employeeName: value.employee_name,
    leaveTypeName: value.leave_type_name,
    startDate: value.start_date,
    endDate: value.end_date,
    totalUnits: value.total_units,
    isHalfDay: value.is_half_day,
    halfDayPart: textOrNull(value.half_day_part),
    state: value.state,
    version: value.version,
    previewVersion: value.preview_version,
    requestSource: value.request_source,
    reason: text(value.reason),
    ownerQueue: value.owner_queue,
    submittedAt: textOrNull(value.submitted_at),
    createdAt: value.created_at,
    approvedAt: textOrNull(value.approved_at),
    cancelledAt: textOrNull(value.cancelled_at),
    approvedPreviewVersion: integerOrNull(value.approved_preview_version),
    days,
    consumedUnits,
    consumptionCount: value.consumptions.length,
  };
}

function readRequestDay(value: unknown): RequestDay | null {
  if (!isObject(value) || typeof value.date !== 'string' || typeof value.units !== 'number'
    || typeof value.eligible !== 'boolean' || typeof value.is_weekly_rest !== 'boolean'
    || typeof value.is_half_day !== 'boolean' || !isTextOrNull(value.holiday_name)
    || !isTextOrNull(value.half_day_part) || !isTextOrNull(value.halfday_mapping_state)
    || typeof value.day_count_basis !== 'string' || typeof value.pay_effect !== 'string'
    || typeof value.balance_mode !== 'string') return null;
  if (value.day_count_basis !== 'working_days' && value.day_count_basis !== 'calendar_days') return null;
  return {
    date: value.date,
    units: value.units,
    eligible: value.eligible,
    isWeeklyRest: value.is_weekly_rest,
    holidayName: textOrNull(value.holiday_name),
    dayCountBasis: value.day_count_basis,
    payEffect: value.pay_effect,
    balanceMode: value.balance_mode,
    isHalfDay: value.is_half_day,
    halfDayPart: textOrNull(value.half_day_part),
    mappingState: textOrNull(value.halfday_mapping_state),
  };
}

export function readRequestQueue(value: unknown): RequestQueuePage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean'
    || value.items.length > 100) return null;
  const items: RequestSummary[] = [];
  for (const entry of value.items) {
    if (!isObject(entry) || !isUuid(entry.id) || typeof entry.employee_code !== 'string'
      || typeof entry.employee_name !== 'string' || typeof entry.leave_type_name !== 'string'
      || typeof entry.start_date !== 'string' || typeof entry.end_date !== 'string'
      || typeof entry.total_units !== 'number' || typeof entry.is_half_day !== 'boolean'
      || typeof entry.state !== 'string' || !isTextOrNull(entry.submitted_at)) return null;
    items.push({ id: entry.id, employeeCode: entry.employee_code, employeeName: entry.employee_name,
      leaveTypeName: entry.leave_type_name, startDate: entry.start_date, endDate: entry.end_date,
      totalUnits: entry.total_units, isHalfDay: entry.is_half_day, state: entry.state,
      submittedAt: textOrNull(entry.submitted_at) });
  }
  return { items, hasMore: value.has_more };
}

export function readCancellationQueue(value: unknown): CancellationQueuePage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean'
    || value.items.length > 100) return null;
  const items: CancellationRow[] = [];
  for (const entry of value.items) {
    if (!isObject(entry) || !isUuid(entry.cancellation_id) || !isUuid(entry.request_id)
      || typeof entry.requester_kind !== 'string' || typeof entry.requested_at !== 'string'
      || !isTextOrNull(entry.reason) || !isInteger(entry.cancellation_version)
      || !isInteger(entry.request_version) || typeof entry.employee_code !== 'string'
      || typeof entry.employee_name !== 'string' || typeof entry.leave_type_name !== 'string'
      || typeof entry.start_date !== 'string' || typeof entry.end_date !== 'string'
      || typeof entry.is_half_day !== 'boolean') return null;
    items.push({
      cancellationId: entry.cancellation_id,
      requestId: entry.request_id,
      requesterKind: entry.requester_kind,
      requestedAt: entry.requested_at,
      reason: text(entry.reason),
      cancellationVersion: entry.cancellation_version,
      requestVersion: entry.request_version,
      employeeCode: entry.employee_code,
      employeeName: entry.employee_name,
      leaveTypeName: entry.leave_type_name,
      startDate: entry.start_date,
      endDate: entry.end_date,
      isHalfDay: entry.is_half_day,
    });
  }
  return { items, hasMore: value.has_more };
}

function readCancellationEvent(value: unknown): CancellationEvent | null {
  if (!isObject(value)) return null;
  if (!(value.id === null || typeof value.id === 'string' || isInteger(value.id))) return null;
  if (!isTextOrNull(value.cancellation_id) || (value.cancellation_id !== null && !isUuid(value.cancellation_id)))
    return null;
  if (typeof value.event_key !== 'string' || !isTextOrNull(value.from_state)
    || typeof value.to_state !== 'string' || !isInteger(value.to_version)
    || !isTextOrNull(value.reason) || typeof value.time_reconciliation_required !== 'boolean'
    || typeof value.created_at !== 'string') return null;
  if (value.result !== null && !isObject(value.result)) return null;
  return {
    id: String(value.id),
    cancellationId: textOrNull(value.cancellation_id),
    eventKey: value.event_key,
    fromState: textOrNull(value.from_state),
    toState: value.to_state,
    toVersion: value.to_version,
    reason: text(value.reason),
    timeReconciliationRequired: value.time_reconciliation_required,
    createdAt: value.created_at,
    result: isObject(value.result) ? value.result : null,
  };
}

export function readCancellationHistory(value: unknown): CancellationHistory | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean'
    || value.items.length > 100 || !(value.latest_event === null || isObject(value.latest_event))) return null;
  const items: CancellationEvent[] = [];
  for (const entry of value.items) {
    const event = readCancellationEvent(entry);
    if (!event) return null;
    items.push(event);
  }
  const latest = value.latest_event === null ? null : readCancellationEvent(value.latest_event);
  if (value.latest_event !== null && !latest) return null;
  return { items, hasMore: value.has_more, latest };
}

export function readPendingCancellation(history: CancellationHistory | null): PendingCancellation | null {
  const latest = history?.latest ?? null;
  if (!latest || latest.cancellationId === null) return null;
  if (latest.eventKey !== 'employee.requested' && latest.eventKey !== 'hr.requested') return null;
  if (latest.toState !== 'pending') return null;
  const payload = latest.result === null ? null : latest.result['cancellation'];
  const version = isObject(payload) && isInteger(payload.version) ? payload.version : latest.toVersion;
  if (version < 1) return null;
  return {
    id: latest.cancellationId,
    version,
    reason: latest.reason,
    requestedAt: latest.createdAt,
    requesterKind: latest.eventKey === 'hr.requested' ? 'hr' : 'employee',
  };
}

export function parsePage(raw: string | string[] | undefined): { value: number; invalid: boolean } {
  if (raw === undefined || Array.isArray(raw) || raw === '') return { value: 1, invalid: false };
  if (!/^\d+$/.test(raw)) return { value: 1, invalid: true };
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < 1 || value > MAX_PAGE) return { value: 1, invalid: true };
  return { value, invalid: false };
}

export function queueHref(tenantId: string, requestPage: number, cancellationPage: number): string {
  const params = new URLSearchParams();
  if (requestPage > 1) params.set('page', String(requestPage));
  if (cancellationPage > 1) params.set('cpage', String(cancellationPage));
  const search = params.toString();
  return `/tenant/${tenantId}/leave${search ? `?${search}` : ''}`;
}

export function detailHref(tenantId: string, requestId: string): string {
  return `/tenant/${tenantId}/leave/requests/${requestId}`;
}

export function detailStateHref(tenantId: string, requestId: string, state: string): string {
  return `${detailHref(tenantId, requestId)}?state=${encodeURIComponent(state)}`;
}

export function historyHref(tenantId: string, requestId: string, page: number): string {
  const search = page > 1 ? `?hpage=${String(page)}` : '';
  return `${detailHref(tenantId, requestId)}${search}`;
}

export function stateLabel(state: string): string {
  if (state === 'submitted') return 'مُقدَّم وبانتظار القرار';
  if (state === 'approved') return 'معتمد';
  if (state === 'rejected') return 'مرفوض';
  if (state === 'withdrawn') return 'مسحوب';
  if (state === 'cancelled') return 'ملغى الاعتماد';
  if (state === 'superseded') return 'استُبدل بتصحيح';
  if (state === 'draft') return 'مسودة';
  return 'غير محدّد';
}

export function stateClass(state: string): string {
  if (state === 'submitted') return 'is-pending';
  if (state === 'approved') return 'is-active';
  return 'is-inactive';
}

export function nextOwnerText(state: string, pendingCancellation: boolean): string {
  if (state === 'submitted') return 'فريق اعتماد الإجازات — بانتظار قرار الاعتماد أو الرفض';
  if (state === 'approved' && pendingCancellation) return 'فريق اعتماد الإجازات — بانتظار قرار طلب الإلغاء';
  if (state === 'approved') return 'لا يوجد إجراء مطلوب الآن';
  return 'مغلق — لا يوجد إجراء مطلوب';
}

export function requestSourceLabel(source: string): string {
  if (source === 'hr') return 'إدارة الموارد البشرية';
  if (source === 'employee') return 'خدمة الموظف';
  return 'غير محدّد';
}

export function requesterKindLabel(kind: string): string {
  if (kind === 'hr') return 'إدارة الموارد البشرية';
  if (kind === 'employee') return 'الموظف';
  return 'غير محدّد';
}

export function mappingStateLabel(state: string | null): string {
  if (state === 'mapped') return 'مطابق لدوام اليوم';
  if (state === 'review_required') return 'يحتاج مراجعة دوام اليوم';
  if (state === 'leave_only') return 'احتساب الإجازة فقط';
  return 'غير محدّد';
}

export function mappingStateClass(state: string | null): string {
  if (state === 'mapped') return 'is-active';
  if (state === 'review_required' || state === 'leave_only') return 'is-pending';
  return 'is-inactive';
}

export function halfDayPartLabel(part: string | null): string {
  if (part === 'first') return 'الجزء الأول من اليوم';
  if (part === 'second') return 'الجزء الثاني من اليوم';
  return 'وفق دوام اليوم';
}

export function cancellationStateLabel(state: string): string {
  if (state === 'pending') return 'بانتظار القرار';
  if (state === 'accepted') return 'مقبول';
  if (state === 'rejected') return 'مرفوض';
  return 'غير محدّد';
}

export function cancellationStateClass(state: string): string {
  if (state === 'pending') return 'is-pending';
  if (state === 'accepted') return 'is-active';
  return 'is-inactive';
}

export function eventKeyLabel(eventKey: string): string {
  if (eventKey === 'employee.requested') return 'الموظف طلب إلغاء الاعتماد';
  if (eventKey === 'hr.requested') return 'الموارد البشرية طلبت إلغاء الاعتماد';
  if (eventKey === 'hr.accepted') return 'قُبل طلب الإلغاء وأُلغي الاعتماد';
  if (eventKey === 'hr.rejected') return 'رُفض طلب الإلغاء وبقي الاعتماد ساريًا';
  if (eventKey === 'hr.direct_cancelled') return 'أُلغي الاعتماد مباشرة';
  return 'حدثة غير محدّدة';
}

export function formatDays(value: number): string {
  return String(value);
}

export function formatInstant(value: string): string {
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime())) return value;
  return instant.toLocaleString(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo', dateStyle: 'short', timeStyle: 'short' });
}

export type ReviewErrorCode =
  | 'input'
  | 'reason'
  | 'version'
  | 'setup'
  | 'session'
  | 'failed'
  | 'forbidden'
  | 'unknown'
  | 'key-conflict'
  | 'conflict'
  | 'refresh-required'
  | 'not-approvable'
  | 'not-rejectable'
  | 'not-refreshable'
  | 'not-cancellable'
  | 'cancellation-pending'
  | 'cancellation-not-pending'
  | 'cancellation-unavailable'
  | 'half-day-mapping'
  | 'attendance-conflict'
  | 'payroll-locked-period'
  | 'overlap'
  | 'balance'
  | 'employment'
  | 'type'
  | 'configuration'
  | 'queue'
  | 'unavailable'
  | 'new-work-disabled';

export function mapReviewError(message: string, code?: string): ReviewErrorCode {
  if (message.includes('payroll_locked_leave_addition_requires_correction')) return 'payroll-locked-period';
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_request_version_conflict') || message.includes('leave_cancellation_version_conflict')
    || message.includes('leave_request_transition_invalid')) return 'conflict';
  if (message.includes('leave_half_day_mapping_required') || message.includes('leave_halfday_refresh_invalid')
    || message.includes('leave_half_day_mapping') || message.includes('leave_half_day')) return 'half-day-mapping';
  if (message.includes('leave_attendance_fact_conflict')) return 'attendance-conflict';
  if (message.includes('leave_request_overlap')) return 'overlap';
  if (message.includes('leave_balance_insufficient') || message.includes('leave_balance_invariant_violation')) return 'balance';
  if (message.includes('leave_request_not_approvable')) return 'not-approvable';
  if (message.includes('leave_request_not_rejectable')) return 'not-rejectable';
  if (message.includes('leave_request_not_refreshable') || message.includes('leave_preview_refresh_input_invalid')) return 'not-refreshable';
  if (message.includes('leave_cancellation_request_unavailable') || message.includes('leave_request_not_cancellable')) return 'not-cancellable';
  if (message.includes('leave_cancellation_pending')) return 'cancellation-pending';
  if (message.includes('leave_cancellation_not_pending')) return 'cancellation-not-pending';
  if (message.includes('leave_cancellation_unavailable')) return 'cancellation-unavailable';
  if (message.includes('leave_approval_input_invalid') || message.includes('leave_reject_input_invalid')
    || message.includes('leave_cancellation_input_invalid') || message.includes('leave_cancellation_decision_input_invalid')) return 'input';
  if (message.includes('leave_new_work_disabled')) return 'new-work-disabled';
  if (message.includes('leave_employment_range_unavailable')) return 'employment';
  if (message.includes('leave_type_unavailable')) return 'type';
  if (message.includes('leave_year_period_unavailable') || message.includes('leave_calendar_version_unavailable')
    || message.includes('leave_calendar_unavailable') || message.includes('leave_type_version_unavailable')) return 'configuration';
  if (message.includes('leave_approval_queue_unavailable')) return 'queue';
  if (message.includes('leave_request_unavailable')) return 'unavailable';
  if (message.includes('leave_forbidden') || message.includes('leave_self_forbidden') || code === '42501') return 'forbidden';
  if (code === '22023') return 'input';
  if (code === 'P0002') return 'unavailable';
  return 'unknown';
}

const REVIEW_ERROR_TEXT: Record<ReviewErrorCode, string> = {
  input: 'راجع بيانات المراجعة ثم أعد المحاولة.',
  reason: `اكتب سببًا من ${MIN_REASON_LENGTH} إلى ${MAX_REASON_LENGTH} حرفًا.`,
  version: 'تغيّرت بيانات الطلب منذ فتح الصفحة. حدّث الصفحة ثم أعد المحاولة.',
  setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
  session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
  failed: 'تعذر تنفيذ الإجراء. لم يتغير الطلب؛ أعد المحاولة أو حدّث الصفحة.',
  forbidden: 'ليست لديك صلاحية تنفيذ هذا الإجراء على طلبات الإجازة. راجع إدارة الموارد البشرية.',
  unknown: 'تعذّر تأكيد نتيجة الإجراء؛ قد نُفّذ أو لم يُنفذ. أعد المحاولة بالسبب والمفاتيح نفسها دون تغيير، ثم حدّث الصفحة لعرض الحالة الفعلية.',
  'key-conflict': 'تعارض في مفتاح التنفيذ مع محاولة سابقة ببيانات مختلفة. حدّث الصفحة ثم نفّذ التغيير بسبب جديد.',
  conflict: 'تغيّر الطلب أو طلب الإلغاء منذ فتح الصفحة. حدّث الصفحة لعرض أحدث بيانات ثم أعد المحاولة.',
  'refresh-required': 'المعاينة المحفوظة لم تعد مطابقة لحسابات اليوم. حدّث المعاينة من زر التحديث ثم راجع أيامها واعتمد. لم يتغير الطلب.',
  'not-approvable': 'لا يمكن اعتماد هذا الطلب في حالته الحالية. حدّث الصفحة للتحقق من حالته.',
  'not-rejectable': 'لا يمكن رفض هذا الطلب في حالته الحالية. حدّث الصفحة للتحقق من حالته.',
  'not-refreshable': 'لا يمكن تحديث معاينة هذا الطلب في حالته الحالية. حدّث الصفحة للتحقق من حالته.',
  'not-cancellable': 'لا يمكن طلب إلغاء اعتماد هذا الطلب في حالته الحالية. حدّث الصفحة للتحقق من حالته.',
  'cancellation-pending': 'يوجد طلب إلغاء معلق لهذا الطلب بالفعل. راجع قراره قبل أي إجراء جديد.',
  'cancellation-not-pending': 'لم يعد طلب الإلغاء معلقًا. حدّث الصفحة لعرض نتيجته الفعلية.',
  'cancellation-unavailable': 'طلب الإلغاء لم يعد متاحًا. حدّث الصفحة للتحقق من حالته.',
  'half-day-mapping': 'مطابقة نصف يوم غير مكتملة لهذا الطلب، فلا يمكن اعتماده. حدّث المعاينة أولًا؛ وإن استمرت المطابقة غير مكتملة فراجع إعدادات دوام الموظف وسياسة الحضور لتاريخ النصف يوم. لا يُصحَّح سجل الوقت من هذه الصفحة.',
  'attendance-conflict': 'يوجد سجل حضور مسجّل لأحد أيام الطلب، لذا لا يمكن اعتماده. راجع سجل الحضور لهذا اليوم قبل أي قرار، ثم أعد المحاولة.',
  'payroll-locked-period': 'هذه الإجازة تضيف أيامًا إلى فترة راتب مقفلة. الطلب محفوظ ولم يُعتمد. اطلب من مسؤول الرواتب مراجعة تصحيح المسير؛ اعتماد الإضافة التاريخية من هذه الشاشة غير متاح حاليًا.',
  overlap: 'يتداخل هذا الطلب مع إجازة معتمدة أخرى لنفس الموظف في نفس الأيام. راجع سجل طلبات الموظف ثم أعد المحاولة.',
  balance: 'لا يكفي رصيد الموظف لاعتماد كل أيام الطلب. راجع أرصدة الإجازات لهذا النوع قبل إعادة المحاولة.',
  employment: 'بيانات عمل الموظف لم تعد تغطي تواريخ الطلب. راجع ملف الموظف ثم أعد المحاولة.',
  type: 'نوع الإجازة المحدد لم يعد متاحًا. حدّث الصفحة للتحقق من بيانات الطلب.',
  configuration: 'فترة أو تقويم الإجازات غير مهيأ لهذه التواريخ. راجع إعدادات الإجازات ثم أعد المحاولة.',
  queue: 'اعتماد طلبات الإجازة غير متاح حاليًا في الشركة. تواصل مع إدارة الموارد البشرية.',
  unavailable: 'هذا الطلب لم يعد متاحًا للعرض. عُد إلى قائمة المراجعة وحدّثها.',
  'new-work-disabled': 'خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن اعتماد طلبات جديدة أو تحديث معايناتها. تبقى مراجعة الطلبات ورفضها متاحة.',
};

export function reviewErrorText(code: ReviewErrorCode): string {
  return REVIEW_ERROR_TEXT[code] ?? REVIEW_ERROR_TEXT.failed;
}

const FEEDBACK_TEXT: Record<string, string> = {
  approved: 'تم اعتماد الطلب وسُجّل استهلاك أي رصيد مطلوب.',
  replaced: 'تم استبدال الإجازة واعتماد الطلب البديل، مع حفظ الأصل وسجل التصحيح.',
  rejected: 'تم رفض الطلب بسبب المذكور وسُجّل القرار في سجل العملية.',
  refreshed: 'تم تحديث معاينة الطلب. راجع أيامها الجديدة ثم اتخذ قرارك.',
  'cancellation-requested': 'تم إرسال طلب إلغاء الاعتماد، وسيبقى الطلب معتمدًا حتى يُقبل طلب الإلغاء.',
  'cancellation-accepted': 'تم قبول طلب الإلغاء وأُعيد أي رصيد استُهلك عند الاعتماد.',
  'cancellation-accepted-time': 'تم قبول طلب الإلغاء وأصبح الطلب ملغى. يلزم مراجعة سجل الحضور لهذا الطلب لأن أيامه كانت قد اعتُمدت؛ لن يتغير سجل الوقت تلقائيًا.',
  'cancellation-rejected': 'تم رفض طلب الإلغاء وبقي الطلب معتمدًا كما هو.',
};

export function feedbackText(state: string | undefined, requestState: string, cancellationState?: string): string | null {
  if (typeof state !== 'string') return null;
  if (state === 'refreshed') return null;
  if (state === 'approved' && requestState !== 'approved') return null;
  if (state === 'replaced' && requestState !== 'superseded') return null;
  if (state === 'rejected' && requestState !== 'rejected') return null;
  if (state === 'cancellation-requested' && (requestState !== 'approved' || cancellationState !== 'pending')) return null;
  if (state.startsWith('cancellation-accepted') && (requestState !== 'cancelled' || cancellationState !== 'accepted')) return null;
  if (state === 'cancellation-rejected' && (requestState !== 'approved' || cancellationState !== 'rejected')) return null;
  return FEEDBACK_TEXT[state] ?? null;
}
