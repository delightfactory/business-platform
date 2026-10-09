import { ARABIC_DISPLAY_LOCALE } from '@/lib/display-locale';
export type LocationEvidence = { latitude: number; longitude: number; accuracy: number; captured_at: string };
export type MobileAttempt = { id: string; direction: 'in' | 'out'; happened_at: string; scope: string; policy_version: number; location: LocationEvidence | null };
export type MobileSnapshot = { scope: string; available: boolean; reason: string | null; next_direction: 'in' | 'out'; site_name: string | null; timezone_name: string | null; geofence_required: boolean; policy_version: number; retention_seconds: number; history: Array<{ id: string; direction: string; happened_at: string; state: string; reason: string | null; timezone_name: string | null; site_name?: string | null; timezone_is_fallback?: boolean; review_required?: boolean; review_decision?: { decision: string; reason: string; created_at: string; timezone_name: string; actor_label: string } | null }> };
export type PunchResult = { state: string; reason?: string | null; next_direction?: 'in' | 'out'; review?: boolean };
export function readMobileSnapshot(data: unknown): MobileSnapshot | null {
  const object = (value: unknown): value is Record<string, unknown> => !!value && typeof value === 'object' && !Array.isArray(value);
  const nullableText = (value: unknown) => value === null || typeof value === 'string';
  const optionalText = (value: unknown) => value === undefined || nullableText(value);
  const direction = (value: unknown) => value === 'in' || value === 'out';
  if (!object(data) || typeof data.scope !== 'string' || !data.scope.trim()
    || typeof data.available !== 'boolean' || !nullableText(data.reason) || !direction(data.next_direction)
    || !optionalText(data.site_name) || !optionalText(data.timezone_name) || typeof data.geofence_required !== 'boolean'
    || !Number.isInteger(data.policy_version) || (data.policy_version as number) < 0
    || !Number.isInteger(data.retention_seconds) || (data.retention_seconds as number) <= 0 || !Array.isArray(data.history)) return null;
  for (const item of data.history) {
    if (!object(item) || typeof item.id !== 'string' || typeof item.happened_at !== 'string'
      || !direction(item.direction) || typeof item.state !== 'string' || !nullableText(item.reason)
      || !optionalText(item.timezone_name) || !optionalText(item.site_name)
      || (item.timezone_is_fallback !== undefined && typeof item.timezone_is_fallback !== 'boolean')
      || (item.review_required !== undefined && typeof item.review_required !== 'boolean')) return null;
    const review = item.review_decision;
    if (review !== undefined && review !== null && (!object(review)
      || (review.decision !== 'accept' && review.decision !== 'exclude') || typeof review.reason !== 'string'
      || typeof review.created_at !== 'string' || typeof review.timezone_name !== 'string'
      || typeof review.actor_label !== 'string')) return null;
  }
  const snapshot = data as MobileSnapshot;
  return { ...snapshot, site_name: snapshot.site_name ?? null, timezone_name: snapshot.timezone_name ?? null,
    history: snapshot.history.map(item => ({ ...item, timezone_name: item.timezone_name ?? null })) };
}
export function channelStateLabel(state: string) { return ({ received: 'وصلت وبانتظار المعالجة', accepted: 'تم التسجيل', duplicate: 'مسجلة بالفعل', rejected: 'لم تُقبل', unmapped: 'تحتاج ربط الموظف', retry_failed: 'تعذرت المعالجة', retrying: 'جارٍ إعادة المعالجة', blocked: 'التسجيل غير متاح' } as Record<string,string>)[state] ?? 'تحتاج مراجعة'; }
export function channelReasonLabel(reason: string | null | undefined) { return ({ disabled: 'القناة موقوفة. تواصل مع المسؤول لاستخدام قناة حضور معتمدة.', entitlement: 'خدمة الحضور غير متاحة. تواصل مع المسؤول.', link: 'حسابك غير مرتبط بملف موظف. تواصل مع الموارد البشرية.', permission: 'ليست لديك صلاحية التسجيل. سجّل الدخول بالحساب المصرح له أو تواصل مع المسؤول.', assignment: 'لا يوجد موقع عمل سارٍ لحسابك. تواصل مع الموارد البشرية.', unconfigured: 'قناة موقعك لم تُعدّ بعد. تواصل مع المسؤول.', outside: 'أنت خارج نطاق موقع العمل. انتقل إلى الموقع أو تواصل مع المسؤول.', accuracy: 'دقة الموقع غير كافية. أعد المحاولة من مكان مفتوح.', unavailable: 'تعذر تحديد الموقع. راجع إذن الموقع أو تواصل مع المسؤول.', stale: 'دليل الموقع قديم. حضّر محاولة جديدة.', scope_changed: 'تغير حسابك أو سياق العمل. تحقق من المحاولة السابقة قبل تجهيز أخرى.', conflict: 'هذه المحاولة لها بيانات مختلفة مسجلة. تحقق من نتيجتها أو تواصل مع المسؤول.', direction: 'تغير الإجراء المطلوب. حدّث الصفحة قبل المحاولة.', time: 'وقت المحاولة غير صالح. تحقق من ساعة الهاتف وحضّر محاولة جديدة.', mapping_ambiguous: 'توجد أكثر من فترة ربط سارية لهذا المعرّف. راجع قرارات الربط وألغِ التداخل ثم أعد المعالجة.', mapping: 'اربط معرّف المصدر بالموظف والموقع خلال فترة الحدث ثم أعد المعالجة.', interpretation: 'تحتاج الحركة مراجعة في سجل الحضور.', policy_changed: 'تغيرت سياسة القناة. تحقق من المحاولة ثم حضّر أخرى.', cancelled: 'تأكد الخادم أن المحاولة لن تُسجّل. يمكنك تجهيز محاولة جديدة.', rate: 'محاولات كثيرة خلال وقت قصير. انتظر دقيقة ثم تحقق من المحاولة.' } as Record<string,string>)[reason ?? ''] ?? 'تعذر إكمال الطلب. أعد المحاولة أو تواصل مع المسؤول.'; }
export function formatChannelInstant(value: string, zone: string | null | undefined) { if (!zone) return 'التوقيت المحلي للحدث غير متاح'; try { return new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE, { dateStyle: 'medium', timeStyle: 'short', timeZone: zone }).format(new Date(value)); } catch { return 'التوقيت غير متاح'; } }
export function validAttempt(value: unknown, scope: string): value is MobileAttempt { if (!value || typeof value !== 'object') return false; const a=value as MobileAttempt; return a.scope===scope && /^[0-9a-f-]{36}$/i.test(a.id) && ['in','out'].includes(a.direction) && Number.isFinite(Date.parse(a.happened_at)) && Number.isInteger(a.policy_version) && (a.location===null || (Number.isFinite(a.location.latitude) && Math.abs(a.location.latitude)<=90 && Number.isFinite(a.location.longitude) && Math.abs(a.location.longitude)<=180 && Number.isFinite(a.location.accuracy) && a.location.accuracy>=0 && Number.isFinite(Date.parse(a.location.captured_at)))); }
