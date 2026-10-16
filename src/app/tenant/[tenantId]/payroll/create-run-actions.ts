'use server';

import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { errorText, uuid, type CalendarPreview } from './rules';

export type FirstRunFields = { start: string; cutoff: string; payment: string; month: string };
export type RunCreation = { mode: 'existing'; period: string } | { mode: 'first' | 'next'; revision: number; reviewed: CalendarPreview; start?: string; cutoff?: number | null; payment?: number; month?: string; timezone?: string };
export type CreateRunRequest = { actor: string; tenant: string; employer: string; creation: RunCreation; attempt: string; calendarAttempt: string; runAttempt: string };

export async function previewFirstRun(tenant: string, employer: string, fields: FirstRunFields): Promise<{ preview?: CalendarPreview; error?: string }> {
 if (![tenant, employer].every(uuid) || !/^\d{4}-\d{2}-\d{2}$/.test(fields.start) || !/^(last_day|[1-9]|[12]\d|3[01])$/.test(fields.cutoff) || !/^([1-9]|[12]\d|3[01])$/.test(fields.payment) || !['ending', 'following'].includes(fields.month)) return { error: 'راجع تاريخ البداية وموعد الصرف.' };
 const client = await createSupabaseServerClient();
 if (!client) return { error: errorText() };
 const { data: { user } } = await client.auth.getUser();
 if (!user) return { error: errorText('42501') };
 const result = await client.rpc('payroll_calendar_preview', { p_tenant: tenant, p_employer: employer, p_start: fields.start, p_cutoff: fields.cutoff === 'last_day' ? null : Number(fields.cutoff), p_payment: Number(fields.payment), p_month: fields.month, p_timezone: 'Africa/Cairo' });
 return result.error ? { error: errorText(result.error.code, result.error.message) } : { preview: result.data as CalendarPreview };
}

export async function createRun(request: CreateRunRequest): Promise<{ period?: string; error?: string; settled?: boolean }> {
 if (![request.actor, request.tenant, request.employer, request.attempt, request.calendarAttempt, request.runAttempt].every(uuid)) return { error: 'تعذر قراءة الطلب المحفوظ. لا تنشئ مسيرًا آخر قبل مراجعة هذا الطلب.' };
 const client = await createSupabaseServerClient();
 if (!client) return { error: errorText() };
 const { data: { user } } = await client.auth.getUser();
 if (!user || user.id !== request.actor) return { error: errorText('42501') };
 const result = await client.rpc('payroll_create_run', { p_tenant: request.tenant, p_employer: request.employer, p_creation: request.creation, p_attempt: request.attempt, p_calendar_attempt: request.calendarAttempt, p_run_attempt: request.runAttempt });
 if (result.error) {
  // These failures occur only after the wrapper has looked up the exact
  // receipt. They prove this attempt never committed, including on replay.
  const settled = result.error.code === 'PT409' && ['payroll_run_stale', 'payroll_stale'].includes(result.error.message)
   || result.error.code === '23514' && result.error.message === 'payroll_correction_required';
  return { error: result.error.message === 'payroll_run_stale' ? 'يوجد مسير مفتوح لهذه الفترة بالفعل. افتحه من قائمة المسيرات لمتابعته.' : result.error.message === 'payroll_correction_required' ? 'هذه الفترة مقفلة. افتح مسيرها من القائمة لمراجعته أو تسجيل الصرف.' : errorText(result.error.code, result.error.message), settled };
 }
 if (!uuid(result.data?.period_id ?? '')) return { error: 'لم تصل نتيجة واضحة. استكمل الطلب المحفوظ للتحقق من المسير نفسه.' };
 revalidatePath(`/tenant/${request.tenant}/payroll`);
 return { period: result.data.period_id };
}
