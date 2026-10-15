'use server';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import { operatorCommercialSnapshot, operatorUuid, type OperatorCommercialSnapshot, type OperatorLimit } from '@/lib/operator-read';
export type LimitResult = { outcome: 'changed' | 'unchanged' | 'stale'; snapshot: OperatorCommercialSnapshot }
  | { outcome: 'error'; message: string } | { outcome: 'unknown' };
export async function readLimitsAction(tenantId: string): Promise<LimitResult> {
  if (!operatorUuid(tenantId)) return { outcome: 'error', message: 'الشركة غير متاحة.' };
  try {
    const client = await createSupabaseServerClient();
    if (!client) return { outcome: 'error', message: 'تعذر الاتصال بالخدمة.' };
    const { data, error } = await client.rpc('platform_tenant_commercial_snapshot', { p_tenant_id: tenantId });
    return !error && operatorCommercialSnapshot(data) && data.tenant_id === tenantId
      ? { outcome: 'unchanged', snapshot: data } : { outcome: 'error', message: 'تعذر قراءة الحدود الحالية. تحقق من الاتصال والصلاحية.' };
  } catch { return { outcome: 'unknown' }; }
}
export async function setLimitAction(tenantId: string, key: OperatorLimit['capability_key'], mode: string, value: number | null, expected: string | null, note: string): Promise<LimitResult> {
  if (!operatorUuid(tenantId) || !['tenant.users', 'tenant.sites'].includes(key) || !['limited', 'unlimited'].includes(mode)
    || (mode === 'limited' && (!Number.isSafeInteger(value) || (value ?? 0) < 1)) || typeof note !== 'string' || note.trim().length > 500) return { outcome: 'error', message: 'راجع الحد والملاحظة ثم حاول من جديد.' };
  try {
    const client = await createSupabaseServerClient();
    if (!client) return { outcome: 'error', message: 'تعذر الاتصال بالخدمة.' };
    const { data, error } = await client.rpc('set_tenant_capability_limit', {
      p_tenant_id: tenantId, p_capability_key: key, p_limit_key: key === 'tenant.users' ? 'max_users' : 'max_sites',
      p_limit_mode: mode, p_limit_value: mode === 'limited' ? value : null, p_expected_valid_from: expected, p_note: note.trim() || null,
    });
    if (error) {
      if (error.code === '42501') return { outcome: 'error', message: 'لم تعد صلاحية تعديل حدود الاستخدام متاحة لهذا الحساب.' };
      if (error.message.includes('conflict')) return { outcome: 'error', message: 'تحتاج إعدادات الحد إلى مراجعة فنية قبل التعديل.' };
      if (error.code === '22023') return { outcome: 'error', message: 'أدخل عددًا صحيحًا موجبًا، أو اختر غير محدود.' };
      return { outcome: 'unknown' };
    }
    if (!data || !operatorCommercialSnapshot(data.snapshot) || data.snapshot.tenant_id !== tenantId
      || !['changed', 'unchanged', 'stale'].includes(data.outcome)) return { outcome: 'unknown' };
    revalidatePath(`/operator/companies/${tenantId}/limits`);
    return { outcome: data.outcome, snapshot: data.snapshot };
  } catch { return { outcome: 'unknown' }; }
}
