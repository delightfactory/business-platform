import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import ts from 'typescript';
import React from 'react';

// Execute the actual server page, form and server action with synthetic RPCs.
// These component/transport checks do not claim browser or database acceptance.
const root = path.resolve('src/app/tenant/[tenantId]/payroll/corrections');
const require = createRequire(import.meta.url);
const id = n => `c4300000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const actor=id(1),tenant=id(2),employer=id(3),output=id(4),source=id(5);
const hash='a'.repeat(64),currentHash='b'.repeat(64);
const defaults={amount:'100',valid_from:'2026-01-01',valid_until:null};
const cases=[
 ['compensation',{amount:'275.25',valid_from:'2026-02-01',valid_until:null}],
 ['compensation_split',{amount:'310.15',effective_from:'2026-02-10'}],
 ['assignment',{site_id:id(8),department_id:null,job_id:null,manager_employee_id:null,valid_from:'2026-02-01',valid_until:null,work_policy_template_id:null,work_policy_version:null}],
 ['assignment_split',{site_id:id(8),department_id:null,job_id:null,manager_employee_id:null,work_policy_template_id:null,work_policy_version:null,effective_from:'2026-02-10'}],
 ['employment',{start_date:'2026-02-01',end_date:null,pay_basis:'daily',payroll_eligible:false}],
 ['new_employment',{employee_code:'NEW',full_name:'Synthetic Employee',start_date:'2026-02-01',end_date:null,pay_basis:'monthly',payroll_eligible:true,amount:'520.30',site_id:id(8)}],
 ['new_employment',{employee_id:id(9),start_date:'2026-02-01',end_date:null,pay_basis:'daily',payroll_eligible:true,amount:'82.15',site_id:id(8)}],
 ['input_revision',{effective_from:'2026-02-01',effective_until:null,cancelled:false,data:{name:'Saved component',classification:'earning',calculation:'fixed',value:'38.27',base:'base_pay',behavior:'period_input',taxable:true,social:false,visible:true,active:true,proration:'paid_full_period',order:'4',key:'saved',reason:'Saved component reason'}}],
];
function harness(change) {
 const calls=[],state=[],storage=new Map();let index=0;
 const browserStorage={getItem:key=>storage.get(key)??null,setItem:(key,value)=>storage.set(key,value),removeItem:key=>storage.delete(key)};
 const browserWindow={location:{pathname:'/tenant/'+tenant+'/payroll/corrections',search:''},dispatchEvent(){},addEventListener(){},removeEventListener(){}};
 const kind=change.type.replace(/_split$/,'');
 const rows=[{employment_id:id(10),output_id:id(11),basis:'period_component',amount:'-12.35',component_id:id(12),target_period:id(13),source:'Reviewed synthetic source',reference:'Saved row reference'}];
 const savedCase={id:id(6),proposal_id:id(7),revision:3,status:'draft',reason:'Saved reason',reference:'Saved reference',target_period:id(13),changes:[change],responsibilities:rows,affected_outputs:[],affected_count:0};
 const workspace={case:savedCase,employer:{display_name:'Synthetic Employer'},period:{id:id(14),starts_on:'2026-02-01',ends_on:'2026-02-28'},sources:[],employees:[],sites:[],references:{},period_choices:[],output_choices:[],component_choices:[],replacement_outputs:[],history:[],settlements:[],access:{can_prepare:true},ever_paid:true};
 const rpc=async (name,args)=>{
  calls.push({name,args});
  if(name==='payroll_correction_workspace')return {data:workspace};
  if(name==='payroll_correction_choices')return {data:{selected:{id:source,expected_hash:currentHash,kind:'component',fields:kind==='compensation'?defaults:change.fields}}};
  return {data:{preview_hash:'preview',case_id:savedCase.id}};
 };
 const client={auth:{getUser:async()=>({data:{user:{id:actor}}})},rpc};
 const stubs={
  react:{...React,
   useState:initial=>{const slot=index++;if(!(slot in state))state[slot]=typeof initial==='function'?initial():initial;return [state[slot],value=>{state[slot]=typeof value==='function'?value(state[slot]):value;}];},
   useRef:initial=>{const slot=index++;if(!(slot in state))state[slot]={current:initial};return state[slot];},
   useEffect:callback=>callback(),useEffectEvent:callback=>callback,useSyncExternalStore:(_subscribe,snapshot)=>snapshot(),
   useActionState:(callback,initial)=>{const slot=index++;if(!(slot in state))state[slot]=initial;return [state[slot],async submitted=>{state[slot]=await callback(state[slot],submitted);return state[slot];},false];},
  },
  'next/navigation':{useRouter:()=>({refresh(){}}),redirect:href=>{throw Object.assign(new Error('redirect'),{href});},notFound:()=>{throw new Error('notFound');}},
  'next/link':{default:props=>React.createElement('a',props)},
  'next/cache':{revalidatePath(){}},
  '@/lib/supabase/server':{createSupabaseServerClient:async()=>client},
  '@/components/context-navigation':{PageFrame:props=>props.children},
 };
 const cache=new Map();
 function load(filename) {
  if(cache.has(filename))return cache.get(filename);
  const loadedModule={exports:{}};cache.set(filename,loadedModule.exports);
  const result=ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022,esModuleInterop:true}});
  const localRequire=name=>{
   if(name in stubs)return stubs[name];
   if(name.endsWith('.css'))return {};
   if(name.startsWith('.')){
    const base=path.resolve(path.dirname(filename),name);
    const file=['.ts','.tsx'].map(ext=>base+ext).find(fs.existsSync);
    if(file)return load(file);
   }
   return require(name);
  };
  vm.runInThisContext(`(function(require,module,exports,localStorage,window){${result.outputText}\n})`,{filename})(localRequire,loadedModule,loadedModule.exports,browserStorage,browserWindow);
  cache.set(filename,loadedModule.exports);return loadedModule.exports;
 }
 const forms=load(path.join(root,'CorrectionForms.tsx'));
 function find(element,predicate) {
  if(!element||typeof element!=='object')return null;
  if(predicate(element))return element;
  for(const child of React.Children.toArray(element.props?.children)) {const result=find(child,predicate);if(result)return result;}
  return null;
 }
 function values(element,form=new FormData()) {
  if(!element||typeof element!=='object')return form;
  const p=element.props??{};
  if(['input','select','textarea'].includes(element.type)&&p.name)form.append(p.name,String(p.value??''));
  // The actual selector's controlled value is submitted under its input name.
  if(typeof element.type==='function'&&element.type.name==='PagedChoice'&&p.name)form.append(p.name,String(p.value??''));
  for(const child of React.Children.toArray(p.children))values(child,form);
  return form;
 }
 return {calls,workspace,savedCase,load,find,values,forms,render:p=>{index=0;return forms.ProposalForm(p);},recover:f=>browserStorage.setItem('payroll-correction:v1:'+JSON.stringify([actor,tenant,employer,output]),JSON.stringify({version:1,form:'proposal',attempt:id(15),href:browserWindow.location.pathname,entries:Array.from(f.entries()),previous:{error:'',saved:false,signature:'',attempt:''}})),kind};
}
for(const [type,fields] of cases) {
 test(`saved ${type}${fields.employee_id?' existing employee':''} survives page → form → preview`,async()=>{
  const h=harness({type,source_id:type==='new_employment'?undefined:source,expected_hash:type==='new_employment'?undefined:hash,fields});
  const Page=h.load(path.join(root,'page.tsx')).default;
  const element=await Page({params:Promise.resolve({tenantId:tenant}),searchParams:Promise.resolve({employer,output,case:id(6),edit:'1',kind:h.kind})});
  const form=h.find(element,x=>x.type===h.forms.ProposalForm);assert.ok(form,'saved proposal is reachable with no source query');
  assert.deepEqual(form.props.initialProposal.fields,fields);
  const submitted=h.values(h.render(form.props));submitted.set('operation','preview');
  const action=h.load(path.join(root,'actions.ts')).correctionAction;
  await action({saved:false,error:'',signature:'',attempt:''},submitted);
  const command=h.calls.find(x=>x.name==='payroll_correction_proposal');assert.ok(command);
  assert.deepEqual(command.args.p_changes[0].fields,fields);
  assert.equal(command.args.p_changes[0].type,type);
  assert.equal(command.args.p_changes[0].expected_hash,type==='new_employment'?null:hash,'saved stale hash is not replaced by current hash');
  assert.equal(command.args.p_reason,'Saved reason');assert.equal(command.args.p_reference,'Saved reference');
  assert.equal(command.args.p_target,id(13));assert.equal(command.args.p_rows[0].amount,'-12.35');assert.equal(command.args.p_rows[0].output_id,id(11));
 });
}
test('pending request restoration overrides saved proposal fields and retains exact replay intent',async()=>{
 const h=harness({type:'compensation',source_id:source,expected_hash:hash,fields:cases[0][1]});
 const p={actor,tenant,employer,output,kind:'compensation',revision:3,source:{id:source,expected_hash:hash,fields:defaults},initialProposal:{fields:cases[0][1],reason:'Saved reason',reference:'Saved reference',target:'',rows:[],split:false},employees:[],sites:[],references:{},periods:[],components:[],outputs:[],everPaid:false};
 const pending=h.values(h.render(p));pending.set('field:amount','999.99');pending.set('reason','Pending reason');h.recover(pending);
 h.render(p);const restored=h.values(h.render(p));assert.equal(restored.get('field:amount'),'999.99');assert.equal(restored.get('reason'),'Pending reason');
 const action=h.load(path.join(root,'actions.ts')).correctionAction;
 const result=await action({saved:false,error:'',signature:JSON.stringify({rpc:'payroll_correction_proposal',args:{p_expected:3}}),attempt:id(15),recoverPending:true},restored);
 assert.equal(result.recoverPending,true);assert.equal(h.calls.length,0,'different replay cannot execute a new RPC');
});
test('editing a saved kind redirects to its own editor before loading a different source',async()=>{
 const h=harness({type:'assignment_split',source_id:source,expected_hash:hash,fields:cases[3][1]});
 const Page=h.load(path.join(root,'page.tsx')).default;
 await assert.rejects(()=>Page({params:Promise.resolve({tenantId:tenant}),searchParams:Promise.resolve({employer,output,case:id(6),edit:'1'})}),error=>new URL(error.href,'http://localhost').searchParams.get('kind')==='assignment');
 assert.equal(h.calls.length,1);
});
test('editing one ordinary change preserves its saved sibling and all responsibility rows',async()=>{
 const h=harness({type:'compensation',source_id:source,expected_hash:hash,fields:cases[0][1]});
 const sibling={type:'employment',source_id:id(16),expected_hash:currentHash,fields:cases[4][1]};
 h.savedCase.changes.push(sibling);
 h.savedCase.responsibilities.push({...h.savedCase.responsibilities[0],employment_id:id(17),output_id:id(18),amount:'45.20'});
 const Page=h.load(path.join(root,'page.tsx')).default;
 const element=await Page({params:Promise.resolve({tenantId:tenant}),searchParams:Promise.resolve({employer,output,case:id(6),edit:'1',kind:'compensation'})});
 const form=h.find(element,x=>x.type===h.forms.ProposalForm);
 const submitted=h.values(h.render(form.props));submitted.set('operation','preview');
 await h.load(path.join(root,'actions.ts')).correctionAction({saved:false,error:'',signature:'',attempt:''},submitted);
 const command=h.calls.find(x=>x.name==='payroll_correction_proposal');
 assert.deepEqual(command.args.p_changes[1],sibling);assert.equal(command.args.p_rows.length,2);assert.equal(command.args.p_rows[1].output_id,id(18));
});
test('saved multi-source observations still restore exact hashes and responsibilities',async()=>{
 const h=harness({type:'source_change',source_id:source,expected_hash:hash,fields:{}});
 h.savedCase.changes.push({type:'source_change',source_id:id(16),expected_hash:currentHash,fields:{}});
 const Page=h.load(path.join(root,'page.tsx')).default;
 const element=await Page({params:Promise.resolve({tenantId:tenant}),searchParams:Promise.resolve({employer,output,case:id(6),edit:'1',kind:'source_change'})});
 const form=h.find(element,x=>x.type===h.forms.ProposalForm);
 const submitted=h.values(h.render(form.props));submitted.set('operation','preview');
 await h.load(path.join(root,'actions.ts')).correctionAction({saved:false,error:'',signature:'',attempt:''},submitted);
 const command=h.calls.find(x=>x.name==='payroll_correction_proposal');
 assert.deepEqual(command.args.p_changes.map(x=>x.expected_hash),[hash,currentHash]);assert.equal(command.args.p_rows[0].output_id,id(11));
});
