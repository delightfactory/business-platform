import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
const ts=createRequire(import.meta.url)('typescript'),exports={};
runInNewContext(ts.transpileModule(readFileSync(new URL('./payroll-configuration-date.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports});
const {configurationDateFloor:floor,nextConfigurationDate:next}=exports;
test('configuration versions require an exact later civil date',()=>{
 assert.equal(next('2028-02-28'),'2028-02-29');
 assert.equal(next('2026-12-31'),'2027-01-01');
 assert.equal(floor('2026-10-01',null,''),'2026-10-02');
 assert.equal(floor(undefined,null,''),undefined,'new policy has no invented date');
});
test('open-ended guidance preserves supported finite historical ranges',()=>{
 assert.equal(floor('2026-10-01','2026-12-01',''),'2026-12-01');
 assert.equal(floor('2026-12-31','2026-12-01',''),'2027-01-01');
 assert.equal(floor('2026-10-01','2026-12-01','2026-10-15'),'2026-10-02');
 assert.equal(floor(undefined,'2026-12-01','2026-10-15'),undefined);
});
