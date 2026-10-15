export function invitationCreationError(error: { code?: string; message?: string }): 'invalid' | 'forbidden' | 'conflict' | 'unknown' {
  if (error.code === '42501') return 'forbidden';
  if (['onboarding_required_fields_invalid', 'onboarding_invalid_limit', 'tenant_admin_invite_invalid_request'].includes(error.message ?? '')) return 'invalid';
  if (['onboarding_idempotency_conflict', 'tenant_admin_invite_idempotency_conflict'].includes(error.message ?? '')) return 'conflict';
  return 'unknown';
}
