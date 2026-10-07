const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const repo=process.env.UX_REPO_ROOT||path.resolve(__dirname,'../../../..'),req=require('node:module').createRequire(path.join(repo,'package.json')),ts=req('typescript');
const files=JSON.parse(fs.readFileSync(path.join(__dirname,'files.json'))),id='a1111111-1111-4111-8111-111111111111',other='b2222222-2222-4222-8222-222222222222',key='c3333333-3333-4333-8333-333333333333';
function runtime(kind,config={},before=false){const calls=[];let setups=0;const cache=new Map();
 function load(file){if(cache.has(file))return cache.get(file);const i=files.indexOf(file);const source=i>=0?fs.readFileSync(path.join(__dirname,`${before?'before':'candidate'}-${i}.txt`),'utf8'):fs.readFileSync(path.join(repo,file),'utf8');const exports={};cache.set(file,exports);
  const resolve=name=>name==='next/navigation'?{redirect:url=>{throw Object.assign(Error('redirect'),{url})}}:name==='@/lib/supabase/server'?{createSupabaseServerClient:async()=>{setups++;return config.setup===false?null:{auth:{getUser:async()=>({data:{user:config.session===false?null:{id}}})},rpc:async(name,params)=>{calls.push({name,params:JSON.parse(JSON.stringify(params))});if(config.throws)throw Error('synthetic-transport-unknown');return{data:config.data,error:config.error||null}}}}}:name.startsWith('.')?load(path.posix.join(path.posix.dirname(file),name)+'.ts'):req(name);
  vm.runInNewContext(ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,esModuleInterop:true}}).outputText,{exports,require:resolve});return exports;
 }
 const mod=load(files[kind==='cancel'?1:0]),action=kind==='submit'?mod.submitLeaveRequestAction:kind==='withdraw'?mod.withdrawLeaveRequestAction:mod.requestLeaveCancellationAction;
 const fields={tenantId:id,requestId:id,leaveTypeId:other,idempotencyKey:key,expectedVersion:'2',startDate:'2026-10-10',endDate:'2026-10-10',halfDay:'false',reason:'سبب تجريبي'};
 return{calls,async run(overrides={}){const form=new FormData();for(const [k,v]of Object.entries({...fields,...overrides}))form.set(k,v);try{return{reply:JSON.parse(JSON.stringify(await action({error:'',attempt:4},form))),setups}}catch(e){return{redirect:e.url,thrown:e.url?undefined:e.message,setups}}}};
}
const valid={submit:{id,state:'submitted',version:1},withdraw:{id,state:'withdrawn',version:3},cancel:{state:'pending',cancellation:{id:other,request_id:id,state:'pending',version:1},request:{id,state:'approved',version:2}}};
const cases=[];async function check(name,fn){await fn();cases.push({name,result:'PASS'})}
(async()=>{
 for(const kind of Object.keys(valid)){
  await check(kind+' valid fresh-or-stored-replay response shape',async()=>{const a=runtime(kind,{data:valid[kind]},true),b=runtime(kind,{data:valid[kind]});assert.deepEqual(await a.run(),await b.run());assert.deepEqual(a.calls,b.calls);assert.equal(b.calls.length,1);assert.equal(b.calls[0].params.p_idempotency_key,key);});
  const bad=[null,false,[],{},'bad',kind==='cancel'?{state:'pending'}:{id}];
  if(kind==='submit')bad.push({id:'bad',state:'submitted'},{id,state:'approved'},{id,state:'withdrawn'});
  if(kind==='withdraw')bad.push({id:other,state:'withdrawn'},{id,state:'submitted'},{id,state:'approved'},{id:'bad',state:'withdrawn'});
  if(kind==='cancel')for(const [target,field,value]of [['cancellation','id','bad'],['cancellation','request_id',other],['cancellation','state','accepted'],['request','id',other],['request','state','cancelled'],['request','id','bad']]){const x=JSON.parse(JSON.stringify(valid.cancel));x[target][field]=value;bad.push(x)}
  for(const [n,data]of bad.entries())await check(kind+' malformed outcome '+n,async()=>{const e=runtime(kind,{data}),r=await e.run();assert(r.reply?.error);assert.equal(r.reply.attempt,5);assert(!r.redirect);assert.equal(e.calls.length,1);});
  await check(kind+' RPC thrown unknown is recoverable without retry',async()=>{const a=runtime(kind,{throws:true},true),b=runtime(kind,{throws:true});assert((await a.run()).thrown);const r=await b.run();assert(r.reply.error);assert(!r.thrown&&!r.redirect);assert.equal(b.calls.length,1);assert.deepEqual(a.calls,b.calls);});
  for(const cfg of [{setup:false},{session:false},{error:{code:'42501',message:'leave_forbidden'}},{error:{code:'23505',message:'leave_idempotency_conflict'}},{error:{code:'40001',message:'leave_request_version_conflict'} }])await check(kind+' unchanged setup/session/RPC-error '+JSON.stringify(cfg),async()=>{const a=runtime(kind,{data:valid[kind],...cfg},true),b=runtime(kind,{data:valid[kind],...cfg});assert.deepEqual(await a.run(),await b.run());assert.deepEqual(a.calls,b.calls)});
  for(const overrides of [{tenantId:'bad'},{idempotencyKey:'bad'},{reason:'ab'},...(kind==='submit'?[{halfDay:'true',endDate:'2026-10-11'},{startDate:'bad'}]:[{expectedVersion:'0'},{requestId:'bad'}])])await check(kind+' local-invalid no SDK '+JSON.stringify(overrides),async()=>{const a=runtime(kind,{data:valid[kind]},true),b=runtime(kind,{data:valid[kind]});const actual=await b.run(overrides);assert.deepEqual(await a.run(overrides),actual);assert.equal(b.calls.length,0);assert.equal(actual.setups,0);});
  if(kind!=='submit')await check(kind+' UUID input/output case compatibility',async()=>{const e=runtime(kind,{data:valid[kind]});assert((await e.run({requestId:id.toUpperCase()})).redirect)});
 }
 fs.writeFileSync(path.join(__dirname,'focused-results.json'),JSON.stringify({passed:cases.length,failed:0,cases},null,2));console.log(JSON.stringify({passed:cases.length,failed:0}));
})().catch(e=>{console.error(e.stack);process.exitCode=1});
