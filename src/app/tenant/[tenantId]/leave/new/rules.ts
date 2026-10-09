import { isObject, isUuid } from '../rules';
import type { Configuration } from '../settings/rules';

export const PAGE_SIZE = 20;
const RPC_P_OFFSET_MAX = 2147483647;
export const MAX_PAGE = Math.floor(RPC_P_OFFSET_MAX / PAGE_SIZE) + 1;

export const MIN_QUERY_LENGTH = 2;
export const MAX_QUERY_LENGTH = 80;
export const MAX_DATE_SPAN = 731;
export const MIN_REASON_LENGTH = 3;
export const MAX_REASON_LENGTH = 500;

export type RecordLeaveState = { error: string; attempt: number; requestId: string | null };

export const EMPTY_RECORD_STATE: RecordLeaveState = { error: '', attempt: 0, requestId: null };

export type RecordErrorCode =
  | 'input'
  | 'range'
  | 'reason'
  | 'half-day'
  | 'part'
  | 'type'
  | 'configuration'
  | 'zero-days'
  | 'employment'
  | 'unavailable'
  | 'queue'
  | 'key-conflict'
  | 'new-work-disabled'
  | 'forbidden'
  | 'access'
  | 'half-day-context'
  | 'session'
  | 'setup'
  | 'failed'
  | 'unknown';

export type EmployeeOption = {
  employeeId: string;
  employeeCode: string;
  employeeName: string;
  employmentId: string;
  employerId: string;
  employerName: string;
  employmentStart: string | null;
  employmentEnd: string | null;
};

export type OptionsPage = { items: EmployeeOption[]; hasMore: boolean };

export type LeaveTypeVersionOption = {
  effectiveFrom: string;
  effectiveUntil: string | null;
  halfDayAllowed: boolean;
};

export type LeaveTypeOption = {
  id: string;
  code: string;
  name: string;
  versions: LeaveTypeVersionOption[];
};

export type HalfDayPart = 'first' | 'second';

export type HalfDayContext = {
  state: 'leave_only' | 'review_required' | 'mapped_options';
  attendanceEnabled: boolean;
  scheduleKind: 'fixed' | 'flexible' | null;
  parts: HalfDayPart[];
  reason: string | null;
};

export type RecordQuery = {
  start: string;
  end: string;
  datesProvided: boolean;
  dateError: string;
  q: string;
  queryError: string;
  page: number;
  pageInvalid: boolean;
  employee: string;
  employment: string;
  selectionInvalid: boolean;
};

export function isDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = Date.parse(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed) && new Date(parsed).toISOString().slice(0, 10) === value;
}

export function daySpan(start: string, end: string): number {
  if (!isDate(start) || !isDate(end)) return Number.NaN;
  return Math.round((Date.parse(`${end}T00:00:00Z`) - Date.parse(`${start}T00:00:00Z`)) / 86400000);
}

export function dayCount(start: string, end: string): number {
  const span = daySpan(start, end);
  return Number.isNaN(span) ? 0 : span + 1;
}

export function halfDayAllowedOn(type: LeaveTypeOption, date: string): boolean {
  if (!isDate(date)) return false;
  return type.versions.some((version) => version.effectiveFrom <= date
    && (!version.effectiveUntil || version.effectiveUntil > date) && version.halfDayAllowed);
}

export function availableTypes(configuration: Configuration, start: string, end: string): LeaveTypeOption[] {
  const types: LeaveTypeOption[] = [];
  for (const type of configuration.types) {
    const versions = type.versions.filter((version) => version.effective_from <= end
      && (!version.effective_until || version.effective_until > start))
      .sort((a, b) => a.effective_from.localeCompare(b.effective_from));
    if (!type.is_active || versions.length === 0) continue;
    let coveredUntil = start;
    let coversRange = false;
    for (const version of versions) {
      if (version.effective_from > coveredUntil) break;
      if (!version.effective_until || version.effective_until > end) {
        coversRange = true;
        break;
      }
      if (version.effective_until > coveredUntil) coveredUntil = version.effective_until;
    }
    if (!coversRange) continue;
    types.push({
      id: type.id,
      code: type.code,
      name: type.name,
      versions: versions.map((version) => ({
        effectiveFrom: version.effective_from,
        effectiveUntil: version.effective_until,
        halfDayAllowed: version.half_day_allowed,
      })),
    });
  }
  return types;
}

export function readOptionsPage(value: unknown): OptionsPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  if (value.items.length > 50) return null;
  const items: EmployeeOption[] = [];
  for (const entry of value.items) {
    if (!isObject(entry) || !isUuid(entry.employee_id) || typeof entry.employee_code !== 'string'
      || typeof entry.employee_name !== 'string' || !isUuid(entry.employment_id)
      || !isUuid(entry.employer_entity_id) || typeof entry.employer_name !== 'string'
      || !(entry.employment_start === null || typeof entry.employment_start === 'string')
      || !(entry.employment_end === null || typeof entry.employment_end === 'string')) return null;
    items.push({
      employeeId: entry.employee_id,
      employeeCode: entry.employee_code,
      employeeName: entry.employee_name,
      employmentId: entry.employment_id,
      employerId: entry.employer_entity_id,
      employerName: entry.employer_name,
      employmentStart: entry.employment_start,
      employmentEnd: entry.employment_end,
    });
  }
  return { items, hasMore: value.has_more };
}

