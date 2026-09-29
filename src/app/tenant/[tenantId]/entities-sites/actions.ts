'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type NewEntityState = { displayName: string; legalName: string; reason: string; error: string; attempt: number };
export type NewSiteState = { displayName: string; reason: string; error: string; attempt: number };

export type RecordActionState = { displayName: string; legalName: string; reason: string; error: string; attempt: number };

export async function legalEntityFormAction(previous: RecordActionState, formData: FormData): Promise<RecordActionState> {
  const tenantId = field(formData, 'tenantId');
  const entityId = field(formData, 'entityId');
  const action = field(formData, 'action');
  const displayName = field(formData, 'displayName');
  const legalName = field(formData, 'legalName');
  const reason = field(formData, 'reason');
  const failure = (code: string): RecordActionState => ({ displayName, legalName, reason, error: entityErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !isUuid(entityId) || !['update', 'default', 'deactivate', 'reactivate'].includes(action)) return failure('invalid');
  if (action === 'update' && (!displayName || displayName.length > 160 || legalName.length > 200)) return failure('name');
  if (reason.length < 3 || reason.length > 500) return failure('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failure('setup');
  const { data, error } = await supabase.rpc('manage_tenant_legal_entity', {
    p_tenant_id: tenantId, p_action: action, p_entity_id: entityId,
    p_display_name: displayName || null, p_legal_name: legalName || null, p_reason: reason,
  });
  if (error) return failure(mapError(error.message));
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  if (!result || typeof result.state !== 'string') return failure('failed');
  redirect(`/tenant/${tenantId}/entities-sites/${entityId}?state=entity-${encodeURIComponent(result.state)}`);
}

export async function siteFormAction(previous: RecordActionState, formData: FormData): Promise<RecordActionState> {
  const tenantId = field(formData, 'tenantId');
  const entityId = field(formData, 'returnEntityId');
  const siteId = field(formData, 'siteId');
  const action = field(formData, 'action');
  const displayName = field(formData, 'displayName');
  const reason = field(formData, 'reason');
  const failure = (code: string): RecordActionState => ({ displayName, legalName: '', reason, error: entityErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !isUuid(entityId) || !isUuid(siteId) || !['update', 'default', 'deactivate', 'reactivate'].includes(action)) return failure('invalid');
  if (action === 'update' && (!displayName || displayName.length > 160)) return failure('name');
  if (reason.length < 3 || reason.length > 500) return failure('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failure('setup');
  const { data, error } = await supabase.rpc('manage_tenant_site', {
    p_tenant_id: tenantId, p_action: action, p_site_id: siteId,
    p_legal_entity_id: null, p_display_name: displayName || null, p_reason: reason,
  });
  if (error) return failure(mapError(error.message));
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  if (!result || typeof result.state !== 'string') return failure('failed');
  redirect(`/tenant/${tenantId}/entities-sites/${entityId}?state=site-${encodeURIComponent(result.state)}`);
}

export async function createLegalEntityFormAction(previous: NewEntityState, formData: FormData): Promise<NewEntityState> {
  const tenantId = field(formData, 'tenantId');
  const displayName = field(formData, 'displayName');
  const legalName = field(formData, 'legalName');
  const reason = field(formData, 'reason');
  const failure = (code: string): NewEntityState => ({ displayName, legalName, reason, error: entityErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !displayName || displayName.length > 160 || legalName.length > 200) return failure('name');
  if (reason.length < 3 || reason.length > 500) return failure('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failure('setup');
  const { data, error } = await supabase.rpc('manage_tenant_legal_entity', {
    p_tenant_id: tenantId, p_action: 'create', p_entity_id: null,
    p_display_name: displayName, p_legal_name: legalName || null, p_reason: reason,
  });
  if (error) return failure(mapError(error.message));
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  const resultEntityId = typeof result?.entity_id === 'string' && isUuid(result.entity_id) ? result.entity_id : '';
  if (!resultEntityId) return failure('failed');
  redirect(`/tenant/${tenantId}/entities-sites/${resultEntityId}?state=entity-${encodeURIComponent(String(result?.state ?? 'created'))}`);
}

export async function createSiteFormAction(previous: NewSiteState, formData: FormData): Promise<NewSiteState> {
  const tenantId = field(formData, 'tenantId');
  const entityId = field(formData, 'legalEntityId');
  const displayName = field(formData, 'displayName');
  const reason = field(formData, 'reason');
  const failure = (code: string): NewSiteState => ({ displayName, reason, error: entityErrorText(code), attempt: previous.attempt + 1 });
  if (!isUuid(tenantId) || !isUuid(entityId) || !displayName || displayName.length > 160) return failure('name');
  if (reason.length < 3 || reason.length > 500) return failure('reason');
  const supabase = await createSupabaseServerClient();
  if (!supabase) return failure('setup');
  const { error } = await supabase.rpc('manage_tenant_site', {
    p_tenant_id: tenantId, p_action: 'create', p_site_id: null,
    p_legal_entity_id: entityId, p_display_name: displayName, p_reason: reason,
  });
  if (error) return failure(mapError(error.message));
  redirect(`/tenant/${tenantId}/entities-sites/${entityId}?state=site-created`);
}

export async function manageLegalEntityAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const action = field(formData, 'action');
  const entityId = field(formData, 'entityId');
  const returnEntityId = field(formData, 'returnEntityId');
  const displayName = field(formData, 'displayName');
  const legalName = field(formData, 'legalName');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isEntityAction(action) || (action !== 'create' && !isUuid(entityId))
    || (returnEntityId && !isUuid(returnEntityId))) go(tenantId, 'invalid');
  if (reason.length < 3 || reason.length > 500) go(tenantId, 'reason', returnEntityId || entityId);
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup', returnEntityId || entityId);
  const { data, error } = await supabase.rpc('manage_tenant_legal_entity', {
    p_tenant_id: tenantId,
    p_action: action,
    p_entity_id: entityId || null,
    p_display_name: displayName || null,
    p_legal_name: legalName || null,
    p_reason: reason,
  });
  if (error) go(tenantId, mapError(error.message), returnEntityId || entityId);
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  const state = typeof result?.state === 'string' ? result.state : 'failed';
  const resultEntityId = typeof result?.entity_id === 'string' && isUuid(result.entity_id) ? result.entity_id : '';
  go(tenantId, `entity-${state}`, returnEntityId || entityId || resultEntityId);
}

export async function manageSiteAction(formData: FormData) {
  const tenantId = field(formData, 'tenantId');
  const action = field(formData, 'action');
  const siteId = field(formData, 'siteId');
  const legalEntityId = field(formData, 'legalEntityId');
  const returnEntityId = field(formData, 'returnEntityId');
  const displayName = field(formData, 'displayName');
  const reason = field(formData, 'reason');
  if (!isUuid(tenantId) || !isSiteAction(action)
    || (action !== 'create' && !isUuid(siteId))
    || (action === 'create' && !isUuid(legalEntityId))
    || (returnEntityId && !isUuid(returnEntityId))) go(tenantId, 'invalid');
  if (reason.length < 3 || reason.length > 500) go(tenantId, 'reason', returnEntityId || legalEntityId);
  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup', returnEntityId || legalEntityId);
  const { data, error } = await supabase.rpc('manage_tenant_site', {
    p_tenant_id: tenantId,
    p_action: action,
    p_site_id: siteId || null,
    p_legal_entity_id: legalEntityId || null,
    p_display_name: displayName || null,
    p_reason: reason,
  });
  if (error) go(tenantId, mapError(error.message), returnEntityId || legalEntityId);
  const state = data && typeof data === 'object' && !Array.isArray(data) ? (data as Record<string, unknown>).state : null;
  go(tenantId, typeof state === 'string' ? `site-${state}` : 'failed', returnEntityId || legalEntityId);
}

function field(data: FormData, name: string) { return String(data.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function isEntityAction(value: string): value is 'create'|'update'|'default'|'deactivate'|'reactivate' {
  return ['create','update','default','deactivate','reactivate'].includes(value);
}
function isSiteAction(value: string): value is 'create'|'update'|'default'|'deactivate'|'reactivate' {
  return ['create','update','default','deactivate','reactivate'].includes(value);
}
function mapError(message: string) {
  if (message.includes('_manage_forbidden')) return 'forbidden';
  if (message.includes('capacity_reached')) return 'capacity';
  if (message.includes('limit_unavailable')) return 'limit';
  if (message.includes('has_active_sites')) return 'entity-has-sites';
  if (message.includes('entity_inactive') || message.includes('site_inactive')) return 'inactive';
  if (message.includes('entity_unavailable')) return 'entity-unavailable';
  if (message.includes('not_found')) return 'not-found';
  if (message.includes('reason_required')) return 'reason';
  if (message.includes('name_invalid')) return 'name';
  if (message.includes('move_not_supported')) return 'move';
  if (message.includes('unavailable')) return 'unavailable';
  return 'failed';
}
function entityErrorText(code: string) {
  const messages: Record<string, string> = {
    name: 'راجع الاسم المدخل ثم أعد المحاولة.',
    reason: 'اكتب سببًا واضحًا من 3 أحرف على الأقل.',
    setup: 'الخدمة غير متاحة الآن. أعد المحاولة لاحقًا.',
    forbidden: 'ليس لديك صلاحية لإجراء هذا التغيير.',
    capacity: 'اكتمل حد الفروع النشطة. عطّل فرعًا غير مستخدم أو اطلب رفع الحد.',
    limit: 'تعذر التحقق من حد الفروع. أعد المحاولة لاحقًا.',
    inactive: 'الجهة غير نشطة حاليًا. فعّلها قبل إضافة فرع.',
    'entity-unavailable': 'هذه الجهة لم تعد متاحة. عد إلى قائمة الجهات.',
    unavailable: 'العملية غير متاحة الآن. حدّث الصفحة وأعد المحاولة.',
  };
  return messages[code] ?? 'تعذر حفظ التغيير. راجع البيانات وأعد المحاولة.';
}
function go(tenantId: string, state: string, entityId?: string): never {
  if (!isUuid(tenantId)) redirect('/auth/login?state=invalid');
  if (entityId && isUuid(entityId)) redirect(`/tenant/${tenantId}/entities-sites/${entityId}?state=${encodeURIComponent(state)}`);
  redirect(`/tenant/${tenantId}/entities-sites?state=${encodeURIComponent(state)}`);
}
