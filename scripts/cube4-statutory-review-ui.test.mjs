import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {createRequire} from 'node:module';
import test from 'node:test';
import ts from 'typescript';
// The actual action/rules execute; Auth/RPC/cache are transport boundaries.
const require=createRequire(import.meta.url),base=path.resolve('src/app/tenant/[tenantId]/payroll/inputs');
const id=n=>`c4360000-0000-4000-8000-${String(n).padStart(12,'0')}`;
function harness({signedIn=true,error=null}={}){
 const calls=[],cache=new Map();const client={auth:{getUser:async()=>({data:{user:signedIn?{id:id(9)}:null}})},rpc:async(name,args)=>{calls.push({name,args});return error?{error}:{data:{id:id(7),revision:1,status:'draft'}};}};
 function load(filename){
  if(cache.has(filename))return cache.get(filename).exports;
  const loaded={exports:{}};cache.set(filename,loaded);
  const compiled=ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}});
  const localRequire=name=>{
   if(name==='@/lib/supabase/server')return {createSupabaseServerClient:async()=>client};
   if(name==='next/cache')return {revalidatePath:()=>{}};
   if(name==='../rules')return {uuid:v=>/^[a-f0-9-]{36}$/.test(v)};
   if(name.startsWith('./'))return load(path.resolve(path.dirname(filename),name+'.ts'));
   return require(name);
  };
  vm.runInThisContext(`(function(require,module,exports){${compiled.outputText}\n})`,{filename})(localRequire,loaded,loaded.exports);return loaded.exports;
 }
 return {calls,action:load(path.join(base,'actions.ts')).inputAction};
}
const state=()=>({error:'',saved:false,head:'',revision:0,attempt:'',signature:'',status:'draft'});
function form(extra={}){
 const result=new FormData();for(const [key,value] of Object.entries({tenant:id(1),employer:id(2),kind:'statutory_context',operation:'save',employment:id(3),from:'2025-01-05',tax_treatment_code:'01',insurance_status:'not_insured',reference:'NONLEGAL reviewed source',reason:'Explicit reviewed period facts',...extra}))result.set(key,String(value));return result;
}
test('ordinary context retains no empty calculation facts or invented duration',async()=>{
 const h=harness();const result=await h.action(state(),form());assert.equal(result.saved,true);
 assert.ok(!('calculation_from' in h.calls[0].args.p_data));assert.ok(!('tax_duration_days' in h.calls[0].args.p_data));
 assert.ok(!('insurance_month_disposition' in h.calls[0].args.p_data));
});
test('explicit dated facts travel with existing immutable input intent',async()=>{
 const h=harness();await h.action(state(),form({calculation_from:'2025-01-05',calculation_until:'2025-01-05',tax_duration_days:'1'}));const data=h.calls[0].args.p_data;
 assert.equal(data.calculation_from,'2025-01-05');assert.equal(data.calculation_until,'2025-01-05');assert.equal(data.tax_duration_days,'1');assert.ok(!('financially_qualified' in data));assert.equal(h.calls[0].name,'payroll_save_input');
});
test('partial facts are retained for server rejection rather than silently completing them',async()=>{
 const h=harness({error:{code:'22023',message:'payroll_statutory_duration_invalid'}});const result=await h.action(state(),form({tax_duration_days:'1'}));assert.equal(result.saved,false);assert.ok(result.error);assert.ok(!('calculation_from' in h.calls[0].args.p_data));
});
test('unchanged failed intent retains the same operation UUID on retry',async()=>{
 const h=harness({error:{code:'22023',message:'payroll_statutory_duration_invalid'}});const fields=form({tax_duration_days:'1'});const failed=await h.action(state(),fields);await h.action(failed,fields);assert.equal(h.calls[0].args.p_attempt,h.calls[1].args.p_attempt);
});
test('no authenticated actor cannot send reviewed source facts',async()=>{
 const h=harness({signedIn:false});const result=await h.action(state(),form({tax_duration_days:'1'}));assert.equal(result.saved,false);assert.equal(h.calls.length,0);
});
test('reviewed partial-month disposition retains its source binding and request identity after rejection',async()=>{
 const h=harness({error:{code:'22023',message:'payroll_insurance_disposition_invalid'}});
 const fields=form({insurance_status:'insured',insurance_category:'NONLEGAL category',insured_wage:'10000',insurance_from:'2026-07-15',insurance_obligation_month:'2026-07-01',insurance_owner_period:id(4),insurance_obligation_reference:'NONLEGAL reviewed joining-month source',insurance_month_disposition:'reviewed_not_due'});
 const failed=await h.action(state(),fields);assert.equal(failed.saved,false);assert.ok(failed.error.includes('استحقاق'));
 await h.action(failed,fields);assert.equal(h.calls[0].args.p_attempt,h.calls[1].args.p_attempt);
 assert.equal(h.calls[1].args.p_data.insurance_month_disposition,'reviewed_not_due');assert.equal(h.calls[1].args.p_data.insurance_owner_period,id(4));assert.equal(h.calls[1].args.p_data.insurance_obligation_reference,'NONLEGAL reviewed joining-month source');
 assert.ok(!('financially_qualified' in h.calls[1].args.p_data));
});

test('reviewed deduction case and assignment consent survive the unchanged rejected intent',async()=>{
 const h=harness({error:{code:'22023',message:'payroll_deduction_source_invalid'}});
 const fields=form({kind:'adjustment',period:id(4),component_id:id(5),amount:'1000',deduction_category:'assignment',consent_reference:'NONLEGAL written assignment consent'});
 const failed=await h.action(state(),fields);await h.action(failed,fields);
 assert.equal(failed.saved,false);assert.equal(h.calls[0].args.p_attempt,h.calls[1].args.p_attempt);
 assert.equal(h.calls[1].args.p_data.deduction_category,'assignment');assert.equal(h.calls[1].args.p_data.consent_reference,'NONLEGAL written assignment consent');
 assert.ok(!('financially_qualified' in h.calls[1].args.p_data));
});
test('blank deduction fields do not alter ordinary approved earning source contracts',async()=>{
 const h=harness();await h.action(state(),form({kind:'adjustment',period:id(4),component_id:id(5),amount:'1000',deduction_category:'',consent_reference:''}));
 assert.ok(!('deduction_category' in h.calls[0].args.p_data));assert.ok(!('consent_reference' in h.calls[0].args.p_data));
});