export function readHalfDayContext(value: unknown): HalfDayContext | null {
  if (!isObject(value) || typeof value.state !== 'string'
    || typeof value.attendance_enabled !== 'boolean') return null;
  if (value.state === 'leave_only') {
    return { state: 'leave_only', attendanceEnabled: value.attendance_enabled, scheduleKind: null, parts: [], reason: null };
  }
  if (value.state === 'review_required') {
    return {
      state: 'review_required',
      attendanceEnabled: value.attendance_enabled,
      scheduleKind: null,
      parts: [],
      reason: typeof value.reason === 'string' ? value.reason : null,
    };
  }
  if (value.state !== 'mapped_options') return null;
  if (value.schedule_kind === 'flexible') {
    return { state: 'mapped_options', attendanceEnabled: value.attendance_enabled, scheduleKind: 'flexible', parts: [], reason: null };
  }
  if (value.schedule_kind !== 'fixed' || !Array.isArray(value.parts)) return null;
  const parts: HalfDayPart[] = [];
  for (const entry of value.parts) {
    if (!isObject(entry) || (entry.part !== 'first' && entry.part !== 'second')) return null;
    parts.push(entry.part);
  }
  if (!parts.includes('first') || !parts.includes('second')) return null;
  return { state: 'mapped_options', attendanceEnabled: value.attendance_enabled, scheduleKind: 'fixed', parts, reason: null };
}

export function halfDayContextNotice(context: HalfDayContext): string {
  if (context.state === 'leave_only') {
    return 'احتساب نصف يوم للإجازة فقط؛ لا يوجد ربط بسجل الحضور لهذه الشركة حاليًا.';
  }
  if (context.state === 'review_required') {
    return 'دوام هذا اليوم غير محدد لدى سجل الحضور، فسيُسجَّل الطلب بحالة تحتاج مراجعة عند الاعتماد.';
  }
  if (context.scheduleKind === 'flexible') {
    return 'دوام الموظف مرن؛ يُحتسب نصف اليوم وفق سياسة الدوام دون تحديد جزء.';
  }
  return '';
}

function text(value: string | string[] | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}

export function parseRecordQuery(raw: {
  start?: string | string[];
  end?: string | string[];
  q?: string | string[];
  page?: string | string[];
  employee?: string | string[];
  employment?: string | string[];
}): RecordQuery {
  const start = text(raw.start);
  const end = text(raw.end);
  const q = text(raw.q);
  const pageRaw = text(raw.page);
  const employee = text(raw.employee);
  const employment = text(raw.employment);

  const datesProvided = start !== '' || end !== '';
  let dateError = '';
  if (datesProvided) {
    if (!isDate(start) || !isDate(end)) dateError = 'اختر تاريخ بداية ونهاية صحيحين.';
    else if (end < start) dateError = 'تاريخ النهاية يجب أن يكون يوم تاريخ البداية أو بعده.';
    else if (daySpan(start, end) > MAX_DATE_SPAN) {
      dateError = `لا يمكن أن تتجاوز الفترة ${MAX_DATE_SPAN + 1} يومًا متتاليًا (مدة تقويمية بين التاريخين).`;
    }
  }

  let queryError = '';
  if (q !== '' && q.length < MIN_QUERY_LENGTH) queryError = 'اكتب حرفين على الأقل للبحث عن موظف.';
  else if (q.length > MAX_QUERY_LENGTH) queryError = `يجب ألا يتجاوز البحث ${MAX_QUERY_LENGTH} حرفًا.`;

  let page = 1;
  let pageInvalid = false;
  if (pageRaw !== '') {
    if (!/^\d+$/.test(pageRaw)) pageInvalid = true;
    else {
      const value = Number(pageRaw);
      if (!Number.isSafeInteger(value) || value < 1 || value > MAX_PAGE) pageInvalid = true;
      else page = value;
    }
  }

  const selectionInvalid = (employee === '') !== (employment === '')
    || (employee !== '' && !isUuid(employee))
    || (employment !== '' && !isUuid(employment));

  return {
    start,
    end,
    datesProvided,
    dateError,
    q,
    queryError,
    page,
    pageInvalid,
    employee: selectionInvalid ? '' : employee,
    employment: selectionInvalid ? '' : employment,
    selectionInvalid,
  };
}

export function recordHref(tenantId: string, values: {
  start?: string;
  end?: string;
  q?: string;
  page?: number;
  employee?: string;
  employment?: string;
}): string {
  const params = new URLSearchParams();
  if (values.start) params.set('start', values.start);
  if (values.end) params.set('end', values.end);
  if (values.q) params.set('q', values.q);
  if (values.page && values.page > 1) params.set('page', String(values.page));
  if (values.employee && values.employment) {
    params.set('employee', values.employee);
    params.set('employment', values.employment);
  }
  const search = params.toString();
  return `/tenant/${tenantId}/leave/new${search ? `?${search}` : ''}`;
}

