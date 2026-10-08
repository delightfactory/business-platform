export function operatorPermission(result: { data: unknown; error: unknown }): boolean {
  return result.error === null && result.data === true;
}

export function sameCompanyScope(snapshotId: unknown, tenantId: string): boolean {
  return typeof snapshotId === 'string' && snapshotId.toLowerCase() === tenantId.toLowerCase();
}
