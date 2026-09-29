'use server';

import { randomUUID } from 'node:crypto';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

const bucket = 'tenant-branding';
const maxLogoBytes = 2 * 1024 * 1024;

export async function saveTenantBrandingAction(formData: FormData) {
  const tenantId = text(formData, 'tenantId');
  const displayName = text(formData, 'displayName');
  const color = text(formData, 'color');
  const reason = text(formData, 'reason');
  const removeLogo = formData.get('removeLogo') === 'on';
  const fileField = formData.get('logo');
  const file = fileField instanceof File && fileField.size > 0 ? fileField : null;
  if (!isUuid(tenantId) || !['teal', 'blue', 'violet', 'emerald'].includes(color)
    || (removeLogo && file) || displayName.length > 160) go(tenantId, 'invalid');
  if (reason.length < 3 || reason.length > 500) go(tenantId, 'reason');

  const supabase = await createSupabaseServerClient();
  if (!supabase) go(tenantId, 'setup');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/auth/login?state=no-session');
  const { data: snapshot, error: snapshotError } = await supabase.rpc('tenant_branding_snapshot', { p_tenant_id: tenantId });
  if (snapshotError || !snapshot || typeof snapshot !== 'object' || Array.isArray(snapshot)) go(tenantId, 'forbidden');
  if ((snapshot as Record<string, unknown>).can_manage_branding !== true) go(tenantId, 'forbidden');

  let objectPath: string | null = null;
  if (file) {
    const mime = await verifiedImageMime(file);
    if (!mime || file.size > maxLogoBytes) go(tenantId, 'file');
    const extension = mime === 'image/jpeg' ? 'jpg' : mime === 'image/png' ? 'png' : 'webp';
    objectPath = `tenants/${tenantId}/logos/${randomUUID()}.${extension}`;
    const { error } = await supabase.storage.from(bucket).upload(objectPath, file, {
      cacheControl: '3600', contentType: mime, upsert: false,
    });
    if (error) go(tenantId, 'upload-failed');
  }

  const { error } = await supabase.rpc('save_tenant_branding', {
    p_tenant_id: tenantId,
    p_display_name: displayName || null,
    p_primary_color_key: color,
    p_logo_object_path: objectPath,
    p_remove_logo: removeLogo,
    p_reason: reason,
  });
  if (error) go(tenantId, mapError(error.message));
  redirect(`/tenant/${tenantId}/branding?state=saved`);
}

async function verifiedImageMime(file: File): Promise<string | null> {
  const bytes = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  const isPng = bytes.length >= 8 && [137, 80, 78, 71, 13, 10, 26, 10].every((value, index) => bytes[index] === value);
  const isJpeg = bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const isWebp = bytes.length >= 12 && String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF'
    && String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP';
  if (isPng && file.type === 'image/png') return 'image/png';
  if (isJpeg && file.type === 'image/jpeg') return 'image/jpeg';
  if (isWebp && file.type === 'image/webp') return 'image/webp';
  return null;
}

function text(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }
function mapError(message: string) {
  if (message.includes('tenant_branding_forbidden')) return 'forbidden';
  if (message.includes('tenant_branding_unavailable')) return 'unavailable';
  if (message.includes('tenant_branding_logo_unavailable')) return 'logo';
  if (message.includes('tenant_branding_display_name_invalid')) return 'invalid';
  if (message.includes('tenant_branding_reason_required')) return 'reason';
  if (message.includes('tenant_branding_input_invalid')) return 'invalid';
  return 'save-failed';
}
function go(tenantId: string, state: string): never {
  if (!isUuid(tenantId)) redirect('/tenant/select?state=invalid');
  redirect(`/tenant/${tenantId}/branding?state=${encodeURIComponent(state)}`);
}
