export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const MAX_CODE_LENGTH = 60;
export const MAX_NAME_LENGTH = 160;
export const MAX_LABEL_LENGTH = 120;
export const MAX_SOURCE_LENGTH = 300;
export const MAX_REASON_LENGTH = 500;
export const MIN_REASON_LENGTH = 3;
export const MAX_HOLIDAY_ROWS = 400;

export const WEEKDAY_LABELS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

export type PayEffect = 'paid' | 'unpaid';
export type BalanceMode = 'tracked' | 'untracked';
export type DayCountBasis = 'working_days' | 'calendar_days';

export type HolidayRow = { date: string; name: string };

export type EmployerInfo = { id: string; display_name: string; is_active: boolean };

export type SettingsAccess = {
  canView: boolean;
  canManage: boolean;
  newWorkEnabled: boolean;
};

export type CalendarVersion = {
  id: string;
  version: number;
  effective_from: string;
  effective_until: string | null;
  timezone: string;
  source: string;
  rest_weekdays: number[];
  holidays: HolidayRow[];
};

export type CalendarSummary = {
  id: string;
  code: string;
  name: string;
  versions: CalendarVersion[];
};

export type TypeVersion = {
  id: string;
  version: number;
  effective_from: string;
  effective_until: string | null;
  pay_effect: PayEffect;
  balance_mode: BalanceMode;
  day_count_basis: DayCountBasis;
  half_day_allowed: boolean;
  source: string;
};

export type LeaveTypeSummary = {
  id: string;
  code: string;
  name: string;
  is_active: boolean;
  versions: TypeVersion[];
};

export type YearPeriod = {
  id: string;
  calendar_id: string;
  starts_on: string;
  ends_on: string;
  label: string;
};

export type Configuration = {
  calendars: CalendarSummary[];
  types: LeaveTypeSummary[];
  yearPeriods: YearPeriod[];
};

export type CreateCalendarState = {
  code: string;
  name: string;
  effectiveFrom: string;
  effectiveUntil: string;
  restDays: number[];
  holidays: HolidayRow[];
  source: string;
  reason: string;
  error: string;
  attempt: number;
};

export type ReviseCalendarState = {
  effectiveFrom: string;
  effectiveUntil: string;
  restDays: number[];
  holidays: HolidayRow[];
  source: string;
  reason: string;
  error: string;
  attempt: number;
};

export type CreateYearPeriodState = {
  calendarId: string;
  startsOn: string;
  endsOn: string;
  label: string;
  reason: string;
  error: string;
  attempt: number;
};

export type CreateTypeState = {
  code: string;
  name: string;
  effectiveFrom: string;
  payEffect: PayEffect;
  balanceMode: BalanceMode;
  dayCountBasis: DayCountBasis;
  halfDay: boolean;
  source: string;
  reason: string;
  error: string;
  attempt: number;
};

export type ReviseTypeState = {
  effectiveFrom: string;
  payEffect: PayEffect;
  balanceMode: BalanceMode;
  dayCountBasis: DayCountBasis;
  halfDay: boolean;
  source: string;
  reason: string;
  error: string;
  attempt: number;
};

export type ActivationState = {
  reason: string;
  error: string;
  attempt: number;
};

export const EMPTY_CALENDAR_FORM: CreateCalendarState = {
  code: '', name: '', effectiveFrom: '', effectiveUntil: '', restDays: [], holidays: [],
  source: '', reason: '', error: '', attempt: 0,
};

export const EMPTY_YEAR_PERIOD_FORM: CreateYearPeriodState = {
  calendarId: '', startsOn: '', endsOn: '', label: '', reason: '', error: '', attempt: 0,
};

export const EMPTY_REVISE_CALENDAR_FORM: ReviseCalendarState = {
  effectiveFrom: '', effectiveUntil: '', restDays: [], holidays: [], source: '', reason: '',
  error: '', attempt: 0,
};

export const EMPTY_CREATE_TYPE_FORM: CreateTypeState = {
  code: '', name: '', effectiveFrom: '', payEffect: 'paid', balanceMode: 'tracked',
  dayCountBasis: 'working_days', halfDay: false, source: '', reason: '', error: '', attempt: 0,
};

