'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function recordPunchAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const instanceId = field(formData, 'instanceId');
  const direction = field(formData, 'direction');
  const localTime = field(formData, 'localTime');
  const requestKey = field(formData, 'requestKey');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isUuid(instanceId) || !isUuid(requestKey) || !['in', 'out'].includes(direction) || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(localTime)) move(tenantId, instanceId, 'input');
  const supabase = await createSupabaseServerClient();
  if (!supabase) move(tenantId, instanceId, 'setup');
  const { error } = await supabase.rpc('record_manual_attendance_punch_local', {
    p_tenant_id: tenantId, p_instance_id: instanceId, p_direction: direction,
    p_local_time: localTime, p_request_key: requestKey, p_reason: reason || null,
  });
  move(tenantId, instanceId, error ? mapError(error.message) : 'punch-recorded');
}

export async function correctPunchAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const instanceId = field(formData, 'instanceId');
  const punchId = field(formData, 'punchId');
  const action = field(formData, 'action');
  const direction = field(formData, 'direction');
  const localTime = field(formData, 'localTime');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isUuid(instanceId) || !isUuid(punchId) || !['replace', 'exclude'].includes(action)
    || (action === 'replace' && (!['in', 'out'].includes(direction) || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(localTime))) || reason.trim().length < 3) move(tenantId, instanceId, 'input');
  const supabase = await createSupabaseServerClient();
  if (!supabase) move(tenantId, instanceId, 'setup');
  const { error } = await supabase.rpc('correct_manual_attendance_punch_local', {
    p_tenant_id: tenantId, p_instance_id: instanceId, p_punch_id: punchId, p_action: action,
    p_direction: direction || null, p_local_time: localTime || null, p_reason: reason,
  });
  move(tenantId, instanceId, error ? mapError(error.message) : 'punch-corrected');
}

export async function approveAttendanceAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const instanceId = field(formData, 'instanceId');
  const correctsFactId = field(formData, 'correctsFactId');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isUuid(instanceId) || (correctsFactId && !isUuid(correctsFactId)) || (correctsFactId && reason.trim().length < 3)) move(tenantId, instanceId, 'input');
  const supabase = await createSupabaseServerClient();
  if (!supabase) move(tenantId, instanceId, 'setup');
  const { error } = await supabase.rpc('approve_attendance_fact', {
    p_tenant_id: tenantId, p_instance_id: instanceId, p_corrects_fact_id: correctsFactId || null, p_reason: reason || null,
  });
  move(tenantId, instanceId, error ? mapError(error.message) : 'fact-approved');
}

export async function approveAttendanceAbsenceAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const instanceId = field(formData, 'instanceId');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isUuid(instanceId) || reason.length < 3) move(tenantId, instanceId, 'input');
  const supabase = await createSupabaseServerClient();
  if (!supabase) move(tenantId, instanceId, 'setup');
  const { error } = await supabase.rpc('approve_attendance_absence', {
    p_tenant_id: tenantId, p_instance_id: instanceId, p_reason: reason,
  });
  move(tenantId, instanceId, error ? mapError(error.message) : 'absence-approved');
}

export async function reviewAttendanceOvertimeAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const instanceId = field(formData, 'instanceId');
  const candidateId = field(formData, 'candidateId');
  const decision = field(formData, 'decision');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isUuid(instanceId) || !isUuid(candidateId) || !['approved', 'rejected'].includes(decision) || reason.length < 3 || reason.length > 500) {
    move(tenantId, instanceId, 'overtime-input');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) move(tenantId, instanceId, 'setup');
  const { error } = await supabase.rpc('review_attendance_overtime', {
    p_tenant_id: tenantId, p_candidate_id: candidateId, p_decision: decision, p_reason: reason,
  });
  move(tenantId, instanceId, error ? mapOvertimeError(error.message) : decision === 'approved' ? 'overtime-approved' : 'overtime-rejected');
}

export type BulkApprovalState = {
  message: string;
  items: Array<{ instance_id: string; state: 'approved' | 'skipped'; reason_code?: string }>;
};

export async function bulkApproveReadyAttendanceAction(previousState: BulkApprovalState, formData: FormData): Promise<BulkApprovalState> {
  void previousState;
  const tenantId = field(formData, 'tenantId');
  const date = field(formData, 'operationalDate');
  const ids = formData.getAll('instanceIds').map((value) => String(value).trim());
  if (!isUuid(tenantId) || !/^\d{4}-\d{2}-\d{2}$/.test(date) || ids.length < 1 || ids.length > 50 || ids.some((id) => !isUuid(id)) || new Set(ids).size !== ids.length) {
    return { message: 'اختر سجلات جاهزة صالحة، بحد أقصى 50 سجلًا.', items: [] };
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return { message: 'تعذر الاتصال بخدمة الحضور. لم تتغير السجلات.', items: [] };
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { message: 'انتهت الجلسة. سجّل الدخول ثم أعد المحاولة.', items: [] };
  const { data, error } = await supabase.rpc('approve_attendance_facts_bulk', {
    p_tenant_id: tenantId, p_operational_date: date, p_instance_ids: ids,
  });
  if (error || !data || typeof data !== 'object') {
    const message = error?.message.includes('forbidden') ? 'لا تملك صلاحية الاعتماد الجماعي.'
      : error?.message.includes('input_invalid') ? 'تعذر اعتماد الاختيار. حدّث الصفحة ثم أعد المحاولة.'
        : 'تعذر تنفيذ الاعتماد. لم تكتمل المعاملة.';
    return { message, items: [] };
  }
  const result = data as { approved_count?: number; skipped_count?: number; items?: Array<{ instance_id?: string; state?: string; reason_code?: string }> };
  const items: BulkApprovalState['items'] = Array.isArray(result.items) ? result.items.flatMap((item) => {
    if (typeof item.instance_id !== 'string' || (item.state !== 'approved' && item.state !== 'skipped')) return [];
    return [{ instance_id: item.instance_id, state: item.state as 'approved' | 'skipped', reason_code: item.reason_code }];
  }) : [];
  revalidatePath(`/tenant/${tenantId}/attendance`);
  revalidatePath(`/tenant/${tenantId}/attendance/review`);
  return {
    message: `اكتمل الإجراء: اعتُمد ${Number(result.approved_count ?? 0)}، وتعذّر اعتماد ${Number(result.skipped_count ?? 0)} بعد إعادة التحقق.`,
    items,
  };
}

function field(data: FormData, name: string) { return String(data.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function mapError(message: string) {
  if (message.includes('forbidden')) return 'forbidden';
  if (message.includes('attendance_punch_input_invalid')) return 'input';
  if (message.includes('ambiguous_or_invalid')) return 'time';
  if (message.includes('attendance_punch_in_future')) return 'time-future';
  if (message.includes('not_ready')) return 'not-ready';
  if (message.includes('absence_not_eligible')) return 'stale';
  if (message.includes('stale')) return 'stale';
  if (message.includes('idempotency_conflict')) return 'conflict';
  return 'failed';
}
function mapOvertimeError(message: string) {
  if (message.includes('review_forbidden')) return 'overtime-forbidden';
  if (message.includes('candidate_stale')) return 'overtime-stale';
  if (message.includes('already_reviewed')) return 'overtime-reviewed';
  if (message.includes('review_input_invalid')) return 'overtime-input';
  return 'failed';
}
function move(tenantId: string, instanceId: string, state: string): never {
  redirect(`/tenant/${tenantId}/attendance/${instanceId}?state=${encodeURIComponent(state)}`);
}
