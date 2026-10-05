import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {createContext,runInContext} from 'node:vm';
const require=createRequire(import.meta.url),ts=require('typescript');
function moduleFrom(url,dependencies={}){
 const context=createContext({exports:{},URL,Request,Response,Buffer,require:name=>{assert.ok(name in dependencies,`Unexpected internal dependency ${name}`);return dependencies[name];}});
 const code=ts.transpileModule(readFileSync(url,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 runInContext(code,context);return context.exports;
}
const rules=moduleFrom(new URL('../rules.ts',import.meta.url));
const common=moduleFrom(new URL('../../rules.ts',import.meta.url));
const tenant='c4081000-0000-4000-8000-000000000001',employer='c4083000-0000-4000-8000-000000000001',output='c4089500-0000-4000-8000-000000000001';
const rows=Array.from({length:51},(_,i)=>({id:`c4085000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,employee:{name:`employee${i+1}`,code:String(i+1)},net:'10.00',paid:'2.00',remaining:'8.00',insured_wage:'2700.00',statutory_deductions:'300.00',statutory_context:{calendar_year:2030,category:'SYNTHETIC_NONLEGAL',obligation_months:['2030-01','2030-02'],insured_wage_source:'ROLLBACK_FIXTURE_ONLY'}}));
const site='c4084000-0000-4000-8000-000000000001',department='c4084100-0000-4000-8000-000000000001';
function harness(mode,report='payments'){
 const calls=[];
 const workspace=(items,next)=>({report:'payments',output_id:output,superseded:false,replacement_output_id:null,employer:{name:'QA',legal_name:'QA NONLEGAL'},period:{starts_on:'2026-01-25',ends_on:'2026-02-24'},previous_period:null,rows:items,next,total_count:51,summary:{net:'510.00',paid:'102.00',remaining:'408.00'},issues:[],can_export:true,source_revision:'modeled-source-boundary'});
 const client={auth:{getUser:async()=>({data:{user:{id:'c4080000-0000-4000-8000-000000000001'}}})},rpc:async(name,args)=>{
  assert.equal(name,'payroll_report_workspace');calls.push(args);
  if(args.p_limit===1)return {data:workspace([rows[0]],null)};
  if(!args.p_after)return {data:workspace(rows.slice(0,50),rows[49].id)};
  if(mode==='denied')return {data:null,error:{code:'42501'}};
  if(mode==='changed')return {data:null,error:{code:'PT409'}};
  if(mode==='duplicate')return {data:workspace([rows[0]],null)};
  return {data:workspace([rows[50]],null)};
 }};
 const action=moduleFrom(new URL('./route.ts',import.meta.url),{'@/lib/supabase/server':{createSupabaseServerClient:async()=>client},'../../rules':common,'../rules':rules});
 const request=new Request(`http://127.0.0.1:3335/tenant/${tenant}/payroll/reports/export?employer=${employer}&output=${output}&report=${report}&site=${site}&department=${department}&after=${rows[49].id}`);
 return {calls,run:()=>action.GET(request,{params:Promise.resolve({tenantId:tenant})})};
}
// These exercise the real GET and internal CSV helper with modeled Auth/RPC
// boundaries. SQL snapshot, permission and browser qualification are separate.
test('whole export ignores an existing display cursor and exhausts 51 rows before releasing CSV',async()=>{
 const h=harness('success'),response=await h.run(),body=await response.text();
 assert.equal(response.status,200);assert.equal(body.split('\r\n').length,52);assert.ok(body.includes('"employee1"'));assert.ok(body.includes('"employee51"'));
 assert.equal(h.calls.length,3);assert.ok(h.calls.every(call=>call.p_site===site&&call.p_department===department));assert.equal(h.calls[0].p_after,null);assert.equal(h.calls[1].p_after,rows[49].id);assert.equal(h.calls[2].p_limit,1);
 assert.equal(h.calls[1].p_expected_revision,'modeled-source-boundary');assert.equal(response.headers.get('Cache-Control'),'private, no-store');
});
test('authority denial on a later page returns an error without a partial CSV or retry',async()=>{
 const h=harness('denied'),response=await h.run(),body=await response.text();
 assert.equal(response.status,403);assert.match(response.headers.get('Content-Type'),/json/);assert.ok(!body.includes('employee1'));assert.equal(h.calls.length,2);
});
test('changed source stops collection at the first conflicted page',async()=>{
 const h=harness('changed'),response=await h.run();assert.equal(response.status,409);assert.equal(h.calls.length,2);
});
test('repeated row identity stops collection without a cursor retry loop',async()=>{
 const h=harness('duplicate'),response=await h.run();assert.equal(response.status,409);assert.equal(h.calls.length,2);assert.match(response.headers.get('Content-Type'),/json/);
});


test('statutory CSV preserves saved basis and obligation months without deriving separate contributions',async()=>{
 const h=harness('success','statutory'),response=await h.run(),body=await response.text();
 assert.equal(response.status,200);assert.ok(body.includes('"2700.00"'));assert.ok(body.includes('"300.00"'));assert.ok(body.includes('"2030"'));assert.ok(body.includes('"2030-01، 2030-02"'));assert.ok(body.includes('"ROLLBACK_FIXTURE_ONLY"'));
 assert.ok(h.calls.every(call=>call.p_report==='statutory'));assert.equal(h.calls.length,3);
});
