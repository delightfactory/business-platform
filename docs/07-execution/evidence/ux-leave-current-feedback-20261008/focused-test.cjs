const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const repo=process.env.UX_REPO_ROOT||path.resolve(__dirname,'../../../..'),req=require('node:module').createRequire(path.join(repo,'package.json')),React=req('react'),render=req('react-dom/server').renderToStaticMarkup,ts=req('typescript');
const files=JSON.parse(fs.readFileSync(path.join(__dirname,'files.json'))),id='11111111-1111-4111-8111-111111111111';
const detail={id,leave_type_name:'نوع تجريبي',start_date:'2026-10-10',end_date:'2026-10-10',total_units:1,is_half_day:false,state:'submitted',version:2,reason:'سبب تجريبي',submitted_at:'2026-10-08T00:00:00Z',request_source:'employee',days:[],correction_links:[]};
function runtime(config={},before=false){
 const calls=[],cache=new Map();
 const sdk={auth:{getUser:async()=>({data:{user:config.noUser?null:{id}}})},rpc:async(name,params)=>{calls.push({name,params:JSON.parse(JSON.stringify(params))});if(config.fail===name)return{data:null,error:{code:'XX000',message:'synthetic-read-failed'}};
 const data=name==='leave_access_snapshot'?{self_access:!config.denied,self_can_request:!!config.canRequest,new_work_enabled:!!config.canRequest}:name==='leave_my_requests'?{items:config.requests||[],has_more:false}:name==='leave_my_balances'?{items:[],has_more:false}:name==='leave_my_request_detail'?{...detail,state:config.state||'submitted'}:name==='leave_my_cancellation_history'?{items:[],has_more:false,latest_event:config.latest||null}:undefined;
 if(data===undefined)throw Error('Unexpected or mutation RPC '+name);return{data,error:null};}};
 function load(file){
  if(cache.has(file))return cache.get(file);const index=files.indexOf(file);
  const code=index>=0?fs.readFileSync(path.join(__dirname,`${before?'before':'candidate'}-${index}.txt`),'utf8'):fs.readFileSync(path.join(repo,file),'utf8');
  const exports={};cache.set(file,exports);
  function resolve(name){if(name==='react'||name==='react/jsx-runtime')return req(name);
   if(name==='next/link')return{__esModule:true,default:({children,...props})=>React.createElement('a',props,children)};
   if(name==='next/navigation')return{redirect:url=>{throw Object.assign(Error('redirect'),{url})},notFound:()=>{throw Error('notFound')}};
   if(name==='@/lib/supabase/server')return{createSupabaseServerClient:async()=>config.noSdk?null:sdk};
   if(name==='@/components/context-navigation')return{PageFrame:({children})=>React.createElement('main',{},children)};
   if(name==='@/components/feedback-toast')return{FeedbackToast:({message})=>React.createElement('div',{'data-toast':'true',role:'status'},message)};
   if(name.endsWith('RequestCancellationForm')||name.endsWith('WithdrawRequestForm'))return{RequestCancellationForm:props=>React.createElement('div',{'data-form':'cancellation','data-version':props.expectedVersion}),WithdrawRequestForm:props=>React.createElement('div',{'data-form':'withdraw','data-version':props.expectedVersion})};
   if(name.endsWith('.css'))return{__esModule:true,default:new Proxy({},{get:(_,key)=>String(key)})};
   if(name==='./pending-link'||name==='../pending-link')return{PendingLink:({children,...props})=>React.createElement('a',props,children)};
   if(name.startsWith('.')){const stem=path.posix.join(path.posix.dirname(file),name);const target=['.ts','.tsx'].map(ext=>stem+ext).find(p=>fs.existsSync(path.join(repo,p)));if(!target)throw Error('Missing '+stem);return load(target)};
   throw Error('Unapproved import '+name);
  }
  vm.runInNewContext(ts.transpileModule(code,{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,esModuleInterop:true}}).outputText,{exports,require:resolve,URLSearchParams,crypto:{randomUUID:()=>id}});return exports;
 }
 return{calls,async page(kind,query={}){return render(await load(files[kind==='list'?0:1]).default({params:Promise.resolve({tenantId:id,requestId:id}),searchParams:Promise.resolve(query)}))},history(code){return render(React.createElement(load(files[2]).CancellationHistorySection,{tenantId:id,requestId:id,view:{ok:false,code},requestedOffset:0,offsetInvalid:false,currentUserId:id}))}};
}
const hrefs=h=>[...h.matchAll(/href="([^"]+)"/g)].map(m=>m[1]);const cases=[];
async function check(name,fn){await fn();cases.push({name,result:'PASS'})}
(async()=>{
 for(const canRequest of [false,true])for(const state of ['submitted','withdrawn',undefined,'approved',['submitted']])await check('list hint '+canRequest+':'+JSON.stringify(state),async()=>{
  const before=runtime({canRequest},true),now=runtime({canRequest}),q={state};const a=await before.page('list',q),b=await now.page('list',q);
  assert.deepEqual(now.calls,before.calls);assert.deepEqual(hrefs(a),hrefs(b));assert(!b.includes('data-toast'));
  if(typeof state==='string'&&['submitted','withdrawn'].includes(state)){assert(a.includes('data-toast'));assert(b.includes('راجع سجل طلبات الإجازة لمعرفة الحالة الحالية لطلباتك'))}else assert.equal(a,b);
 });
 for(const failure of ['leave_my_requests','leave_my_balances'])await check('partial read no unchanged claim '+failure,async()=>{const before=runtime({fail:failure},true),now=runtime({fail:failure});const a=await before.page('list'),b=await now.page('list');assert(a.includes('لم يتغيّر'));assert(!b.includes('لم يتغيّر'));assert(b.includes('تعذر التحقق من أحدث'));assert.deepEqual(now.calls,before.calls);assert.deepEqual(hrefs(a),hrefs(b));});
 for(const code of ['failed','forbidden','session','unavailable','invalid-page'])await check('history read uncertainty '+code,()=>{const a=runtime({},true).history(code),b=runtime().history(code);assert(a.includes('لم يتغيّر شيء'));assert(!b.includes('لم يتغيّر شيء'));assert(b.includes('قد تكون حالة طلب الإلغاء تغيّرت'));assert.deepEqual(hrefs(a),hrefs(b));assert(b.includes('role="alert"'));});
 for(const state of ['submitted','withdrawn','approved','rejected','cancelled','draft'])for(const hint of ['submitted','withdrawn','cancellation-requested'])await check('detail current state '+state+':'+hint,async()=>{const cfg={state,latest:null},before=runtime(cfg,true),now=runtime(cfg);const a=await before.page('detail',{state:hint}),b=await now.page('detail',{state:hint});assert.deepEqual(now.calls,before.calls);assert.deepEqual(hrefs(a),hrefs(b));assert(!b.includes('تم إرسال طلبك'));assert(!b.includes('تم سحب الطلب وحُفظ'));if(hint===state&&['submitted','withdrawn'].includes(state)){assert(b.includes('حالة طلبك الحالية'))}else assert.equal(a,b);});
 await check('authoritative pending cancellation current-state hint only',async()=>{const latest={id:1,cancellation_id:id,actor_user_id:id,event_key:'employee.requested',from_state:null,to_state:'pending',reason:'سبب تجريبي',time_reconciliation_required:false,created_at:'2026-10-08T00:00:00Z'};const a=runtime({state:'approved',latest},true),b=runtime({state:'approved',latest});const x=await a.page('detail',{state:'cancellation-requested'}),y=await b.page('detail',{state:'cancellation-requested'});assert(x.includes('تم إرسال طلب الإلغاء'));assert(y.includes('طلب الإلغاء معلّق حاليًا'));assert.deepEqual(a.calls,b.calls);assert.deepEqual(hrefs(x),hrefs(y));assert(!y.includes('data-form="cancellation"'));});
 for(const cfg of [{denied:true},{noSdk:true}])await check('denied/setup hints suppressed '+JSON.stringify(cfg),async()=>{const a=await runtime(cfg,true).page('list',{state:'submitted'}),b=await runtime(cfg).page('list',{state:'submitted'});assert.equal(a,b);assert(!b.includes('راجع سجل طلبات الإجازة'))});
 for(const q of [{state:'submitted'},{state:'withdrawn'},{state:'submitted',page:'bad'}])await check('unavailable history guide suppressed '+JSON.stringify(q),async()=>{const cfg=q.page?{}:{fail:'leave_my_requests'};const html=await runtime(cfg).page('list',q);assert(!html.includes('راجع سجل طلبات الإجازة'));});
await check('detail failed cancellation history remains blocked and no unchanged assertion',async()=>{const html=await runtime({state:'approved',fail:'leave_my_cancellation_history',canRequest:true}).page('detail');assert(!html.includes('لم تتغيّر'));assert(!html.includes('data-form="cancellation"'));assert(html.includes('يمكنك مراجعة التفاصيل المتاحة أعلاه'));});
fs.writeFileSync(path.join(__dirname,'focused-results.json'),JSON.stringify({passed:cases.length,failed:0,cases},null,2));console.log(JSON.stringify({passed:cases.length,failed:0}));
})().catch(e=>{console.error(e.stack);process.exitCode=1});
