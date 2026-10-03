import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {createContext,runInContext} from 'node:vm';
const require=createRequire(import.meta.url),ts=require('typescript');
function load(url,dependencies={}){
 const context=createContext({exports:{},require:name=>{assert.ok(name in dependencies);return dependencies[name];}});
 runInContext(ts.transpileModule(readFileSync(url,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText,context);return context.exports;
}
const common=load(new URL('../rules.ts',import.meta.url));
const scope={tenant:'c4481000-0000-4000-8000-000000000001',employer:'c4483000-0000-4000-8000-000000000001',output:'c4489500-0000-4000-8000-000000000001',employee:'c4485000-0000-4000-8000-000000000001',revision:'a'.repeat(32),site:null,department:null,query:''};
function harness(mode){
 const calls=[];
 const client={auth:{getUser:async()=>({data:{user:{id:'modeled-actor'}}})},rpc:async(name,args)=>{
  calls.push({name,args});
  if(mode==='denied'||mode==='changed')return {error:{code:mode==='denied'?'42501':'PT409'}};
  return {data:{source_revision:scope.revision,superseded:mode==='superseded',issues:[],total_count:1,rows:[{id:scope.employee}]}};
 }};
 const action=load(new URL('./print-actions.ts',import.meta.url),{'@/lib/supabase/server':{createSupabaseServerClient:async()=>client},'../rules':common});
 return {calls,run:()=>action.authorizePayslipPrint(scope)};
}
// Actual server action and UUID helper, modeled Auth/RPC only. No physical print proof.
test('print authorization requests current export authority for exactly one saved Employee and source',async()=>{
 const h=harness('saved'),result=await h.run();assert.equal(result.allowed,true);assert.equal(h.calls.length,1);const call=h.calls[0];assert.equal(call.name,'payroll_report_workspace');assert.equal(call.args.p_export,true);assert.equal(call.args.p_report,'payslip');assert.equal(call.args.p_expected_revision,scope.revision);assert.equal(call.args.p_employee,scope.employee);assert.equal(call.args.p_limit,1);
});
test('revoked export authority prevents print without a retry',async()=>{const h=harness('denied');assert.equal((await h.run()).allowed,false);assert.equal(h.calls.length,1);});
test('changed source prevents printing the old page',async()=>{const h=harness('changed');assert.equal((await h.run()).allowed,false);assert.equal(h.calls.length,1);});
test('superseded result cannot be authorized for print even without an RPC error',async()=>{const h=harness('superseded');assert.equal((await h.run()).allowed,false);assert.equal(h.calls.length,1);});
