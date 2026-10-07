/* eslint-disable @typescript-eslint/no-require-imports -- Standalone CommonJS audit CLI; no application bundler. */
/* Source-level audit only; does not execute application code or read environment files. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = process.cwd();
const dir = path.join(root, 'docs/04-product-specs/ux-redesign');
const inventory = JSON.parse(fs.readFileSync(path.join(dir, 'inventory.json'), 'utf8'));
const register = JSON.parse(fs.readFileSync(path.join(dir, 'review-register.json'), 'utf8'));
const items = ['routes','boundaries','serverActions','rpcCalls','formControls','requestBoundaries'].flatMap(key => inventory[key]);
const unique = new Set(items.map(item => item.id));
if (unique.size !== items.length) throw Error('Duplicate inventory IDs');
for (const file of [...inventory.files, ...inventory.requestBoundaries]) {
  const digest = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file.file),'utf8').replace(/\r\n/g,'\n')).digest('hex');
  if (digest !== file.sha256) throw Error(`Source drift: ${file.file}`);
}
const reviews = new Map(register.items.map(item => [item.id,item]));
if (reviews.size !== register.items.length || reviews.size !== unique.size) throw Error('Review denominator mismatch');
for (const item of items) {
  const review = reviews.get(item.id);
  if (!review || review.phase !== item.phase) throw Error(`Missing or wrongly assigned review: ${item.id}`);
  if (review.status === 'reviewed' && (!review.scenarioIds.length || !review.reviewer || !review.evidence)) throw Error(`Unsupported reviewed claim: ${item.id}`);
  if (review.status === 'not-applicable' && (!review.reason || !review.reviewer)) throw Error(`Unsupported exclusion: ${item.id}`);
}
const phaseIndex = process.argv.indexOf('--phase');
const phase = phaseIndex < 0 ? null : process.argv[phaseIndex + 1];
if (phaseIndex >= 0 && !/^R[1-8]$/.test(phase ?? '')) throw Error('Use --phase R1 through R8');
const relevant = new Set(items.filter(item => !phase || item.phase === phase || item.reviewPhases?.includes(phase)).map(item => item.id));
const open = register.items.filter(item => relevant.has(item.id) && !['reviewed','not-applicable'].includes(item.status));
const summary = {sourceFingerprintsMatch:true,denominatorItems:items.length,phase:phase??'all',phaseItems:relevant.size,sourceReviewedItems:register.items.filter(item=>relevant.has(item.id)&&item.status==='source-reviewed').length,pendingSemanticReview:open.length,executionCoverageComplete:false};
console.log(JSON.stringify(summary));
if (process.argv.includes('--require-reviewed') && open.length) throw Error(`Freeze blocked: ${open.length} source items still require semantic review`);
