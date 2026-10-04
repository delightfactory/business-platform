'use server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { validAttempt, type MobileAttempt, type PunchResult } from '@/lib/attendance-channel';

export async function submitMobilePunch(tenantId: string, attempt: MobileAttempt): Promise<PunchResult> {
  if (!/^[0-9a-f-]{36}$/i.test(tenantId) || !validAttempt(attempt, attempt?.scope)) return { state: 'rejected', reason: 'time' };
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
  return data as PunchResult;
}

export async function reconcileMobilePunch(tenantId: string, id: string, scope: string): Promise<PunchResult> {
  if (!/^[0-9a-f-]{36}$/i.test(tenantId) || !/^[0-9a-f-]{36}$/i.test(id) || typeof scope !== 'string' || scope.length > 300) return { state: 'blocked', reason: 'scope_changed' };
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
  return data as PunchResult;
}
