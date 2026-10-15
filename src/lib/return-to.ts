/** Internal return context only; the destination still authorizes every read. */
export function safeReturn(tenantId: string, raw: unknown): string | null {
  if (typeof raw !== 'string' || raw.length > 8192 || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId)) return null;
  if (/[\x00-\x20\x7f\\]/.test(raw) || /%(?:0[0-9a-f]|1[0-9a-f]|20|2f|5c|7f)/i.test(raw)) return null;
  const base = `/tenant/${tenantId}`;
  if (raw !== base && !raw.startsWith(`${base}/`) && !raw.startsWith(`${base}?`) && !raw.startsWith(`${base}#`)) return null;
  try {
    const url = new URL(raw, 'https://workspace.invalid');
    return url.origin === 'https://workspace.invalid' && (url.pathname === base || url.pathname.startsWith(`${base}/`)) ? raw : null;
  } catch { return null; }
}
