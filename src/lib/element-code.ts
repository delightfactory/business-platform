import { randomInt } from 'node:crypto';

const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

// A suggestion, not a reservation: the existing database uniqueness rules decide at save time.
export function generateElementCode(prefix: 'E' | 'DEP' | 'JOB' | 'PAY' | 'dwm' | 'typ' | 'cal') {
  const suffix = Array.from({ length: 12 }, () => alphabet[randomInt(alphabet.length)]).join('');
  return prefix === 'PAY' ? `pay_${suffix.toLowerCase()}` : `${prefix}-${suffix}`;
}
