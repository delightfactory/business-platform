import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {createContext,runInContext} from 'node:vm';
import {webcrypto} from 'node:crypto';
import ts from 'typescript';
import {uuid} from '../rules.ts';
import {paymentError} from './rules.ts';

// Execute the real server action with only its transport/session/cache boundaries replaced.
// The tiny receipt stub models committed/lost transport; SQL ledger qualification remains a separate gate.
const source=ts.transpileModule(readFileSync(new URL('./actions.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const initial={error:'',saved:false,revision:0,signature:'',attempt:''};
function form(reference='Bank reference',amount='100.00',revision='0'){
 const result=new FormData();
 for(const [key,value] of Object.entries({tenant:'c4451000-0000-4000-8000-000000000001',employer:'c4453000-0000-4000-8000-000000000001',output:'c4459500-0000-4000-8000-000000000001',operation:'allocations',date:'2026-10-02',reference,reason:'External payment evidence',confirmed:'yes',revision,employee:'c4455000-0000-4000-8000-000000000001','amount:c4455000-0000-4000-8000-000000000001':amount}))result.set(key,value);
 return result;
}
function harness(){
 const h={mode:'commit-lost',code:'',calls:[],receipts:new Map(),events:0,allocations:0,audits:0,revision:0};
 const client={auth:{getUser:async()=>({data:{user:h.mode==='no-session'?null:{id:'fixture-actor'}}})},rpc:async(name,args)=>{
  h.calls.push({name,args});
  if(h.mode==='error')return {error:{code:h.code,message:h.code==='PT409'?'payroll_payment_stale':'retry rejected before receipt resolution'}};
  if(h.mode==='throw')throw new Error('transport unavailable');
  const prior=h.receipts.get(args.p_attempt);
  if(prior)return {data:prior,error:null};
  h.events++;h.allocations++;h.audits++;h.revision++;
  const receipt={revision:h.revision,amount:'100.00',remaining:'900.00',kind:'payment'};h.receipts.set(args.p_attempt,receipt);
  return h.mode==='commit-lost'?{error:{code:'',message:'committed response lost'}}:{data:receipt,error:null};
 }};
 const dependencies={'next/cache':{revalidatePath:()=>{}},'@/lib/supabase/server':{createSupabaseServerClient:async()=>h.mode==='no-client'?null:client},'../rules':{uuid},'./rules':{paymentError}};
 const context=createContext({exports:{},crypto:webcrypto,require:name=>{assert.ok(name in dependencies,`unexpected dependency ${name}`);return dependencies[name];}});
 runInContext(source,context);
 h.action=context.exports.paymentAction;return h;
}
for(const code of ['42501','55P03','40P01','22023','23514','PT409','55000'])test(`committed response lost → retry ${code} retains original unresolved intent until receipt recovery`,async()=>{
 const h=harness(),lost=await h.action(initial,form());assert.equal(lost.recoverPending,true);
 const originalAttempt=lost.attempt,originalSignature=lost.signature;
 h.mode='error';h.code=code;
 const denied=await h.action(lost,form('Bank reference','100.00','1'));
 assert.equal(denied.recoverPending,true);assert.equal(denied.needsRefresh,false);assert.equal(denied.attempt,originalAttempt);assert.equal(denied.signature,originalSignature);
 const calls=h.calls.length;
 const changed=await h.action(denied,form('Different reference','200.00','1'));
 assert.equal(changed.recoverPending,true);assert.equal(changed.signature,originalSignature);assert.equal(changed.attempt,originalAttempt);assert.equal(h.calls.length,calls,'changed request never reaches RPC');
 h.mode='success';const recovered=await h.action(changed,form('Bank reference','100.00','1'));
 assert.equal(recovered.saved,true);assert.equal(recovered.signature,'');assert.equal(recovered.attempt,'');assert.notEqual(recovered.recoverPending,true);
 assert.equal(h.calls.at(-1).args.p_attempt,originalAttempt);assert.equal(h.calls.at(-1).args.p_expected,0,'refresh does not replace unresolved original CAS');
 assert.deepEqual([h.events,h.allocations,h.audits,h.receipts.size,h.revision],[1,1,1,1,1],'receipt recovery produces no second modeled mutation');
});
test('session/client/transport failures and local validation never release prior unresolved state',async()=>{
 const h=harness();let state=await h.action(initial,form());const attempt=state.attempt,signature=state.signature;
 for(const mode of ['no-session','no-client','throw']){h.mode=mode;state=await h.action(state,form());assert.equal(state.recoverPending,true);assert.equal(state.attempt,attempt);assert.equal(state.signature,signature);}
 const invalid=form();invalid.set('tenant','invalid');state=await h.action(state,invalid);assert.equal(state.recoverPending,true);assert.equal(state.attempt,attempt);assert.equal(state.signature,signature);
});
test('a fresh definitively rejected command does not invent earlier uncertainty',async()=>{
 for(const code of ['42501','55P03','40P01','PT409']){const h=harness();h.mode='error';h.code=code;const rejected=await h.action(initial,form());assert.equal(rejected.recoverPending,false);assert.equal(rejected.needsRefresh,code==='PT409');assert.equal(h.events,0);}
});
