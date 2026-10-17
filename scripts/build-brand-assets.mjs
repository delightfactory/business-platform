// Deterministic icon sizing/packaging from the retained raster master.
import fs from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp'; // Already supplied by Next.js; no additional install.
const root = path.resolve(import.meta.dirname, '..');
const out = path.join(root, 'public/brand');
import brand from '../src/lib/product-brand.json' with { type: 'json' };

async function icon(size, background, inset = .76) {
  const mark = await sharp(path.join(out, 'basher-mark.png')).resize(Math.round(size * inset)).toBuffer();
  return sharp({ create: { width: size, height: size, channels: 4, background } })
    .composite([{ input: mark, gravity: 'centre' }]).png().toBuffer();
}

async function main() {
  await fs.mkdir(out, { recursive: true });
  for (const [file, size, background, inset] of [
    ['basher-icon-light.png', 512, '#ffffff', .94],
    ['basher-icon-dark.png', 512, brand.navy, .94],
    ['basher-maskable.png', 512, '#ffffff', .7],
    ['favicon-16.png', 16, '#ffffff', 1],
    ['favicon-32.png', 32, '#ffffff', 1],
    ['favicon-48.png', 48, '#ffffff', 1],
    ['apple-touch-icon.png', 180, '#ffffff', .92],
  ]) await fs.writeFile(path.join(out, file), await icon(size, background, inset));

  const entries = await Promise.all([16, 32, 48].map(size => fs.readFile(path.join(out, `favicon-${size}.png`))));
  const header = Buffer.alloc(6 + entries.length * 16);
  header.writeUInt16LE(1, 2); header.writeUInt16LE(entries.length, 4);
  let offset = header.length;
  entries.forEach((png, index) => {
    const p = 6 + index * 16, size = [16, 32, 48][index];
    header[p] = size; header[p + 1] = size;
    header.writeUInt16LE(1, p + 4); header.writeUInt16LE(32, p + 6);
    header.writeUInt32LE(png.length, p + 8); header.writeUInt32LE(offset, p + 12);
    offset += png.length;
  });
  const ico = Buffer.concat([header, ...entries]);
  await fs.writeFile(path.join(out, 'favicon.ico'), ico);
  await fs.writeFile(path.join(root, 'src/app/favicon.ico'), ico);
  await fs.copyFile(path.join(out, 'apple-touch-icon.png'), path.join(root, 'src/app/apple-icon.png'));
  await fs.writeFile(path.join(root, 'public/pwa/icon-192.png'), await icon(192, '#ffffff', .94));
  await fs.copyFile(path.join(out, 'basher-icon-light.png'), path.join(root, 'public/pwa/icon-512.png'));
  await fs.copyFile(path.join(out, 'basher-maskable.png'), path.join(root, 'public/pwa/maskable-512.png'));
  const markData = (await fs.readFile(path.join(out, 'basher-mark.png'))).toString('base64');
  const card = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630"><rect width="1200" height="630" fill="#f4faf9"/><rect x="0" y="600" width="1200" height="30" fill="${brand.teal}"/><image href="data:image/png;base64,${markData}" x="100" y="95" width="420" height="420"/><text x="585" y="315" font-family="Arial,sans-serif" font-size="88" font-weight="700" fill="${brand.navy}">BASHER</text><text x="590" y="370" font-family="Arial,sans-serif" font-size="25" fill="${brand.navy}">Run Your Business From One Place</text></svg>`;
  await sharp(Buffer.from(card)).png().toFile(path.join(out, 'basher-social.png'));
  for (const name of ['icon-192', 'icon-512', 'maskable-512']) await fs.copyFile(path.join(root, `public/pwa/${name}.png`), path.join(root, `public/pwa/basher-${name}.png`));
  console.log('BASHER: browser, Apple, PWA, maskable, light/dark and sharing assets generated.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
