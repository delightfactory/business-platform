import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
export type RequestState = 'draft' | 'submitted' | 'approved' | 'rejected' | 'withdrawn' | 'cancelled' | 'superseded';

export function isRequestState(value: unknown): value is RequestState {
  return value === 'draft' || value === 'submitted' || value === 'approved' || value === 'rejected'
    || value === 'withdrawn' || value === 'cancelled' || value === 'superseded';
}

export function stateLabel(state: string): string {
  if (state === 'submitted') return 'مُقدَّم وبانتظار القرار';
  if (state === 'withdrawn') return 'مسحوب';
  if (state === 'rejected') return 'مرفوض';
  if (state === 'draft') return 'مسودة';
  if (state === 'approved') return 'معتمد';
  if (state === 'cancelled') return 'ملغى';
  if (state === 'superseded') return 'مستبدَل';
  return 'غير محدّد';
}

export function stateClass(state: string): string {
  if (state === 'submitted') return 'is-pending';
  if (state === 'approved') return 'is-active';
  return 'is-inactive';
}

export function formatDays(value: number): string {
  return String(value);
}

export function formatInstant(value: string): string {
  const instant = new Date(value);
  if (Number.isNaN(instant.getTime())) return value;
  return instant.toLocaleString(ARABIC_DISPLAY_LOCALE, { timeZone: 'Africa/Cairo', dateStyle: 'short', timeStyle: 'short' });
}
