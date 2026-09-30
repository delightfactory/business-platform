'use server';

import { redirect } from 'next/navigation';
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
function move(tenantId: string, instanceId: string, state: string): never {
  redirect(`/tenant/${tenantId}/attendance/${instanceId}?state=${encodeURIComponent(state)}`);
}
