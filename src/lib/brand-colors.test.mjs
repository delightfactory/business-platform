import test from 'node:test';
import assert from 'node:assert/strict';
import { brandPresets, normalizeHexColor, normalizeBrandColor, customBrandStyle, contrastRatio } from './brand-colors.mjs';

test('accepts pasted 3/6 digit codes with optional hash, case and whitespace', () => {
  assert.equal(normalizeHexColor(' #AbC '), '#aabbcc');
  assert.equal(normalizeHexColor('FFCC00'), '#ffcc00');
  assert.equal(normalizeBrandColor('blue'), 'blue');
});
test('rejects CSS, alpha, malformed and non-string input', () => {
  for (const value of [null, {}, '', '#abcd', '#12345678', 'red', '#000;display:none', 'var(--brand)', 'url(x)']) {
    assert.equal(normalizeHexColor(value), null);
    assert.equal(customBrandStyle(value), undefined);
  }
});
test('presets preserve their original theme tokens', () => {
  for (const preset of brandPresets) assert.equal(customBrandStyle(preset.key), undefined);
});
test('custom color remains exact; button and light/dark text remain legible across the RGB cube', () => {
  for (let r = 0; r <= 255; r += 51) for (let g = 0; g <= 255; g += 51) for (let b = 0; b <= 255; b += 51) {
    const color = '#' + [r, g, b].map(c => c.toString(16).padStart(2, '0')).join('');
    const style = customBrandStyle(color);
    assert.equal(style['--brand'], color);
    assert.ok(contrastRatio(color, style['--brand-ink']) >= 4.5, color);
    assert.ok(contrastRatio(style['--brand-strong'], style['--brand-ink']) >= 4.5, color + ' hover');
    assert.ok(contrastRatio(style['--custom-brand-text-light'], '#ffffff') >= 4.5, color + ' light');
    assert.ok(contrastRatio(style['--custom-brand-text-dark'], '#14211d') >= 4.5, color + ' dark');
  }
});
