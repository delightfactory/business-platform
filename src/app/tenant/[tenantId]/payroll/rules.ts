import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
export type CalendarFields = { start: string; cutoff: string; payment: string; month: string; timezone: string; reason: string };
export type CalendarPreview = { starts_on: string; ends_on: string; payment_on: string; timezone: string; label: string; revision?: number; last_generated_end?: string | null; is_transition?: boolean };
export type CalendarState = CalendarFields & { error: string; preview: CalendarPreview | null; attemptKey: string; saved: boolean };
export const uuid = (value: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
export function errorText(code?: string, message?: string) {
 if (message?.includes('payroll_open_run')) return 'يوجد مسير مفتوح لهذه الجهة. ألغِه من مراجعة الرواتب أو أكمل مساره قبل تغيير الدورة.';
 if (message?.includes('payment_before_end')) return 'موعد الصرف يسبق نهاية الفترة. اختر يومًا لاحقًا أو الشهر التالي ثم أعد المعاينة.';
 if (message?.includes('transition_required')) return 'تبدأ النسخة الجديدة في اليوم التالي لآخر فترة محفوظة. راجع تاريخ البداية ثم أعد المعاينة.';
 if (message?.includes('future_required')) return 'تغيير الدورة يبدأ في تاريخ مستقبلي بعد آخر فترة محفوظة.';
 if (code === 'PT409') return 'تغيّر الإعداد أو تسلسل الفترات أثناء المراجعة. حدّث بيانات الدورة وأعد المعاينة؛ بياناتك محفوظة.';
 if (code === '42501') return 'لم تعد لهذا الحساب صلاحية الوصول إلى جهة العمل هذه. راجع مسؤول الشركة لاستعادة الوصول.';
 if (code === '55000') return 'إعداد الرواتب غير متاح الآن. راجع تفعيل الخدمة مع مسؤول الشركة ثم أعد المحاولة.';
 if (code === '22023') return 'راجع التاريخ والأيام والمنطقة الزمنية وسبب التغيير ثم أعد المعاينة.';
 return 'تعذر إتمام الطلب. بياناتك محفوظة؛ أعد المحاولة بنفس الطلب للتحقق من نتيجته.';
}
export function displayDate(value: string) {
 return new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE, { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' }).format(new Date(`${value}T12:00:00Z`));
}