export const EMPTY_REVISE_TYPE_FORM: ReviseTypeState = {
  effectiveFrom: '', payEffect: 'paid', balanceMode: 'tracked', dayCountBasis: 'working_days',
  halfDay: false, source: '', reason: '', error: '', attempt: 0,
};

export const EMPTY_ACTIVATION_FORM: ActivationState = {
  reason: '', error: '', attempt: 0,
};

export type ConfigOperation =
  | 'calendar-create'
  | 'calendar-revise'
  | 'period-create'
  | 'type-create'
  | 'type-revise'
  | 'type-activate';

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function isDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = Date.parse(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed) && new Date(parsed).toISOString().slice(0, 10) === value;
}

export function cairoToday(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
}

export function readAccess(value: unknown): SettingsAccess | null {
  if (!isObject(value)) return null;
  if (typeof value.can_view !== 'boolean' || typeof value.can_manage !== 'boolean'
    || typeof value.new_work_enabled !== 'boolean') return null;
  return {
    canView: value.can_view,
    canManage: value.can_manage,
    newWorkEnabled: value.new_work_enabled,
  };
}

export function readEmployer(value: unknown): EmployerInfo | null {
  if (!isObject(value) || !isUuid(value.id) || typeof value.display_name !== 'string'
    || value.display_name.length === 0 || typeof value.is_active !== 'boolean') return null;
  return { id: value.id, display_name: value.display_name, is_active: value.is_active };
}

export type EmployerPage = {
  items: EmployerInfo[];
  hasMore: boolean;
  nextAfterName: string | null;
  nextAfterId: string | null;
};

export function readEmployerPage(value: unknown): EmployerPage | null {
  if (!isObject(value) || !Array.isArray(value.items) || typeof value.has_more !== 'boolean') return null;
  const items: EmployerInfo[] = [];
  for (const entry of value.items) {
    const employer = readEmployer(entry);
    if (!employer) return null;
    items.push(employer);
  }
  if (items.length > 100) return null;
  const nextName = value.next_after_name === null ? null : value.next_after_name;
  const nextId = value.next_after_id === null ? null : value.next_after_id;
  if (value.has_more) {
    if (typeof nextName !== 'string' || nextName.length === 0 || !isUuid(nextId)) return null;
  } else if (nextName !== null || nextId !== null) {
    return null;
  }
  return {
    items,
    hasMore: value.has_more,
    nextAfterName: typeof nextName === 'string' ? nextName : null,
    nextAfterId: typeof nextId === 'string' ? nextId : null,
  };
}

