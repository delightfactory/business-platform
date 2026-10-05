'use server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { type CalendarState, type CalendarPreview, errorText, uuid } from './rules';
export async function calendarAction(previous: CalendarState, form: FormData): Promise<CalendarState> {
 const field = (key: string) => String(form.get(key) ?? '').trim();
 const tenant = field('tenant'); const employer = field('employer'); const operation = field('operation');
 const state: CalendarState = { start: field('start'), cutoff: field('cutoff'), payment: field('payment'), month: field('month'), timezone: field('timezone'), reason: field('reason'), error: '', preview: previous.preview, attemptKey: previous.attemptKey, saved: false };
 const fail = (code?: string, message?: string) => ({ ...state, error: errorText(code, message) });
 if (operation === 'cancel') return { ...state, preview: null, attemptKey: '', error: '' };
 if (!uuid(tenant) || !uuid(employer) || !/^\d{4}-\d{2}-\d{2}$/.test(state.start) || !/^(last_day|[1-9]|[12]\d|3[01])$/.test(state.cutoff) || !/^([1-9]|[12]\d|3[01])$/.test(state.payment) || !['ending','following'].includes(state.month) || state.timezone.length > 100 || state.reason.length < 3 || state.reason.length > 500) return fail('22023');
 const client = await createSupabaseServerClient(); if (!client) return fail();
 const { data: { user } } = await client.auth.getUser(); if (!user) return { ...fail('42501'), preview: null, attemptKey: '' };
 const args = { p_tenant: tenant, p_employer: employer, p_start: state.start, p_cutoff: state.cutoff === 'last_day' ? null : Number(state.cutoff), p_payment: Number(state.payment), p_month: state.month, p_timezone: state.timezone };
 if (operation === 'preview') {
  const { data, error } = await client.rpc('payroll_calendar_preview', args);
  if (error) return { ...fail(error.code, error.message), preview: null };
  return { ...state, preview: data as CalendarPreview, attemptKey: crypto.randomUUID() };
 }
 if (operation !== 'save' || !previous.preview || !uuid(previous.attemptKey)) return fail('22023');
 const { error } = await client.rpc('payroll_save_calendar', { ...args, p_expected: previous.preview.revision, p_attempt: previous.attemptKey, p_reviewed: previous.preview, p_reason: state.reason });
 if (error) {
  const definitive = ['PT409','42501','55000'].includes(error.code);
  return { ...fail(error.code, error.message), ...(definitive ? { preview: null, attemptKey: '' } : {}) };
 }
 revalidatePath(`/tenant/${tenant}/payroll`);
 revalidatePath(`/tenant/${tenant}/payroll/setup`);
 return { ...state, error: '', preview: null, attemptKey: '', saved: true };
}
export type GenerateState = { error: string; saved: boolean; attemptKey: string };
export async function generateAction(previous: GenerateState, form: FormData): Promise<GenerateState> {
 const tenant = String(form.get('tenant') ?? ''); const employer = String(form.get('employer') ?? '');
 const state = { ...previous, saved: false, error: '' };
 if (!uuid(tenant) || !uuid(employer) || !uuid(previous.attemptKey)) return { ...state, error: errorText('22023') };
 const client = await createSupabaseServerClient(); if (!client) return { ...state, error: errorText() };
 const { data: { user } } = await client.auth.getUser(); if (!user) return { ...state, error: errorText('42501') };
 let reviewed: CalendarPreview;
 try { reviewed = JSON.parse(String(form.get('reviewed') ?? '')); } catch { return { ...state, error: errorText('22023') }; }
 const { error } = await client.rpc('payroll_generate_next_period', { p_tenant: tenant, p_employer: employer, p_expected: Number(form.get('revision')), p_attempt: previous.attemptKey, p_reviewed: reviewed });
 if (error) return { ...state, error: errorText(error.code, error.message) };
 revalidatePath(`/tenant/${tenant}/payroll`); revalidatePath(`/tenant/${tenant}/payroll/setup`); return { error: '', saved: true, attemptKey: crypto.randomUUID() };
}
