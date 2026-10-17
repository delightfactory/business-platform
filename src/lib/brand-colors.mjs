export const brandPresets = Object.freeze([
  { key: 'teal', label: 'فيروزي', hex: '#0e6b5c' },
  { key: 'blue', label: 'أزرق', hex: '#2456c7' },
  { key: 'violet', label: 'بنفسجي', hex: '#6a3fc2' },
  { key: 'emerald', label: 'أخضر', hex: '#0f7a47' },
]);

export function normalizeHexColor(value) {
  if (typeof value !== 'string') return null;
  const hex = value.trim().replace(/^#/, '').toLowerCase();
  if (/^[0-9a-f]{3}$/.test(hex)) return '#' + [...hex].map(c => c + c).join('');
  return /^[0-9a-f]{6}$/.test(hex) ? '#' + hex : null;
}

export function normalizeBrandColor(value) {
  return brandPresets.some(preset => preset.key === value) ? value : normalizeHexColor(value);
}

export function resolveBrandColor(value) {
  return brandPresets.find(preset => preset.key === value)?.hex || normalizeHexColor(value) || brandPresets[0].hex;
}

function rgb(hex) { return [1, 3, 5].map(index => parseInt(hex.slice(index, index + 2), 16)); }
function luminance(hex) {
  const channels = rgb(hex).map(value => { const c = value / 255; return c <= .04045 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4; });
  return channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722;
}
export function contrastRatio(first, second) {
  const a = luminance(first), b = luminance(second);
  return (Math.max(a, b) + .05) / (Math.min(a, b) + .05);
}
function blend(color, target, amount) {
  const end = rgb(target);
  return '#' + rgb(color).map((start, i) => Math.round(start + (end[i] - start) * amount).toString(16).padStart(2, '0')).join('');
}
function readableText(color, background, target) {
  for (let step = 0; step <= 20; step++) {
    const candidate = blend(color, target, step / 20);
    if (contrastRatio(candidate, background) >= 4.5) return candidate;
  }
  return target;
}

// Only validated hexadecimal values enter CSS. Named palettes retain their existing theme behavior.
export function customBrandStyle(value) {
  const color = normalizeHexColor(value);
  if (!color) return undefined;
  const ink = contrastRatio(color, '#ffffff') >= contrastRatio(color, '#000000') ? '#ffffff' : '#000000';
  const darkText = readableText(color, '#14211d', '#ffffff');
  return {
    '--brand': color, '--brand-ink': ink,
    '--brand-strong': blend(color, ink === '#ffffff' ? '#000000' : '#ffffff', .15),
    '--brand-soft': 'color-mix(in srgb, var(--brand) 12%, var(--surface))',
    '--brand-light': color, '--brand-dark': color, '--brand-dark-ink': ink,
    '--custom-brand-text-light': readableText(color, '#ffffff', '#000000'),
    '--custom-brand-text-dark': darkText,
    '--pass-accent': darkText,
    '--pass-accent-ink': contrastRatio(darkText, '#000000') > contrastRatio(darkText, '#ffffff') ? '#000000' : '#ffffff',
    '--color-focus': 'var(--brand-text)',
  };
}
