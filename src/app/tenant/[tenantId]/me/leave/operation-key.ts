export function newOperationKey(): string {
  if (typeof crypto !== 'undefined') {
    if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
    const bytes = new Uint8Array(16);
    crypto.getRandomValues(bytes);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return formatHex(Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join(''));
  }
  let hex = '';
  for (let index = 0; index < 32; index += 1) hex += Math.floor(Math.random() * 16).toString(16);
  return formatHex(hex);
}

function formatHex(hex: string): string {
  const variant = ['8', '9', 'a', 'b'][Math.floor(Math.random() * 4)];
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-${variant}${hex.slice(17, 20)}-${hex.slice(20)}`;
}
