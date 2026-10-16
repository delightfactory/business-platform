import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
const ts=createRequire(import.meta.url)('typescript');
const exports={};
runInNewContext(ts.transpileModule(readFileSync(new URL('./attendance-retention.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports});
const {retentionSeconds,displayRetention}=exports;
test('retention uses exact units and retains allowed endpoints',()=>{
  assert.equal(retentionSeconds('1','minutes'),60);
  assert.equal(retentionSeconds('30','days'),2592000);
  assert.equal(retentionSeconds('90','minutes'),5400);
  assert.equal(retentionSeconds('1','days'),86400);
  for(const seconds of [60,61,300,3601,5400,86400,2592000]) {
    const shown=displayRetention(seconds);
    assert.equal(retentionSeconds(shown.amount,shown.unit),seconds,'existing seconds roundtrip without rounding');
  }
  assert.equal(displayRetention(86400).unit,'days');
  assert.equal(displayRetention(5400).unit,'minutes');
  assert.equal(displayRetention(3601).unit,'seconds');
  assert.equal(displayRetention().amount,'','new policy amount remains blank');
});
test('invalid or fractional policy values never become a duration',()=>{
  for(const [amount,unit] of [['','days'],['0','minutes'],['59','seconds'],['31','days'],['1.5','days'],['Infinity','seconds'],['1e3','seconds'],['1','unknown'],['-1','days'],['999999999999999999999','seconds']]) {
    assert.equal(retentionSeconds(amount,unit),null,`${amount}/${unit}`);
  }
});
