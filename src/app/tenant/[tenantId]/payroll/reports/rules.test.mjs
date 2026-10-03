import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {createContext,runInContext} from 'node:vm';
const require=createRequire(import.meta.url);
const ts=require('typescript');
const code=ts.transpileModule(readFileSync(new URL('./rules.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const context=createContext({exports:{}});runInContext(code,context);
const {reportMoney,csvCell,csvDocument}=context.exports;
test('large numeric(18,2) values preserve their exact cents without a Number conversion',()=>{
 assert.equal(reportMoney('9999999999999999.99'),'9٬999٬999٬999٬999٬999٫99 ج.م.');
 assert.equal(reportMoney('-1234.50'),'-1٬234٫50 ج.م.');
 assert.equal(reportMoney(null),'غير متاح');
 assert.equal(reportMoney('NaN'),'غير مكتمل');
});
test('export neutralizes formulas preceded by whitespace and Unicode BOM',()=>{
 for(const attack of ['=1+2','  =1+2','\uFEFF@SUM(A1)','\t+1','\n-2','\r=3'])assert.equal(csvCell(attack),`"'${attack}"`);
 assert.equal(csvCell('محمود "أحمد"'),'"محمود ""أحمد"""');
});
test('Arabic CSV keeps text, quoted embedded newlines, BOM and CRLF records',()=>{
 assert.equal(csvDocument([['الموظف','الصافي'],['أحمد\nمحمد','100.25']]),'\uFEFF"الموظف","الصافي"\r\n"أحمد\nمحمد","100.25"');
});
