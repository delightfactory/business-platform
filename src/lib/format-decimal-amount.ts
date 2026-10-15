import { ARABIC_DISPLAY_LOCALE } from './display-locale';

/** Presentation of stored decimal money; never convert the decimal to a float. */
export function formatDecimalAmount(value: string | number): string {
  const text = String(value), match = /^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(text);
  if (!match) return text;
  const whole = new Intl.NumberFormat(ARABIC_DISPLAY_LOCALE).format(BigInt(match[2]));
  return `${match[1]}${whole}.${(match[3] ?? '').padEnd(2, '0')}`;
}
