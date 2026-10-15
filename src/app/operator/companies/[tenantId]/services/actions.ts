'use server';

import { createSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { operatorUuid } from '@/lib/operator-read';
import { serviceOrder, servicePlan, serviceSnapshot, type ExpectedServices, type ServiceChange, type ServiceKey, type ServiceResult } from '@/lib/operator-services';

export async function readServicesAction(tenantId: string): Promise<ServiceResult> {
  if (!operatorUuid(tenantId)) return { outcome: 'error', message: 'الشركة غير متاحة.' };
  try {
    const client = await createSupabaseServerClient();
    if (!client) return { outcome: 'error', message: 'تعذر الاتصال بالخدمة. أعد المحاولة لاحقًا.' };
    const result = await client.rpc('platform_tenant_entitlement_snapshot', { p_tenant_id: tenantId });
    if (result.error || !serviceSnapshot(result.data) || result.data.tenant_id !== tenantId) {
      return { outcome: 'error', message: 'تعذر قراءة الحالة الحالية. تحقق من الاتصال وصلاحية الحساب ثم أعد القراءة.' };
    }
    return { outcome: 'unchanged', snapshot: result.data };
  } catch { return { outcome: 'unknown' }; }
}

export async function setServicesAction(tenantId: string, changes: ServiceChange[], expected: ExpectedServices, note?: string): Promise<ServiceResult> {
  if (!operatorUuid(tenantId) || !Array.isArray(changes) || changes.length < 1 || changes.length > 5
    || !expected || typeof expected !== 'object' || (note !== undefined && typeof note !== 'string')) {
    return { outcome: 'error', message: 'بيانات التغيير غير مكتملة. أعد قراءة الشركة.' };
  }
  try {
    const client = await createSupabaseServerClient();
    if (!client) return { outcome: 'error', message: 'تعذر الاتصال بالخدمة. أعد المحاولة لاحقًا.' };
    const result = await client.rpc('set_tenant_capability_entitlements', {
      p_tenant_id: tenantId, p_changes: changes, p_expected: expected, p_note: note?.trim() || null,
    });
    if (result.error) {
      const message = result.error.message;
      if (result.error.code === '42501') return { outcome: 'error', message: 'لم تعد صلاحية تعديل الخدمات متاحة لهذا الحساب.' };
      if (message.includes('future_conflict') || message.includes('entitlement_conflict')) return { outcome: 'error', message: 'تحتاج إعدادات هذه الخدمة إلى مراجعة فنية. أعد قراءة الحالة قبل المتابعة.' };
      if (message.includes('expiry_invalid')) return { outcome: 'error', message: 'اختر آخر يوم سريان من اليوم أو بعده بتوقيت القاهرة.' };
      if (message.includes('input_invalid') || message.includes('note_invalid')) return { outcome: 'error', message: 'راجع المدة والملاحظة، ثم حاول من جديد.' };
      if (message.includes('tenant_unavailable')) return { outcome: 'error', message: 'الشركة غير متاحة.' };
      return { outcome: 'unknown' };
    }
    const data = result.data;
    if (!data || !serviceSnapshot(data.snapshot) || data.snapshot.tenant_id !== tenantId) return { outcome: 'unknown' };
    if (data.outcome === 'changed' || data.outcome === 'unchanged' || data.outcome === 'stale') {
      revalidatePath(`/operator/companies/${tenantId}/services`);
      return { outcome: data.outcome, snapshot: data.snapshot };
    }
    if (data.outcome === 'plan_required' && servicePlan(data.plan)) return { outcome: 'plan_required', snapshot: data.snapshot, plan: data.plan };
    if (data.outcome === 'duration_required' && serviceOrder.includes(data.capability_key as ServiceKey)) return { outcome: 'duration_required', snapshot: data.snapshot, capability_key: data.capability_key };
    return { outcome: 'unknown' };
  } catch { return { outcome: 'unknown' }; }
}
