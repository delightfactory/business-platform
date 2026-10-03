import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import ts from 'typescript';
import React from 'react';
// Execute the actual server page. Auth/RPC and child rendering are transport
// boundaries; this is deliberately not an authenticated browser claim.
const require=createRequire(import.meta.url);
const id=n=>`c4350000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const tenant=id(1),request=id(2),employer=id(3),employee=id(4),output=id(5);
function harness({denied=false,stale=false}={}){
 const calls=[];
 const context={request_id:request,employer_id:employer,employment_id:employee,outputs:[output,id(6)].map(id=>({id,period_id:id,starts_on:'2025-01-01',ends_on:'2025-01-31',ever_paid:true,source_ids:[id===output?'source-a':'source-c','source-b']}))};
 const client={auth:{getUser:async()=>({data:{user:{id:'QA-actor'}}})},rpc:async(name,args)=>{
  calls.push({name,args});
  if(name==='payroll_leave_correction_context')return denied?{error:{code:'42501'}}:{data:context};
  if(name==='payroll_correction_workspace')return {data:{case:null,superseded:false,employer:{display_name:'QA'},period:{id:id(7),starts_on:'2025-01-01',ends_on:'2025-01-31'},ever_paid:true,sources:[],employees:[],sites:[],references:{},period_choices:[],output_choices:[],component_choices:[],replacement_outputs:[],history:[],settlements:[],access:{can_prepare:true}}};
  if(name==='payroll_correction_choices')return {data:{selected:{id:args.p_selected,name:'Actual source',expected_hash:'a'.repeat(64),fresh:!stale,affects_paid_output:true}}};
  throw new Error('Unexpected RPC '+name);
 }};
 const cache=new Map();
 function load(filename){
  filename=path.resolve(filename);if(cache.has(filename))return cache.get(filename).exports;
  const loaded={exports:{}};cache.set(filename,loaded);
  const compiled=ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}});
  const localRequire=name=>{
   if(name==='@/lib/supabase/server')return {createSupabaseServerClient:async()=>client};
   if(name==='next/navigation')return {notFound:()=>{throw Error('NOT_FOUND');},redirect:href=>{throw Object.assign(Error('REDIRECT'),{href});}};
   if(name==='next/link')return {__esModule:true,default:'Link'};
   if(name.endsWith('.module.css'))return {default:{card:'card'}};
   if(name==='../rules')return {uuid:value=>/^[a-f0-9-]{36}$/.test(value),displayDate:value=>value};
   if(name==='./rules')return {correctionKinds:{source_change:'Source'},correctionStatuses:{}};
   if(name==='../runs/rules')return {money:value=>value,issueNames:{}};
   if(name==='@/lib/payroll/leave-correction-context')return load('src/lib/payroll/leave-correction-context.ts');
   if(['./CorrectionForms','./SourcePicker','@/components/context-navigation'].includes(name))return new Proxy({}, {get:(_,key)=>String(key)});
   return require(name);
  };
  vm.runInThisContext(`(function(require,module,exports){${compiled.outputText}\n})`,{filename})(localRequire,loaded,loaded.exports);
  return loaded.exports;
 }
 const page=load('src/app/tenant/[tenantId]/payroll/corrections/page.tsx').default;
 return {context,calls,render:q=>page({params:Promise.resolve({tenantId:tenant}),searchParams:Promise.resolve(q)})};
}
function all(tree,predicate){
 if(!tree||typeof tree!=='object')return [];
 return [...(predicate(tree)?[tree]:[]),...React.Children.toArray(tree.props?.children).flatMap(child=>all(child,predicate))];
}
test('request navigation retains every affected output without general rediscovery',async()=>{
 const h=harness(),tree=await h.render({request});const links=all(tree,e=>e.type==='Link');
 assert.equal(links.length,2);assert.ok(links.every(link=>link.props.href.includes(`request=${request}`)&&link.props.href.includes(`employer=${employer}`)&&link.props.href.includes(`employee=${employee}`)));
 assert.deepEqual(h.calls.map(x=>x.name),['payroll_leave_correction_context']);
});
test('actual correction form receives both authoritative sources, with no guessed financial responsibility',async()=>{
 const h=harness(),tree=await h.render({request,output});const form=all(tree,e=>e.type==='ProposalForm')[0];
 assert.equal(form.props.employer,employer);assert.equal(form.props.employee,employee);assert.equal(form.props.kind,'source_change');
 assert.deepEqual(form.props.initialObservationProposal.observations.map(x=>x.id),['source-a','source-b']);
 assert.deepEqual(form.props.initialObservationProposal.rows,[]);assert.equal(form.props.initialObservationProposal.reason,'');
});
for(const bad of [{output:id(99)},{output,employer:id(99)},{output,employee:id(99)}])test('forged context stops before workspace/source reads '+JSON.stringify(bad),async()=>{
 const h=harness();const tree=await h.render({request,...bad});assert.equal(all(tree,e=>e.type==='ProposalForm').length,0);
 assert.deepEqual(h.calls.map(x=>x.name),['payroll_leave_correction_context']);
});
test('lost payroll authority yields no form or workspace disclosure',async()=>{
 const h=harness({denied:true});const tree=await h.render({request,output});assert.equal(all(tree,e=>e.type==='ProposalForm').length,0);assert.equal(h.calls.length,1);
});
test('source changed during navigation stops proposal initialization',async()=>{
 const h=harness({stale:true});const tree=await h.render({request,output});assert.equal(all(tree,e=>e.type==='ProposalForm').length,0);
});