export function mapRecordError(message: string, code?: string): RecordErrorCode {
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_new_work_disabled')) return 'new-work-disabled';
  if (message.includes('leave_half_day_part_invalid') || message.includes('leave_half_day_part_unavailable')) return 'part';
  if (message.includes('leave_half_day')) return 'half-day';
  if (message.includes('leave_request_range_invalid')) return 'range';
  if (message.includes('leave_request_input_invalid') || message.includes('leave_employee_options_input_invalid')) return 'input';
  if (message.includes('leave_type_unavailable')) return 'type';
  if (message.includes('leave_year_period_unavailable') || message.includes('leave_calendar_version_unavailable')
    || message.includes('leave_calendar_unavailable') || message.includes('leave_type_version_unavailable')) return 'configuration';
  if (message.includes('leave_request_zero_days')) return 'zero-days';
  if (message.includes('leave_employment_range_unavailable')) return 'employment';
  if (message.includes('leave_employee_unavailable') || message.includes('leave_employer_unavailable')) return 'unavailable';
  if (message.includes('leave_approval_queue_unavailable')) return 'queue';
  if (message.includes('leave_forbidden') || message.includes('leave_self_forbidden') || code === '42501') return 'forbidden';
  if (code === '22023') return 'input';
  if (!code) return 'unknown';
  return 'failed';
}

const RECORD_ERROR_TEXT: Record<RecordErrorCode, string> = {
  input: 'راجع بيانات الطلب ثم أعد المحاولة.',
  range: `اختر تاريخ بداية ونهاية صحيحين، بحد أقصى ${MAX_DATE_SPAN + 1} يومًا متتاليًا (مدة تقويمية) في التسجيل الواحد.`,
  reason: `اكتب سببًا واضحًا من ${MIN_REASON_LENGTH} إلى ${MAX_REASON_LENGTH} حرفًا.`,
  'half-day': 'طلب نصف يوم يتطلب تاريخَي بداية ونهاية متطابقين، ونوعًا يسمح بنصف يوم في هذا التاريخ ويومًا يمكن احتسابه.',
  part: 'اختر جزء نصف اليوم المطابق لدوام الموظف؛ ولا يُحدَّد جزء حين يكون الدوام مرنًا أو الاحتساب للإجازة فقط.',
  type: 'نوع الإجازة المحدد لم يعد متاحًا لهذه الجهة أو الفترة. حدّث الصفحة واختر نوعًا آخر.',
  configuration: 'فترة أو تقويم الإجازات غير مهيأين لهذه التواريخ. راجع إعدادات إجازات الجهة ثم أعد المحاولة.',
  'zero-days': 'لا توجد أيام يمكن احتسابها ضمن التاريخين المحددين. اختر تواريخ أخرى.',
  employment: 'بيانات عمل الموظف لم تعد تغطي التواريخ المحددة. حدّث البحث واختر موظفًا أو تواريخ أخرى.',
  unavailable: 'الموظف أو جهة العمل لم يعد متاحًا لتسجيل طلبات الإجازة. عُد إلى البحث ثم أعد المحاولة.',
  queue: 'إرسال طلبات الإجازة غير متاح حاليًا في الشركة. تواصل مع إدارة الموارد البشرية.',
  'key-conflict': 'تعارض في مفتاح التنفيذ مع محاولة سابقة ببيانات مختلفة. حدّث الصفحة وسجّل التغيير كطلب جديد.',
  'new-work-disabled': 'خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، فلا يمكن تسجيل طلبات جديدة. إن سبق أن حاولت التسجيل، راجع قائمة الطلبات للتحقق من النتيجة.',
  forbidden: 'ليست لديك صلاحية تسجيل طلبات إجازة الموظفين في هذه الشركة. راجع إدارة الموارد البشرية.',
  access: 'تعذر التحقق من صلاحيتك الآن. أعد المحاولة لاحقًا.',
  'half-day-context': 'تعذر تأكيد إعدادات نصف اليوم لهذا التاريخ الآن. أعد المحاولة بنفس البيانات؛ لا تغيّر مدة الإجازة بسبب هذا الخطأ.',
  session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
  setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
  failed: 'تعذر تأكيد التسجيل. راجع قائمة الطلبات، أو أعد المحاولة بنفس البيانات دون تحديث هذه الصفحة.',
  unknown: 'تعذر تأكيد نتيجة التسجيل؛ قد يكون الطلب سُجّل بالفعل. أعد المحاولة بنفس البيانات دون تحديث هذه الصفحة، أو راجع قائمة الطلبات قبل تسجيل طلب آخر.',
};

export function recordErrorText(code: RecordErrorCode): string {
  return RECORD_ERROR_TEXT[code] ?? RECORD_ERROR_TEXT.failed;
}
