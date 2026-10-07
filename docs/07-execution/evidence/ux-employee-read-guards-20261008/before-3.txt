import { isObject, isUuid } from '../form-rules';

export const CANCELLATION_HISTORY_LIMIT = 50;

// p_offset is a PostgreSQL integer: stay inside its signed 32-bit bound on a 50-step grid.
export const CANCELLATION_OFFSET_MAX = 2147483600;

export type RequestCancellationState = { error: string; attempt: number };

export type CancellationEvent = {
  id: number;
  cancellation_id: string | null;
  actor_user_id: string;
  event_key: string;
  from_state: string | null;
  to_state: string;
  reason: string;
  time_reconciliation_required: boolean;
  created_at: string;
};

export type CancellationHistoryPage = {
  offset: number;
  items: CancellationEvent[];
  hasMore: boolean;
  latest: CancellationEvent | null;
};

export function readHistoryPage(data: unknown, offset: number): CancellationHistoryPage | null {
  if (!isObject(data) || !Array.isArray(data.items) || typeof data.has_more !== 'boolean') return null;
  const items: CancellationEvent[] = [];
  for (const entry of data.items) {
    const event = readCancellationEvent(entry);
    if (!event) return null;
    items.push(event);
  }
  const latest = data.latest_event === null ? null : readCancellationEvent(data.latest_event);
  if (data.latest_event !== null && !latest) return null;
  return { offset, items, hasMore: data.has_more, latest };
}

function readCancellationEvent(value: unknown): CancellationEvent | null {
  if (!isObject(value)) return null;
  const id = typeof value.id === 'number' ? value.id
    : typeof value.id === 'string' && /^\d+$/.test(value.id) ? Number(value.id) : Number.NaN;
  if (!Number.isSafeInteger(id) || id < 0) return null;
  if (!(value.cancellation_id === null || isUuid(value.cancellation_id))) return null;
  if (!isUuid(value.actor_user_id)) return null;
  if (typeof value.event_key !== 'string' || typeof value.to_state !== 'string') return null;
  if (!(value.from_state === null || typeof value.from_state === 'string')) return null;
  if (typeof value.reason !== 'string' || typeof value.created_at !== 'string') return null;
  if (typeof value.time_reconciliation_required !== 'boolean') return null;
  return {
    id,
    cancellation_id: value.cancellation_id,
    actor_user_id: value.actor_user_id,
    event_key: value.event_key,
    from_state: value.from_state,
    to_state: value.to_state,
    reason: value.reason,
    time_reconciliation_required: value.time_reconciliation_required,
    created_at: value.created_at,
  };
}

export function parseHistoryOffset(raw: string | string[] | undefined): { value: number; invalid: boolean } {
  if (raw === undefined) return { value: 0, invalid: false };
  if (typeof raw !== 'string' || !/^\d+$/.test(raw)) return { value: 0, invalid: true };
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value % CANCELLATION_HISTORY_LIMIT !== 0
    || value > CANCELLATION_OFFSET_MAX) return { value: 0, invalid: true };
  return { value, invalid: false };
}

export function historyPageNumber(offset: number): number {
  return Math.floor(offset / CANCELLATION_HISTORY_LIMIT) + 1;
}

export function cancellationStateLabel(state: string): string {
  if (state === 'pending') return 'معلّق بانتظار القرار';
  if (state === 'accepted') return 'مقبول';
  if (state === 'rejected') return 'مرفوض';
  if (state === 'cancelled') return 'ملغى';
  if (state === 'approved') return 'معتمد';
  return 'غير محدّد';
}

export function cancellationStateClass(state: string): string {
  if (state === 'pending') return 'is-pending';
  if (state === 'accepted' || state === 'approved') return 'is-active';
  return 'is-inactive';
}

export function cancellationEventLabel(eventKey: string): string {
  if (eventKey === 'employee.requested') return 'طلب إلغاء منك';
  if (eventKey === 'hr.requested') return 'طلب إلغاء من الموارد البشرية';
  if (eventKey === 'hr.accepted') return 'قبول طلب الإلغاء';
  if (eventKey === 'hr.rejected') return 'رفض طلب الإلغاء';
  if (eventKey === 'hr.direct_cancelled') return 'إلغاء من الموارد البشرية';
  return 'حركة في طلب الإلغاء';
}

export function cancellationEventActor(event: CancellationEvent, currentUserId: string): string {
  if (event.actor_user_id === currentUserId) return 'بواسطتك';
  if (event.event_key.startsWith('hr.')) return 'بواسطة إدارة الموارد البشرية';
  return 'بواسطة مسؤول الشركة';
}

