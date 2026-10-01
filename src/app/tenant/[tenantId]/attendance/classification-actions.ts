'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { readClassificationReview, uuid, type ClassificationActionState } from './classification';

export async function renewClassificationReview(tenantId: string, instanceId: string) {
  if (!uuid(tenantId) || !uuid(instanceId)) return { review: null, message: 'السجل غير متاح للمراجعة.' };
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { review: null, message: 'تعذر الاتصال. السبب محفوظ؛ أعد المحاولة.' };
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { review: null, message: 'انتهت الجلسة. سجّل الدخول لاستكمال المراجعة.' };
  const { data, error } = await supabase.rpc('attendance_review_classification', { p_tenant_id: tenantId, p_work_instance_id: instanceId });
  const review = error ? null : readClassificationReview(data);
  return { review, message: review ? '' : 'لا يمكن اعتماد هذه النتيجة حاليًا. راجع تسجيلات اليوم وصلاحية الاعتماد؛ السبب محفوظ.' };
}

export async function commitClassificationAction(
  previous: ClassificationActionState, data: FormData,
): Promise<ClassificationActionState> {
  void previous;
  const field = (name: string) => String(data.get(name) ?? '').trim();
  const tenantId = field('tenantId'), instanceId = field('instanceId');
  const reason = field('reason'), key = field('operationKey');
  let review;
  try { review = readClassificationReview(JSON.parse(field('review'))); } catch { review = null; }
  if (!uuid(tenantId) || !uuid(instanceId) || !review || !uuid(key)) {
    return { message: 'تعذر التحقق من المراجعة. أعد مراجعة نتيجة اليوم.', needsReview: true };
  }
  if (reason.length < 3 || reason.length > 500) {
    return { message: 'اكتب سببًا من 3 إلى 500 حرف. السبب الذي أدخلته محفوظ.', needsReview: false };
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { message: 'تعذر الاتصال. السبب محفوظ؛ أعد المحاولة بنفس البيانات.', needsReview: false };
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { message: 'انتهت الجلسة. سجّل الدخول ثم أعد مراجعة اليوم.', needsReview: true };
  const { data: result, error } = await supabase.rpc('attendance_commit_classification', {
    p_tenant_id: tenantId, p_work_instance_id: instanceId,
    p_expected_fact_id: review.expected_fact_id, p_expected_fact_version: review.expected_fact_version,
    p_expected_interpretation_id: review.expected_interpretation_id,
    p_expected_interpretation_version: review.expected_interpretation_version,
    p_expected_input_fingerprint: review.input_fingerprint, p_expected_context_hash: review.context_hash,
    p_reviewed_plan_hash: review.plan_hash, p_reason: reason, p_idempotency_key: key,
  });
  if (error) {
    if (error.code === 'PT409' || error.code === '23505') {
      return { message: 'تغيّرت بيانات المراجعة. السبب محفوظ؛ أعد مراجعة النتيجة قبل الاعتماد.', needsReview: true };
    }
    if (error.code === '42501') return { message: 'صلاحية الاعتماد أو تفعيل الحضور غير متاح. السبب محفوظ.', needsReview: true };
    if (error.code === '23514') return { message: 'تحتاج تسجيلات هذا اليوم إلى تصحيح قبل الاعتماد. السبب محفوظ.', needsReview: true };
    return { message: 'تعذر تأكيد الاعتماد. السبب محفوظ؛ أعد المحاولة بنفس البيانات أو تحقق من سجل الاعتماد.', needsReview: false };
  }
  if (!result || typeof result !== 'object' || typeof result.fact_id !== 'string' || !uuid(result.fact_id)) {
    return { message: 'تعذر تأكيد النتيجة. السبب محفوظ؛ تحقق من سجل الاعتماد أو أعد المحاولة بنفس البيانات.', needsReview: false };
  }
  revalidatePath(`/tenant/${tenantId}/attendance/${instanceId}`);
  revalidatePath(`/tenant/${tenantId}/attendance`);
  revalidatePath(`/tenant/${tenantId}/attendance/review`);
  redirect(`/tenant/${tenantId}/attendance/${instanceId}?state=classification-approved`);
}