export function readConfiguration(value: unknown): Configuration | null {
  if (!isObject(value) || !Array.isArray(value.calendars) || !Array.isArray(value.types)
    || !Array.isArray(value.year_periods)) return null;
  const calendars: CalendarSummary[] = [];
  for (const entry of value.calendars) {
    if (!isObject(entry) || !isUuid(entry.calendar_id) || typeof entry.code !== 'string'
      || typeof entry.name !== 'string' || !Array.isArray(entry.versions)) return null;
    const versions: CalendarVersion[] = [];
    for (const raw of entry.versions) {
      if (!isObject(raw) || !isUuid(raw.id) || !isInteger(raw.version) || raw.version < 1
        || !isDate(String(raw.effective_from))
        || !(raw.effective_until === null || isDate(String(raw.effective_until)))
        || typeof raw.timezone !== 'string' || typeof raw.source !== 'string'
        || !Array.isArray(raw.rest_weekdays) || !Array.isArray(raw.holidays)) return null;
      const restWeekdays: number[] = [];
      for (const weekday of raw.rest_weekdays) {
        if (!isInteger(weekday) || weekday < 0 || weekday > 6) return null;
        restWeekdays.push(weekday);
      }
      const holidays: HolidayRow[] = [];
      for (const holiday of raw.holidays) {
        if (!isObject(holiday) || !isDate(String(holiday.date)) || typeof holiday.name !== 'string') return null;
        holidays.push({ date: String(holiday.date), name: holiday.name });
      }
      versions.push({
        id: raw.id,
        version: raw.version,
        effective_from: String(raw.effective_from),
        effective_until: raw.effective_until === null ? null : String(raw.effective_until),
        timezone: raw.timezone,
        source: raw.source,
        rest_weekdays: restWeekdays,
        holidays,
      });
    }
    calendars.push({ id: entry.calendar_id, code: entry.code, name: entry.name, versions });
  }
  const types: LeaveTypeSummary[] = [];
  for (const entry of value.types) {
    if (!isObject(entry) || !isUuid(entry.id) || typeof entry.code !== 'string'
      || typeof entry.name !== 'string' || typeof entry.is_active !== 'boolean'
      || !Array.isArray(entry.versions)) return null;
    const versions: TypeVersion[] = [];
    for (const raw of entry.versions) {
      if (!isObject(raw) || !isUuid(raw.id) || !isInteger(raw.version) || raw.version < 1
        || !isDate(String(raw.effective_from))
        || !(raw.effective_until === null || isDate(String(raw.effective_until)))
        || !isPayEffect(raw.pay_effect) || !isBalanceMode(raw.balance_mode)
        || !isDayCountBasis(raw.day_count_basis) || typeof raw.half_day_allowed !== 'boolean'
        || typeof raw.source !== 'string') return null;
      versions.push({
        id: raw.id,
        version: raw.version,
        effective_from: String(raw.effective_from),
        effective_until: raw.effective_until === null ? null : String(raw.effective_until),
        pay_effect: raw.pay_effect,
        balance_mode: raw.balance_mode,
        day_count_basis: raw.day_count_basis,
        half_day_allowed: raw.half_day_allowed,
        source: raw.source,
      });
    }
    types.push({ id: entry.id, code: entry.code, name: entry.name, is_active: entry.is_active, versions });
  }
  const yearPeriods: YearPeriod[] = [];
  for (const raw of value.year_periods) {
    if (!isObject(raw) || !isUuid(raw.id) || !isUuid(raw.calendar_id)
      || !isDate(String(raw.starts_on)) || !isDate(String(raw.ends_on))
      || typeof raw.label !== 'string') return null;
    yearPeriods.push({
      id: raw.id,
      calendar_id: raw.calendar_id,
      starts_on: String(raw.starts_on),
      ends_on: String(raw.ends_on),
      label: raw.label,
    });
  }
  return { calendars, types, yearPeriods };
}

function isInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value);
}

export function isPayEffect(value: unknown): value is PayEffect {
  return value === 'paid' || value === 'unpaid';
}

export function isBalanceMode(value: unknown): value is BalanceMode {
  return value === 'tracked' || value === 'untracked';
}

export function isDayCountBasis(value: unknown): value is DayCountBasis {
  return value === 'working_days' || value === 'calendar_days';
}

export function payEffectLabel(value: PayEffect): string {
  return value === 'paid' ? 'الإجازة بأجر' : 'الإجازة بدون أجر';
}

export function balanceModeLabel(value: BalanceMode): string {
  return value === 'tracked' ? 'تُخصم أيامها من الرصيد' : 'لا تُخصم من الرصيد';
}

export function dayCountBasisLabel(value: DayCountBasis): string {
  return value === 'working_days' ? 'أيام العمل في التقويم (تستثني الراحة والعطلات)'
    : 'أيام تقويمية متتالية';
}

export function halfDayLabel(value: boolean): string {
  return value ? 'مسموح' : 'غير مسموح';
}

export function restDaysText(days: number[]): string {
  if (days.length === 0) return 'لا توجد أيام راحة أسبوعية محددة';
  return [...days].sort((a, b) => a - b).map((day) => WEEKDAY_LABELS[day] ?? String(day)).join('، ');
}

export function effectiveRangeText(from: string, until: string | null): string {
  return until
    ? `من ${from} إلى ما قبل ${until}`
    : `من ${from} · بدون نهاية محددة`;
}

export function periodRangeText(starts: string, ends: string): string {
  return `من ${starts} حتى ${ends}، شاملًا يوم النهاية`;
}

export function versionText(version: number): string {
  return `الإصدار ${version}`;
}

