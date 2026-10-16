import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {runInNewContext} from 'node:vm';
import {test} from 'node:test';
const ts=createRequire(import.meta.url)('typescript'),exports={};
runInNewContext(ts.transpileModule(readFileSync(new URL('./attendance-calendar.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports,require:()=>({ARABIC_DISPLAY_LOCALE:'ar-EG-u-nu-latn'}),Intl,Date});
const {calendarWeeks:weeks,adjacentDay,adjacentMonth,isCivilDate,isAttendanceMonth,readMonthCalendar:read}=exports;
test('civil dates/months reject rollover and month controls respect their range',()=>{
 assert.equal(isCivilDate('2026-02-29'),false);assert.equal(isCivilDate('2028-02-29'),true);
 assert.equal(isAttendanceMonth('2026-13'),false);assert.equal(isAttendanceMonth('1999-12'),false);
 assert.equal(adjacentMonth('2000-01',-1),null);assert.equal(adjacentMonth('2100-12',1),null);
 assert.equal(adjacentMonth('2026-12',1),'2027-01');assert.equal(adjacentDay('2028-03-01',-1),'2028-02-29');
});
test('calendar has Saturday-first civil offsets and every date exactly once',()=>{
 const october=weeks('2026-10');assert.equal(october[0][5],'2026-10-01');
 assert.equal(october.flat().filter(Boolean).length,31);assert.equal(new Set(october.flat().filter(Boolean)).size,31);
 assert.equal(weeks('2028-02').flat().filter(Boolean).length,29);assert.equal(weeks('2026-02').flat().filter(Boolean).length,28);
 assert.equal(weeks('2026-13').length,0);
});
test('calendar read cannot turn malformed or partial-scope data into zero counts',()=>{
 const row={date:'2026-10-14',open:0,ready:6,needs_review:2,approved:3};
 assert.equal(read({month:'2026-10',days:[row]},'2026-10').days[0].approved,3);
 assert.equal(read({month:'2026-10',days:[]},'2026-10').days.length,0);
 for(const value of [null,{month:'2026-09',days:[]},{month:'2026-10',days:[row,row]},
 {month:'2026-10',days:[{...row,ready:-1}]},{month:'2026-10',days:[{...row,date:'2026-10-32'}]},
 {month:'2026-10',days:[{...row,date:'2026-09-14'}]},{month:'2026-10',days:[{...row,approved:'3'}]},
 {month:'2026-10',days:[{...row,ready:undefined}]}]) assert.equal(read(value,'2026-10'),null);
});