export function mapCancellationError(message: string, code?: string): string {
  if (message.includes('leave_cancellation_input_invalid')) return 'invalid';
  if (message.includes('leave_idempotency_conflict')) return 'key-conflict';
  if (message.includes('leave_cancellation_pending')) return 'already-pending';
  if (message.includes('leave_cancellation_request_unavailable')) return 'not-approved';
  if (message.includes('leave_request_version_conflict')) return 'conflict';
  if (message.includes('leave_approval_queue_unavailable')) return 'queue';
  if (message.includes('leave_request_unavailable') || code === 'P0002') return 'unavailable';
  if (message.includes('leave_forbidden') || code === '42501') return 'forbidden';
  if (message.includes('JWT') || code === 'PGRST301') return 'session';
  if (code === 'PGRST202') return 'setup';
  return 'unknown';
}

export function cancellationErrorText(code: string): string {
  const messages: Record<string, string> = {
    invalid: 'تعذر تنفيذ طلب الإلغاء. حدّث الصفحة ثم أعد المحاولة.',
    version: 'رقم إصدار الطلب غير صالح أو تغيّر منذ فتح الصفحة. حدّث الصفحة ثم أعد المحاولة.',
    reason: 'اكتب سبب طلب الإلغاء من 3 إلى 500 حرف.',
    conflict: 'تغيّر الطلب منذ فتح الصفحة. حدّث الصفحة ثم أعد المحاولة.',
    unavailable: 'هذا الطلب غير متاح لحسابك لطلب الإلغاء: تأكد أن حسابك ما زال مرتبطًا بملف الموظف صاحب الطلب وأن الطلب محفوظ، ثم أعد المحاولة أو راجع إدارة الموارد البشرية.',
    forbidden: 'ليست لديك صلاحية طلب إلغاء هذا الطلب من هذا الحساب. راجع إدارة الموارد البشرية.',
    'not-approved': 'لم يعد هذا الطلب في حالة «معتمد» القابلة للإلغاء. حدّث الصفحة وراجع حالته وسجل طلبات الإلغاء قبل أي إجراء جديد.',
    'already-pending': 'يوجد طلب إلغاء معلق لهذا الطلب بالفعل، وهو بانتظار قرار الموارد البشرية. حدّث الصفحة لرؤيته في سجل طلبات الإلغاء، ولا ترسل طلبًا آخر حاليًا.',
    queue: 'لا يوجد حاليًا موافق معتمد في الموارد البشرية لتغطية قرار الإلغاء. أعد المحاولة لاحقًا أو تواصل مع إدارة الموارد البشرية.',
    'key-conflict': 'تعارض مفتاح العملية مع بيانات مختلفة محفوظة سابقًا. غيّر سبب الطلب لإنشاء مفتاح جديد، أو حدّث الصفحة وتحقق من سجل طلبات الإلغاء أولًا.',
    session: 'انتهت الجلسة. سجّل الدخول من جديد ثم أعد المحاولة.',
    setup: 'الاتصال بخدمة الحسابات غير متاح الآن. أعد المحاولة لاحقًا.',
    unknown: 'تعذّر تأكيد نتيجة طلب الإلغاء، وقد يكون الطلب قد سُجّل. حدّث الصفحة وتحقق من سجل طلبات الإلغاء قبل تغيير أي بيانات، أو أعد المحاولة بنفس السبب دون تعديل.',
  };
  return messages[code] ?? messages.unknown;
}

export function mapHistoryError(message: string, code?: string): string {
  if (message.includes('leave_page_invalid')) return 'invalid-page';
  if (message.includes('leave_request_unavailable') || code === 'P0002') return 'unavailable';
  if (message.includes('leave_forbidden') || code === '42501') return 'forbidden';
  if (message.includes('JWT') || code === 'PGRST301') return 'session';
  return 'failed';
}

export function historyErrorText(code: string): string {
  const messages: Record<string, string> = {
    unavailable: 'هذا الطلب غير متاح لعرض سجل الإلغاء من هذا الحساب؛ تأكد أن حسابك ما زال مرتبطًا بملف الموظف صاحب الطلب.',
    forbidden: 'ليست لديك صلاحية عرض سجل طلبات الإلغاء لهذا الطلب.',
    session: 'انتهت الجلسة. سجّل الدخول من جديد لعرض السجل.',
    'invalid-page': 'رقم صفحة سجل الإلغاء غير صالح.',
    failed: 'تعذر تحميل سجل طلبات الإلغاء الآن.',
  };
  return messages[code] ?? messages.failed;
}