export function calendarCoverageText(calendar: CalendarSummary): string {
  if (calendar.versions.length === 0) return 'لا توجد إصدارات بعد';
  const starts = calendar.versions.map((version) => version.effective_from).sort();
  const last = calendar.versions.reduce<string | null>((acc, version) => {
    if (version.effective_until === null) return null;
    return acc === null || version.effective_until > acc ? version.effective_until : acc;
  }, null);
  const openEnded = calendar.versions.some((version) => version.effective_until === null);
  const start = starts[0];
  return openEnded ? `تغطية من ${start} (مفتوحة)` : last
    ? `تغطية من ${start} حتى ${last} — ${last} أول يوم خارج التغطية`
    : 'لا توجد تغطية';
}

export function parseRestDays(values: unknown[]): number[] | null {
  const days = new Set<number>();
  for (const value of values) {
    const text = String(value);
    if (!/^\d$/.test(text)) return null;
    const day = Number(text);
    if (day < 0 || day > 6) return null;
    days.add(day);
  }
  if (days.size > 7) return null;
  return [...days].sort((a, b) => a - b);
}

export function readHolidayRows(formData: FormData): HolidayRow[] {
  const dates = formData.getAll('holidayDate').map((value) => String(value ?? '').trim());
  const names = formData.getAll('holidayName').map((value) => String(value ?? '').trim());
  const length = Math.max(dates.length, names.length);
  const rows: HolidayRow[] = [];
  for (let index = 0; index < length; index += 1) {
    rows.push({ date: dates[index] ?? '', name: names[index] ?? '' });
  }
  return rows;
}

export type HolidayProblem =
  | 'too-many'
  | 'half-filled'
  | 'bad-date'
  | 'before-start'
  | 'after-end'
  | 'duplicate-date'
  | 'long-name'
  | null;

export function holidaysProblem(rows: HolidayRow[], effectiveFrom: string, effectiveUntil: string): HolidayProblem {
  if (rows.length > MAX_HOLIDAY_ROWS) return 'too-many';
  const dates = new Set<string>();
  for (const row of rows) {
    if (!row.date && !row.name) continue;
    if (!row.date || !row.name) return 'half-filled';
    if (!isDate(row.date)) return 'bad-date';
    if (row.name.length > MAX_NAME_LENGTH) return 'long-name';
    if (effectiveFrom && row.date < effectiveFrom) return 'before-start';
    if (effectiveUntil && row.date >= effectiveUntil) return 'after-end';
    if (dates.has(row.date)) return 'duplicate-date';
    dates.add(row.date);
  }
  return null;
}

export function mapConfigError(message: string, code?: string): string {
  if (message.includes('leave_forbidden') || code === '42501') return 'forbidden';
  if (message.includes('leave_new_work_disabled')) return 'new-work-disabled';
  if (message.includes('leave_calendar_revision_breaks_year_period')) return 'coverage';
  if (message.includes('leave_calendar_revision_invalid') || message.includes('leave_type_revision_invalid')) return 'conflict';
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_calendar_input_invalid')) return 'calendar-input';
  if (message.includes('leave_type_input_invalid')) return 'type-input';
  if (message.includes('leave_type_activation_input_invalid')) return 'activation-input';
  if (message.includes('leave_year_period_invalid')) return 'period-input';
  if (message.includes('leave_employer_unavailable') || message.includes('leave_employer_or_calendar_unavailable')
    || message.includes('leave_calendar_unavailable') || message.includes('leave_type_unavailable')) return 'unavailable';
  if (code === '23505') {
    if (message.includes('calendar_holidays')) return 'duplicate-date';
    if (message.includes('year_periods')) return 'duplicate-period';
    if (message.includes('calendars') || message.includes('types')) return 'duplicate-code';
    return 'duplicate';
  }
  if (code === '23P01') return 'conflict';
  if (code === '22023') return 'input';
  if (code === 'P0002') return 'unavailable';
  return 'unknown';
}

