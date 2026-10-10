import type { Tone } from '@/components/ui/primitives';
import { channelStateLabel } from '@/lib/attendance-channel';
import { stateLabel as employeeLeaveStateLabel } from '@/app/tenant/[tenantId]/me/leave/states';
import { stateLabel as hrLeaveStateLabel } from '@/app/tenant/[tenantId]/leave/rules';

export type DisplayStatus = { label: string; tone: Tone };
const attendanceLabels: Record<string, string> = { open: 'قيد المتابعة', ready: 'جاهز للمراجعة', needs_review: 'يحتاج مراجعة', approved: 'معتمد' };
const attendanceTones: Record<string, Tone> = { open: 'neutral', ready: 'info', needs_review: 'warn', approved: 'ok' };
const exceptionLabels: Record<string, string> = { ambiguous_local_time: 'وقت غير واضح حسب المنطقة الزمنية', conflicting_punches: 'تعارض في تسجيلات الحضور والانصراف', outside_window: 'التسجيل خارج الفترة المسموح بها', missing_punch: 'ينقص تسجيل حضور أو انصراف', short_workday: 'مدة العمل أقل من المطلوب', absence_candidate: 'لا توجد تسجيلات بعد انتهاء اليوم' };
export function attendanceStatus(state: string): DisplayStatus { return { label: attendanceLabels[state] ?? 'قيد المتابعة', tone: attendanceTones[state] ?? 'neutral' }; }
export function attendanceException(code: string): DisplayStatus { return { label: exceptionLabels[code] ?? 'تحتاج الحالة إلى مراجعة فردية', tone: ['conflicting_punches', 'ambiguous_local_time', 'outside_window'].includes(code) ? 'bad' : 'warn' }; }
export function channelStatus(state: string): DisplayStatus { const tones: Record<string, Tone> = { accepted: 'ok', duplicate: 'neutral', received: 'info', retrying: 'info', rejected: 'bad', blocked: 'bad', unmapped: 'warn', retry_failed: 'warn' }; return { label: channelStateLabel(state), tone: tones[state] ?? 'warn' }; }
export function leaveStatus(state: string, audience: 'employee' | 'hr' = 'employee'): DisplayStatus { const tone: Tone = state === 'submitted' ? 'warn' : state === 'approved' ? 'ok' : state === 'rejected' ? 'bad' : 'neutral'; return { label: audience === 'hr' ? hrLeaveStateLabel(state) : employeeLeaveStateLabel(state), tone }; }
export function payrollStatusTone(state: string): Tone { return ({ draft: 'neutral', review: 'info', approved: 'ok', locked: 'ok', cancelled: 'neutral', superseded: 'neutral', partially_paid: 'warn', paid: 'ok' } as Record<string, Tone>)[state] ?? 'neutral'; }
