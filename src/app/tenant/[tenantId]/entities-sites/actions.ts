'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

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
function go(tenantId: string, state: string, entityId?: string): never {
  if (!isUuid(tenantId)) redirect('/auth/login?state=invalid');
  if (entityId && isUuid(entityId)) redirect(`/tenant/${tenantId}/entities-sites/${entityId}?state=${encodeURIComponent(state)}`);
  redirect(`/tenant/${tenantId}/entities-sites?state=${encodeURIComponent(state)}`);
}
