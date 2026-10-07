'use server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { validAttempt, type MobileAttempt, type PunchResult } from '@/lib/attendance-channel';

export async function submitMobilePunch(tenantId: string, attempt: MobileAttempt): Promise<PunchResult> {
  if (!/^[0-9a-f-]{36}$/i.test(tenantId) || !validAttempt(attempt, attempt?.scope)) return { state: 'unconfirmed', reason: 'invalid_input' };
  const db = await createSupabaseServerClient();
  if (!db) throw new Error('attendance_unreachable');
  const { data: { user } } = await db.auth.getUser();
  if (!user) return { state: 'blocked', reason: 'permission' };
  const { data, error } = await db.rpc('attendance_mobile_punch', { p_tenant: tenantId, p_attempt: attempt });
  if (error) {
    if (error.code === '42501') return { state: 'blocked', reason: 'permission' };
    throw new Error('attendance_unreachable');
  }
  revalidatePath(`/tenant/${tenantId}/me/attendance`);
  revalidatePath(`/tenant/${tenantId}/attendance`);
  return readPunchResult(data);
}

export async function reconcileMobilePunch(tenantId: string, id: string, scope: string): Promise<PunchResult> {
  if (!/^[0-9a-f-]{36}$/i.test(tenantId) || !/^[0-9a-f-]{36}$/i.test(id) || typeof scope !== 'string' || scope.length > 300) return { state: 'unconfirmed', reason: 'invalid_input' };
  const db = await createSupabaseServerClient();
  if (!db) throw new Error('attendance_unreachable');
  const { data: { user } } = await db.auth.getUser();
  if (!user) return { state: 'blocked', reason: 'permission' };
  const { data, error } = await db.rpc('attendance_mobile_attempt', { p_tenant: tenantId, p_attempt_id: id, p_scope: scope });
  if (error) {
    if (error.code === '42501') return { state: 'blocked', reason: 'permission' };
    throw new Error('attendance_unreachable');
  }
  revalidatePath(`/tenant/${tenantId}/me/attendance`);
  return readPunchResult(data);
}

function readPunchResult(value: unknown): PunchResult {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('attendance_unconfirmed');
  const result = value as Record<string, unknown>;
  const states = ['accepted', 'duplicate', 'rejected', 'blocked', 'received', 'unmapped', 'retry_failed', 'retrying'];
  if (typeof result.state !== 'string' || !states.includes(result.state)
    || (result.reason !== undefined && result.reason !== null && typeof result.reason !== 'string')
    || (result.review !== undefined && typeof result.review !== 'boolean')
    || (result.next_direction !== undefined && result.next_direction !== 'in' && result.next_direction !== 'out')
    || (['accepted', 'duplicate'].includes(result.state) && typeof result.review !== 'boolean')
    || (['rejected', 'blocked'].includes(result.state) && (typeof result.reason !== 'string' || !result.reason))) {
    throw new Error('attendance_unconfirmed');
  }
  return {
    state: result.state,
    ...(result.reason !== undefined ? { reason: result.reason as string | null } : {}),
    ...(result.review !== undefined ? { review: result.review as boolean } : {}),
    ...(result.next_direction !== undefined ? { next_direction: result.next_direction as 'in' | 'out' } : {}),
  };
}
