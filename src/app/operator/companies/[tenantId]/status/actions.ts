'use server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { operatorLifecycleSnapshot, operatorUuid, type OperatorLifecycleSnapshot } from '@/lib/operator-read';
export type LifecycleResult = { outcome: 'changed' | 'read' | 'stale'; snapshot: OperatorLifecycleSnapshot }
  | { outcome: 'error'; message: string } | { outcome: 'unknown' };
export async function readLifecycleAction(tenantId: string): Promise<LifecycleResult> {
  if (!operatorUuid(tenantId)) return { outcome: 'error', message: 'الشركة غير متاحة.' };
  try {
    const client = await createSupabaseServerClient();
    if (!client) return { outcome: 'error', message: 'تعذر الاتصال بالخدمة.' };
    const { data, error } = await client.rpc('platform_tenant_lifecycle_get', { p_tenant_id: tenantId });
    return !error && operatorLifecycleSnapshot(data) && data.tenant_id === tenantId
      ? { outcome: 'read', snapshot: data } : { outcome: 'error', message: 'تعذر قراءة حالة الشركة. تحقق من الاتصال والصلاحية.' };
  } catch { return { outcome: 'unknown' }; }
}
export async function setLifecycleAction(tenantId: string, expected: string, target: string, reason: string): Promise<LifecycleResult> {
  if (!operatorUuid(tenantId) || !['active', 'suspended', 'archived'].includes(expected) || !['active', 'suspended', 'archived'].includes(target)
    || typeof reason !== 'string' || reason.trim().length < 3 || reason.trim().length > 500) return { outcome: 'error', message: 'أدخل سببًا واضحًا من 3 إلى 500 حرف.' };
  try {
    const client = await createSupabaseServerClient();
    if (!client) return { outcome: 'error', message: 'تعذر الاتصال بالخدمة.' };
    const { data, error } = await client.rpc('change_tenant_lifecycle', { p_tenant_id: tenantId, p_expected_state: expected, p_target_state: target, p_reason: reason.trim() });
    if (error) {
      if (error.message.includes('state_changed')) { const fresh = await readLifecycleAction(tenantId); return 'snapshot' in fresh ? { outcome: 'stale', snapshot: fresh.snapshot } : fresh; }
      if (error.code === '42501') return { outcome: 'error', message: 'لم تعد صلاحية إدارة حالة الشركة متاحة لهذا الحساب.' };
      if (error.message.includes('transition_invalid')) return { outcome: 'error', message: 'هذا الإجراء غير متاح من حالة الشركة الحالية. أعد قراءة الحالة.' };
      if (error.code === '22023') return { outcome: 'error', message: 'راجع سبب الإجراء ثم حاول من جديد.' };
      return { outcome: 'unknown' };
    }
    if (!data || data.tenant_id !== tenantId || data.from_state !== expected || data.to_state !== target) return { outcome: 'unknown' };
    const fresh = await readLifecycleAction(tenantId);
    for (const section of ['services', 'limits', 'status']) revalidatePath(`/operator/companies/${tenantId}/${section}`);
    revalidatePath('/operator/companies');
    return 'snapshot' in fresh ? { outcome: 'changed', snapshot: fresh.snapshot } : { outcome: 'unknown' };
  } catch { return { outcome: 'unknown' }; }
}