const COMMON_ERROR_TEXT: Record<string, string> = {
  forbidden: 'ليست لديك صلاحية إدارة إعدادات الإجازات في هذه الشركة. راجع إدارة الموارد البشرية.',
  'new-work-disabled': 'خدمة إدارة الموظفين أو الإجازات موقوفة حاليًا، لذا لا يمكن إنشاء إعدادات جديدة أو إصدارات لاحقة. يمكنك مراجعة الإعدادات الحالية.',
  unavailable: 'التقويم أو الجهة أو النوع المطلوب لم يعد متاحًا. حدّث صفحة الإعدادات ثم أعد المحاولة.',
  conflict: 'تعارض مع إصدار أو فترة محفوظة حاليًا. حدّث الصفحة لعرض أحدث الإعدادات ثم عدّل التاريخ وأعد المحاولة؛ لن يُستبدل أي إصدار موجود.',
  coverage: 'هذا التعديل يترك فترة إجازات مسجلة خارج تغطية التقويم. عدّل التواريخ لتبقى الفترات الحالية مغطاة ثم أعد المحاولة.',
  'key-conflict': 'تعارض في مفتاح التنفيذ مع محاولة سابقة ببيانات مختلفة. حدّث الصفحة ثم ابدأ تغييرًا جديدًا بسبب جديد.',
  'duplicate-date': 'يوجد عطلة مسجلة بنفس التاريخ في هذه النسخة. راجع صفوف العطلات وأزِل التكرار قبل الحفظ.',
  setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
  session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
  invalid: 'راجع البيانات المدخلة ثم أعد المحاولة.',
  input: 'راجع البيانات المدخلة وفق الحدود الموضحة ثم أعد المحاولة.',
  reason: `اكتب سببًا من ${MIN_REASON_LENGTH} إلى ${MAX_REASON_LENGTH} حرفًا.`,
  source: `اكتب مصدر التعديل من 1 إلى ${MAX_SOURCE_LENGTH} حرفًا.`,
  'duplicate-code': 'الرمز مستخدم بالفعل. راجع السجل الموجود أو اختر رمزًا آخر. حُفظت مدخلاتك.',
};

