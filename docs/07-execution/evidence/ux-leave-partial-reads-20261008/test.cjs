const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const repo=process.env.UX_REPO_ROOT||path.resolve(__dirname,'../../../..'),req=require('node:module').createRequire(path.join(repo,'package.json')),React=req('react'),render=req('react-dom/server').renderToStaticMarkup,ts=req('typescript');
const files=JSON.parse(fs.readFileSync(path.join(__dirname,'files.json'))),id='11111111-1111-4111-8111-111111111111';
const detail={id,leave_type_name:'نوع تجريبي',start_date:'2026-10-10',end_date:'2026-10-10',total_units:1,is_half_day:false,state:'submitted',version:2,reason:'سبب تجريبي',submitted_at:'2026-10-08T00:00:00Z',request_source:'employee',days:[],correction_links:[]};
function runtime(config={},before=false){
 const calls=[],cache=new Map();
 const sdk={auth:{getUser:async()=>({data:{user:config.noUser?null:{id}}})},rpc:(name,params)=>{if(config.syncThrow===name){calls.push({name,params:JSON.parse(JSON.stringify(params))});throw Error('synthetic-sync')}return read(name,params);}};
 async function read(name,params){calls.push({name,params:JSON.parse(JSON.stringify(params))});if(config.throws===name||config.throws?.includes(name))throw Error('synthetic-transport');if(config.fail===name)return{data:null,error:{code:config.errorCode||'XX000',message:'synthetic-read-failed'}};
 const data=name==='leave_access_snapshot'?{self_access:!config.denied,self_can_request:!!config.canRequest,new_work_enabled:!!config.canRequest}:name==='leave_my_requests'?{items:config.requests||[],has_more:false}:name==='leave_my_balances'?{items:config.balances||[],has_more:false}:name==='leave_my_request_detail'?{...detail,state:config.state||'submitted',correction_links:config.links||[]}:name==='leave_my_cancellation_history'?{items:[],has_more:false,latest_event:config.latest||null}:undefined;
 if(data===undefined)throw Error('Unexpected or mutation RPC '+name);return{data:config.nullData===name?null:data,error:null};}
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
 return{calls,async page(kind,query={}){return render(await load(files[kind==='list'?0:1]).default({params:Promise.resolve({tenantId:id,requestId:id}),searchParams:Promise.resolve(query)}))},async historyLoad(offset=0){return load(files[2]).loadCancellationHistory(sdk,id,id,offset)},history(code){return render(React.createElement(load(files[2]).CancellationHistorySection,{tenantId:id,requestId:id,view:{ok:false,code},requestedOffset:0,offsetInvalid:false,currentUserId:id}))}};
}
const hrefs=h=>[...h.matchAll(/href="([^"]+)"/g)].map(m=>m[1]);const cases=[];
async function check(name,fn){await fn();cases.push({name,result:'PASS'})}
(async()=>{
 const balance={leave_type_id:id,period_id:id,type_name:'رصيد تجريبي',period_label:'فترة تجريبية',starts_on:'2026-01-01',balance_days:4};
 for(const canRequest of [false,true])for(const state of ['submitted','withdrawn','approved','rejected','cancelled','draft'])await check('unchanged known detail '+canRequest+':'+state,async()=>{const cfg={state,canRequest};const a=runtime(cfg,true),b=runtime(cfg);assert.equal(await a.page('detail'),await b.page('detail'));assert.deepEqual(a.calls,b.calls)});
 for(const name of ['leave_my_balances','leave_my_requests'])for(const kind of ['fail','throws','syncThrow'])await check('list sibling preserved '+kind+':'+name,async()=>{
  const cfg={[kind]:name,canRequest:true,requests:[detail],balances:[balance]},now=runtime(cfg),html=await now.page('list',{page:'2',bal:'3'});
  assert(html.includes(name==='leave_my_balances'?'نوع تجريبي':'رصيد تجريبي'));assert(html.includes(name==='leave_my_balances'?'تعذر تحميل أرصدة إجازاتك':'تعذر تحميل سجل طلباتك'));
  assert.equal(now.calls.length,3);assert.equal(now.calls.find(c=>c.name==='leave_my_balances').params.p_offset,20);assert.equal(now.calls.find(c=>c.name==='leave_my_requests').params.p_offset,10);
  if(kind==='fail'){const old=runtime(cfg,true);assert.equal(html,await old.page('list',{page:'2',bal:'3'}));assert.deepEqual(now.calls,old.calls)}else await assert.rejects(runtime(cfg,true).page('list',{page:'2',bal:'3'}));
 });
 for(const kind of ['throws','syncThrow'])for(const key of ['bal','page'])await check('invalid pager suppresses target RPC '+kind+':'+key,async()=>{const skipped=key==='bal'?'leave_my_balances':'leave_my_requests',r=runtime({[kind]:skipped});const h=await r.page('list',{[key]:'bad'});assert(h.includes('غير صالح'));assert(!r.calls.some(c=>c.name===skipped));assert.equal(r.calls.length,2)});
 await check('both list reads throw recover independently',async()=>{const h=await runtime({throws:['leave_my_balances','leave_my_requests']}).page('list');assert(h.includes('تعذر تحميل أرصدة إجازاتك'));assert(h.includes('تعذر تحميل سجل طلباتك'));assert(!h.includes('لم يتغيّر'))});
 for(const name of ['leave_my_cancellation_history','leave_access_snapshot'])for(const kind of ['fail','throws','syncThrow'])await check('approved detail retained cancellation blocked '+kind+':'+name,async()=>{const cfg={state:'approved',canRequest:true,[kind]:name},r=runtime(cfg),h=await r.page('detail');assert(h.includes('نوع تجريبي'));assert(!h.includes('data-form="cancellation"'));assert(h.includes('إعادة المحاولة'));assert.equal(r.calls.length,3);if(kind==='fail')assert.equal(h,await runtime(cfg,true).page('detail'));else await assert.rejects(runtime(cfg,true).page('detail'))});
 for(const state of ['submitted','superseded'])await check('history throw preserves distinct detail authority '+state,async()=>{const h=await runtime({state,throws:'leave_my_cancellation_history',canRequest:true}).page('detail');assert(h.includes('نوع تجريبي'));assert.equal(h.includes('data-form="withdraw"'),state==='submitted');assert(!h.includes('data-form="cancellation"'))});
 for(const kind of ['throws','syncThrow'])await check('detail transport classified technical retry '+kind,async()=>{const h=await runtime({[kind]:'leave_my_request_detail'}).page('detail');assert(h.includes('تعذر تحميل الطلب الآن'));assert(!h.includes('الطلب غير متاح'));assert(h.includes('إعادة المحاولة'));assert(hrefs(h).includes(`/tenant/${id}/me/leave/${id}`))});
 for(const errorCode of ['P0002','42501'])await check('detail authority error classification unchanged '+errorCode,async()=>{const cfg={fail:'leave_my_request_detail',errorCode},h=await runtime(cfg).page('detail');assert.equal(h,await runtime(cfg,true).page('detail'));assert(!h.includes('إعادة المحاولة'))});
 await check('null successful detail still source unavailable',async()=>{const cfg={nullData:'leave_my_request_detail'},h=await runtime(cfg).page('detail');assert.equal(h,await runtime(cfg,true).page('detail'));assert(h.includes('الطلب غير متاح'))});
 for(const kind of ['throws','syncThrow'])await check('history loader catches only RPC '+kind,async()=>{const r=runtime({[kind]:'leave_my_cancellation_history'});const view=await r.historyLoad(50);assert.equal(view.ok,false);assert.equal(view.code,'failed');assert.equal(r.calls[0].params.p_offset,50);assert.equal(r.calls[0].params.p_limit,50)});
 for(const cfg of [{denied:true},{noSdk:true}])await check('list authority/setup unchanged '+JSON.stringify(cfg),async()=>{assert.equal(await runtime(cfg).page('list'),await runtime(cfg,true).page('list',{page:'2',bal:'3'}))});
 await check('auth redirect escapes unchanged',async()=>{await assert.rejects(runtime({noUser:true}).page('detail'),e=>e.url===`/auth/login?next=${encodeURIComponent(`/tenant/${id}/me/leave/${id}`)}`)});
 await check('superseded historical original readable no mutation',async()=>{const replacement='22222222-2222-4222-8222-222222222222',cfg={state:'superseded',canRequest:true,links:[{original_request_id:id,replacement_request_id:replacement,reason:'تصحيح تجريبي',created_at:'2026-10-08T00:00:00Z'}]},a=runtime(cfg,true),b=runtime(cfg),old=await a.page('detail'),h=await b.page('detail');assert(old.includes('غير محدّد'));assert(h.includes('مستبدَل'));assert(h.includes('استُبدل هذا الطلب ضمن تصحيح الإجازة'));assert(!h.includes('أُلغيت الإجازة'));assert(!h.includes('data-form'));assert(hrefs(h).includes(`/tenant/${id}/me/leave/${replacement}`));assert.deepEqual(hrefs(old),hrefs(h));assert.deepEqual(a.calls,b.calls)});
 await check('superseded list label preserves own record link',async()=>{const h=await runtime({requests:[{...detail,state:'superseded'}]}).page('list');assert(h.includes('مستبدَل'));assert(hrefs(h).includes(`/tenant/${id}/me/leave/${id}`))});
 fs.writeFileSync(path.join(__dirname,'focused-results.json'),JSON.stringify({passed:cases.length,failed:0,cases},null,2));console.log(JSON.stringify({passed:cases.length,failed:0}));
})().catch(e=>{console.error(e.stack);process.exitCode=1});
