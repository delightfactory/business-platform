import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
const ts=createRequire(import.meta.url)('typescript'),exports={};
runInNewContext(ts.transpileModule(readFileSync(new URL('./rules.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports});
const {readEmployerPage}=exports;
const base={items:[],has_more:false,next_after_name:null,next_after_id:null};
const id='e3940000-0000-4000-8000-000000000005';
test('entry hint accepts legacy payload and explicit null without inferring from rows',()=>{
 assert.equal(readEmployerPage(base).uniqueEmployer,null);
 assert.equal(readEmployerPage({...base,unique_employer:null}).uniqueEmployer,null);
 assert.equal(readEmployerPage({...base,items:[{id,display_name:'Only visible row',is_active:true}]}).uniqueEmployer,null);
});
test('entry hint is independently validated and does not change paging validation',()=>{
 assert.equal(readEmployerPage({...base,unique_employer:id}).uniqueEmployer,id);
 for(const hint of ['',false,{},[],123,'not-a-uuid'])assert.equal(readEmployerPage({...base,unique_employer:hint}),null);
 assert.equal(readEmployerPage({...base,unique_employer:id,has_more:true}),null);
});