const OPERATION_ERROR_TEXT: Record<ConfigOperation, Record<string, string>> = {
  'calendar-create': {
    ...COMMON_ERROR_TEXT,
    range: 'اختر تاريخ بداية صحيحًا؛ تاريخ النهاية اختياري ويجب أن يكون لاحقًا لبداية سريان التقويم.',
    'calendar-input': `راجع رمز التقويم (${MAX_CODE_LENGTH} حرفًا كحد أقصى) والاسم (${MAX_NAME_LENGTH} حرفًا) والتواريخ وأيام الراحة والعطلات (${MAX_HOLIDAY_ROWS} عطلة كحد أقصى).`,
    'duplicate-code': 'الرمز مستخدم لتقويم موجود. راجع التقويم أو اختر رمزًا آخر. حُفظت مدخلاتك.',
    unknown: 'تعذر تأكيد الإنشاء. راجع قائمة التقويمات قبل إعادة المحاولة أو تغيير الرمز. حُفظت مدخلاتك.',
  },
  'calendar-revise': {
    ...COMMON_ERROR_TEXT,
    range: 'اختر تاريخ بداية صحيحًا؛ تاريخ النهاية اختياري ويجب أن يكون لاحقًا لبداية سريان الإصدار.',
    'calendar-input': 'راجع تاريخ البداية (بعد اليوم بتوقيت القاهرة) والاختياري بعده وأيام الراحة وصفوف العطلات والمصدر والسبب.',
    future: 'تاريخ بدء الإصدار الجديد يجب أن يكون بعد تاريخ اليوم بتوقيت القاهرة. اختر تاريخًا لاحقًا.',
    unknown: 'تعذر تأكيد نتيجة حفظ الإصدار الجديد؛ قد يكون حُفظ أو لم يُحفظ. حدّث صفحة التقويم وراجع الإصدارات قبل إعادة المحاولة.',
  },
  'period-create': {
    ...COMMON_ERROR_TEXT,
    'period-input': 'راجع تواريخ سنة الرصيد وتغطية التقويم، واكتب اسمًا من 1 إلى 120 حرفًا.',
    'duplicate-period': 'توجد فترة إجازات بنفس تاريخي البداية والنهاية لدى الشركة. راجع السنوات الحالية قبل إنشاء فترة جديدة.',
    conflict: 'توجد فترة إجازات متداخلة أو مكررة مع التواريخ المختارة. حدّث الصفحة وراجع الفترات المسجلة ثم عدّل التواريخ.',
    label: `اكتب اسمًا لفترة الإجازات من 1 إلى ${MAX_LABEL_LENGTH} حرفًا.`,
    range: 'اختر تاريخ بداية ونهاية صحيحين، وليست النهاية قبل البداية.',
    unknown: 'تعذر تأكيد نتيجة إنشاء فترة الإجازات؛ قد أُنشئت أو لم تُنشأ. حدّث صفحة الإعدادات وراجع السنوات الحالية قبل إعادة الإرسال.',
  },
  'type-create': {
    ...COMMON_ERROR_TEXT,
    'type-input': `راجع رمز النوع (${MAX_CODE_LENGTH} حرفًا كحد أقصى) والاسم (${MAX_NAME_LENGTH} حرفًا) وتاريخ البداية وخيارات الأجر والرصيد واحتساب الأيام ونصف يوم والمصدر والسبب.`,
    unknown: 'تعذر تأكيد نتيجة إنشاء نوع الإجازة؛ قد أُنشئ أو لم يُنشأ. حدّث صفحة الإعدادات وراجع الأنواع الحالية قبل إعادة الإرسال أو اختيار رمز جديد.',
  },
  'type-revise': {
    ...COMMON_ERROR_TEXT,
    'type-input': 'راجع تاريخ البداية (بعد اليوم بتوقيت القاهرة) الخيارات الأربعة والمصدر والسبب.',
    future: 'تاريخ بدء الإصدار الجديد يجب أن يكون بعد تاريخ اليوم بتوقيت القاهرة. اختر تاريخًا لاحقًا.',
    unknown: 'تعذر تأكيد نتيجة حفظ الإصدار الجديد؛ قد يكون حُفظ أو لم يُحفظ. حدّث صفحة النوع وراجع الإصدارات قبل إعادة المحاولة.',
  },
  'type-activate': {
    ...COMMON_ERROR_TEXT,
    'activation-input': `اكتب سببًا من ${MIN_REASON_LENGTH} إلى ${MAX_REASON_LENGTH} حرفًا.`,
    'key-conflict': 'تعارض مفتاح التنفيذ: تغيّر السبب أو الهدف عن محاولة سابقة بالمفتاح نفسه. حدّث الصفحة ثم نفّذ تغييرًا جديدًا بسبب جديد.',
    unknown: 'تعذر تأكيد تغيير الحالة. أعد المحاولة بنفس السبب، أو راجع صفحة النوع للتحقق من حالته.',
  },
};

export function configErrorText(operation: ConfigOperation, code: string): string {
  const texts = OPERATION_ERROR_TEXT[operation];
  return texts[code] ?? texts.input ?? COMMON_ERROR_TEXT.input;
}

export type PageNotice = { tone: 'success' | 'info' | 'error'; message: string };

const NOTICE_TEXT: Record<string, PageNotice> = {
  'calendar-created': { tone: 'success', message: 'تم إنشاء تقويم الإجازات.' },
  'year-created': { tone: 'success', message: 'تم إنشاء سنة الرصيد.' },
  'type-created': { tone: 'success', message: 'تم إنشاء نوع الإجازة.' },
  'revision-created': { tone: 'success', message: 'تم حفظ الإصدار الجديد من تاريخ سريانه؛ الإصدارات السابقة تبقى محفوظة كما هي.' },
  'type-activated': { tone: 'success', message: 'تم تفعيل نوع الإجازة وسُجّل التغيير بسببه.' },
  'type-deactivated': { tone: 'success', message: 'تم إيقاف استخدام نوع الإجازة؛ تبقى إصداراته وسجلاته محفوظة.' },
  'type-unchanged': { tone: 'info', message: 'لم تتغير حالة التفعيل؛ لا حاجة لحفظ جديد.' },
  unavailable: {
    tone: 'error',
    message: 'التقويم أو الجهة أو النوع لم يعد متاحًا. عُدّلت الصفحة بأحدث الإعدادات؛ راجعها ثم أعد المحاولة.',
  },
};

export function noticeForState(state: string): PageNotice | null {
  return NOTICE_TEXT[state] ?? null;
}
