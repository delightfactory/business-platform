import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import ts from 'typescript';
import React from 'react';

// Actual Leave action/rules/form; only React/Next/Supabase transport boundaries
// are emulated. This does not replace authenticated browser acceptance.
const root=path.resolve('src/app/tenant/[tenantId]/leave');
const require=createRequire(import.meta.url);
const tenant='c4331000-0000-4000-8000-000000000001',request='c4332000-0000-4000-8000-000000000001';
function harness({permission=true,error=null}={}){
 const calls=[],slots=[];let index=0;
 const client={auth:{getUser:async()=>({data:{user:{id:'synthetic-actor'}}})},rpc:async(name,args)=>{
  calls.push({name,args});
  if(name==='leave_access_snapshot')return {data:{can_view:true,can_manage:false,can_approve:permission,new_work_enabled:true}};
  return {data:error?null:{state:'approved'},error};
 }};
 const stubs={
  react:{...React,useState:initial=>{const slot=index++;if(!(slot in slots))slots[slot]=typeof initial==='function'?initial():initial;return [slots[slot],value=>{slots[slot]=value;}];},useRef:initial=>{const slot=index++;if(!(slot in slots))slots[slot]={current:initial};return slots[slot];},useActionState:(action,initial)=>[initial,action,false]},
  'react-dom':{useFormStatus:()=>({pending:false})},
  'next/link':{default:'a',useLinkStatus:()=>({pending:false})},
  'next/navigation':{redirect:href=>{throw Object.assign(new Error('redirect'),{href});}},
  '@/lib/supabase/server':{createSupabaseServerClient:async()=>client},
 };
 const cache=new Map();
 function load(filename){
  if(cache.has(filename))return cache.get(filename);
  const loaded={exports:{}};cache.set(filename,loaded.exports);
  const result=ts.transpileModule(fs.readFileSync(filename,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022,esModuleInterop:true}});
  const localRequire=name=>{
   if(name in stubs)return stubs[name];
   if(name.startsWith('.')||name.startsWith('@/')){
    const base=name.startsWith('@/')?path.resolve('src',name.slice(2)):path.resolve(path.dirname(filename),name);
    const file=['.ts','.tsx'].map(ext=>base+ext).find(fs.existsSync);if(file)return load(file);
   }
   return require(name);
  };
  vm.runInThisContext(`(function(require,module,exports){${result.outputText}\n})`,{filename})(localRequire,loaded,loaded.exports);
  return loaded.exports;
 }
 const actions=load(path.join(root,'actions.ts'));
 const forms=load(path.join(root,'requests/[requestId]/ReviewIntentForm.tsx'));
 function render(){index=0;const wrapper=forms.ReviewIntentForm({intent:'approve',tenantId:tenant,requestId:request,expectedVersion:1,reviewedPreviewVersion:1,submitLabel:'اعتماد',pendingLabel:'جارٍ الاعتماد',hint:'راجع الطلب'});return wrapper.type(wrapper.props);}
 return {calls,actions,render};
}
function find(element,predicate){
 if(!element||typeof element!=='object')return null;if(predicate(element))return element;
 for(const child of React.Children.toArray(element.props?.children)){const found=find(child,predicate);if(found)return found;}return null;
}
function input(historical=false){const form=new FormData();for(const [key,value] of Object.entries({tenantId:tenant,requestId:request,operationKey:'c4333000-0000-4000-8000-000000000001',expectedVersion:'1',reviewedPreviewVersion:'1',reason:'Reviewed historical source'}))form.set(key,value);if(historical)form.set('historicalPayrollCorrection','on');return form;}
for(const historical of [false,true])test(`actual action sends ${historical?'explicit historical':'ordinary'} approval and exact receipt identity`,async()=>{
 const h=harness();await assert.rejects(h.actions.approveRequestAction({attempt:0},input(historical)),error=>error.href?.includes(historical?'payrollCorrection=required':'state=approved'));
 const mutation=h.calls.at(-1);assert.equal(mutation.name,historical?'leave_approve_historical_request':'leave_approve_request');assert.equal(mutation.args.p_expected_version,1);assert.equal(mutation.args.p_reviewed_preview_version,1);assert.equal(mutation.args.p_idempotency_key,input().get('operationKey'));assert.ok(!('amount' in mutation.args));
});
test('loss of Leave approval authority prevents historical mutation',async()=>{
 const h=harness({permission:false});const result=await h.actions.approveRequestAction({attempt:0},input(true));assert.ok(result.error);assert.deepEqual(h.calls.map(call=>call.name),['leave_access_snapshot']);
});
test('ordinary locked-source refusal offers the explicit correction path without resubmit',async()=>{
 const h=harness({error:{message:'payroll_locked_leave_addition_requires_correction',code:'23514'}});const result=await h.actions.approveRequestAction({attempt:0},input());assert.match(result.error,/مسير مقفل/);assert.match(result.error,/تصحيحات الرواتب/);assert.equal(h.calls.length,2);
});
test('actual form gives historical intent a distinct stable operation key and preserves reason',()=>{
 const h=harness();let tree=h.render();const key=()=>find(tree,item=>item.props?.name==='operationKey').props.value;
 const ordinary=key();find(tree,item=>item.type==='textarea').props.onChange({target:{value:'Retained reason'}});tree=h.render();const ordinaryWithReason=key();assert.notEqual(ordinaryWithReason,ordinary);
 find(tree,item=>item.props?.name==='historicalPayrollCorrection').props.onChange({target:{checked:true}});tree=h.render();const historical=key();assert.notEqual(historical,ordinaryWithReason);assert.equal(find(tree,item=>item.type==='textarea').props.value,'Retained reason');
 find(tree,item=>item.props?.name==='historicalPayrollCorrection').props.onChange({target:{checked:false}});tree=h.render();assert.equal(key(),ordinaryWithReason);
 find(tree,item=>item.props?.name==='historicalPayrollCorrection').props.onChange({target:{checked:true}});tree=h.render();assert.equal(key(),historical);assert.equal(find(tree,item=>item.props?.name==='historicalPayrollCorrection').props.checked,true);
});
