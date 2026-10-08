const fs=require('fs'),vm=require('vm'),cp=require('child_process'),assert=require('assert/strict'),path=require('path'),crypto=require('crypto');
const repo=process.cwd(),ts=require(path.join(repo,'node_modules/typescript')),React=require(path.join(repo,'node_modules/react')),jsx=require(path.join(repo,'node_modules/react/jsx-runtime'));
const baseline='a8422f14d6c9bfea24166d5fa8ac388a12afc55b',cases=[];
function load(text,imports,globals={}){const exports={};vm.runInNewContext(ts.transpileModule(text,{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText,{exports,require:imports,...globals});return exports;}
const read=file=>fs.readFileSync(path.join(repo,file),'utf8');
const prior=file=>cp.execFileSync('git',['show',baseline+':'+file],{cwd:repo,encoding:'utf8'});
const rules=load(read('src/app/tenant/[tenantId]/payroll/advances/rules.ts'),()=>{throw Error('Unexpected rules import');});
function nodes(tree,predicate){if(!React.isValidElement(tree))return [];return [...(predicate(tree)?[tree]:[]),...React.Children.toArray(tree.props.children).flatMap(child=>nodes(child,predicate))];}
const form=tree=>nodes(tree,n=>n.type==='form')[0];
const named=(tree,name)=>nodes(tree,n=>n.props.name===name)[0];
function engine(kind,old=false,extra={}){
 const slots=[],refs=[],effects=[],effectDeps=[],subscriptions=[],cleanups=[],transitions=[],storage=new Map(),listeners=new Map();let index=0;
 if(extra.journal!==undefined)storage.set('employee-advance:v1:'+JSON.stringify(['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']),extra.journal);
 const stats={uuid:0,writes:0,removes:0,locks:0,actions:0,formData:0,notifications:0,signalRefresh:0,refresh:0};
 const navigator={onLine:true,locks:{request:async(_key,run)=>{stats.locks++;return run();}}};
 const hooks={
  useState:initial=>{const pos=index++;if(!(pos in slots))slots[pos]=typeof initial==='function'?initial():initial;return [slots[pos],next=>slots[pos]=typeof next==='function'?next(slots[pos]):next];},
  useReducer:(reducer,initial)=>{const [value,set]=hooks.useState(initial);return [value,()=>{stats.signalRefresh++;set(reducer);}];},
  useRef:value=>{const pos=index++;if(!refs[pos])refs[pos]={current:value};return refs[pos];},
  useId:()=>{const pos=index++;return 'qa-offline-'+pos;},
  useEffect:(run,deps)=>{const pos=index++;if(!effectDeps[pos]||!deps||deps.some((value,i)=>value!==effectDeps[pos][i])){effects.push(run);effectDeps[pos]=deps;}},
  useSyncExternalStore:(subscribe,snapshot,server)=>{const pos=index++;if(!subscriptions[pos]){subscriptions[pos]=true;cleanups.push(subscribe(()=>stats.notifications++));}return extra.ssr?server():snapshot();},
  useTransition:()=>{index++;return [false,run=>{transitions.push(Promise.resolve(run()));}];},
  useActionState:(action,initial)=>{const [state,set]=hooks.useState(initial);return [state,async data=>{const result=await action(state,data);set(result);return result;},!!extra.reactPending];},
 };
 const window={addEventListener:(name,listener)=>{if(!listeners.has(name))listeners.set(name,new Set());listeners.get(name).add(listener);},removeEventListener:(name,listener)=>listeners.get(name)?.delete(listener),dispatchEvent:event=>{for(const listener of listeners.get(event.type)??[])listener(event);},location:{reload:()=>{throw Error('Unexpected reload');}}};
 const localStorage={getItem:key=>storage.get(key)??null,setItem:(key,value)=>{stats.writes++;storage.set(key,value);},removeItem:key=>{stats.removes++;storage.delete(key);}};
 class TestFormData extends FormData{constructor(){super();stats.formData++;for(const [key,value]of Object.entries({principal:'100',reason:'سبب اصطناعي',reference:'QA-reference',date:'2026-10-08'}))this.set(key,value);}}
 const globals={window,navigator,localStorage,FormData:TestFormData,crypto:{randomUUID:()=>{stats.uuid++;return '77777777-7777-4777-8777-777777777777';}},queueMicrotask:callback=>effects.push(callback),Event:class{constructor(type){this.type=type;}},CustomEvent:class{constructor(type,{detail}){this.type=type;this.detail=detail;}}};
 const shared=load(read('src/components/offline-submission.tsx'),name=>name==='react'?hooks:jsx,globals);
 const submit=load(read('src/components/submit-button.tsx'),name=>name==='react-dom'?{useFormStatus:()=>({pending:false})}:jsx,globals);
 const leaveRules=load(read('src/app/tenant/[tenantId]/me/leave/form-rules.ts'),()=>{throw Error('Unexpected leave rule import');},globals);
 const options={error:'',startDate:'2026-10-09',endDate:'2026-10-09',types:extra.emptyTypes?[]:[{id:'33333333-3333-4333-8333-333333333333',code:'QA-ANNUAL',name:'سنوية',versions:[]} ]};
 const actionModule={advanceAction:async()=>{stats.actions++;if(extra.deferAction)await new Promise(()=>{});return {resolution:'unknown',error:'synthetic unknown'};},deductionDispositionAction:async()=>{stats.actions++;return {status:'not_committed',error:'synthetic'};},loadLeaveRequestOptionsAction:async()=>options,submitLeaveRequestAction:async()=>{stats.actions++;return {error:'synthetic',attempt:1};}};
 const imports=name=>{
  if(name==='react')return hooks;if(name==='react/jsx-runtime')return jsx;
  if(name==='@/components/offline-submission')return shared;if(name==='@/components/submit-button')return submit;
  if(name==='next/navigation')return {useRouter:()=>({refresh:()=>stats.refresh++,replace:()=>{}})};
  if(name.endsWith('.css'))return {default:{}};
  if(name==='./actions'||name==='../actions'||name==='./deduction-disposition-actions')return actionModule;
  if(name==='./rules')return kind==='deduction'?{money:value=>String(value)}:rules;
  if(name==='../rules')return {uuid:value=>typeof value==='string'&&/^[0-9a-f-]{36}$/.test(value)};
  if(name==='./DeductionRecovery')return {deductionRecoveryEvent:'deduction-recovery'};
  if(name==='../form-rules')return leaveRules;
  if(name==='../operation-key')return {newOperationKey:globals.crypto.randomUUID};
  if(name==='../pending-link')return {PendingLink:'a'};
  throw Error('Unexpected import '+name);
 };
 const files={advance:'src/app/tenant/[tenantId]/payroll/advances/AdvanceForm.tsx',deduction:'src/app/tenant/[tenantId]/payroll/runs/DeductionDisposition.tsx',leave:'src/app/tenant/[tenantId]/me/leave/new/NewLeaveRequestForm.tsx'};
 const mod=load(old?prior(files[kind]):read(files[kind]),imports,globals);
 const props={actor:'11111111-1111-4111-8111-111111111111',tenant:'22222222-2222-4222-8222-222222222222',tenantId:'22222222-2222-4222-8222-222222222222',employer:'33333333-3333-4333-8333-333333333333',period:'44444444-4444-4444-8444-444444444444',advance:'55555555-5555-4555-8555-555555555555',employment:'66666666-6666-4666-8666-666666666666',idempotencyKey:'88888888-8888-4888-8888-888888888888',operation:'save',revision:0,today:'2026-10-08',periods:[{id:'44444444-4444-4444-8444-444444444444',name:'فترة اصطناعية'}],claim:'99999999-9999-4999-8999-999999999999',capacity:100,original:100,canExternal:true,...extra.props};
 function render(){index=0;return (kind==='advance'?mod.AdvanceForm:kind==='deduction'?mod.DeductionDisposition:mod.NewLeaveRequestForm)(props);}
 async function settle(){while(effects.length){const queued=effects.splice(0);for(const run of queued)run();}await Promise.all(transitions.splice(0));}
 function zero(){for(const key of Object.keys(stats))stats[key]=0;}
 async function dispatch(tree){let prevented=false;const event={preventDefault:()=>prevented=true,currentTarget:{}};const target=form(tree);target.props.onSubmit?.(event);if(!prevented&&target.props.action){const data=new FormData();for(const control of nodes(target,n=>n.props.name&&['input','select','textarea'].includes(n.type))){const value=control.props.value??control.props.defaultValue;if(value!==undefined)data.set(control.props.name,String(value));}await target.props.action(data);}await settle();return prevented;}
 return {render,settle,dispatch,zero,stats,navigator,storage,props,mod,hooks,shared,listeners,unmount:()=>cleanups.forEach(run=>run()),emit:name=>window.dispatchEvent({type:name})};
}
async function check(name,run){await run();cases.push({name,status:'pass'});}
(async()=>{
 for(const operation of Object.keys(rules.labels)){
  await check('Advance '+operation+' offline before UUID, lock, journal and action',async()=>{
   const e=engine('advance',false,{props:{operation}});const tree=e.render();e.zero();e.navigator.onLine=false;
   await e.dispatch(tree);assert.equal(e.stats.uuid,0);assert.equal(e.stats.formData,0);assert.equal(e.stats.locks,0);assert.equal(e.stats.writes,0);assert.equal(e.stats.actions,0);assert.equal(e.stats.signalRefresh,1);
   const offline=e.render();assert.equal(form(offline).key,form(tree).key);assert.equal(nodes(offline,n=>n.type==='button'&&n.props.type==='submit')[0].props.disabled,true);assert.equal(nodes(offline,n=>n.type==='fieldset')[0].props.disabled,false);
   e.navigator.onLine=true;e.emit('online');e.render();assert.equal(e.stats.actions,0);assert.equal(e.storage.size,0);
  });
  await check('Advance '+operation+' online unchanged versus accepted baseline',async()=>{
   const actual=engine('advance',false,{props:{operation}}),old=engine('advance',true,{props:{operation}});
   await actual.dispatch(actual.render());await old.dispatch(old.render());
   for(const key of ['uuid','formData','locks','writes','actions','removes','refresh'])assert.equal(actual.stats[key],old.stats[key],key);
   assert.equal(actual.stats.actions,1);assert.deepEqual([...actual.storage.values()],[...old.storage.values()]);
  });
 }
 for(const mode of ['carry','external_settlement','retract'])await check('Deduction '+mode+' blocks before journal/event/action and retains identity',async()=>{
  const e=engine('deduction',false,{props:mode==='retract'?{retraction:'synthetic-original'}:{}});e.render();await e.settle();let tree=e.render();
  if(mode==='external_settlement'){named(tree,'mode').props.onChange({target:{value:mode}});tree=e.render();}
  const attempt=named(tree,'attempt').props.value;e.zero();e.navigator.onLine=false;assert.equal(await e.dispatch(tree),true);
  assert.equal(e.stats.writes,0);assert.equal(e.stats.uuid,0);assert.equal(e.stats.actions,0);assert.equal(e.stats.notifications,0);
  const blocked=e.render();assert.equal(named(blocked,'attempt').props.value,attempt);assert.equal(nodes(blocked,n=>n.type==='fieldset')[0].props.disabled,false);assert.equal(nodes(blocked,n=>n.type==='button')[0].props.disabled,true);
  e.navigator.onLine=true;e.emit('online');e.render();assert.equal(e.stats.actions,0);assert.equal(e.storage.size,0);
 });
 for(const mode of ['carry','external_settlement','retract'])await check('Deduction '+mode+' online unchanged versus accepted baseline',async()=>{
  const results=[];for(const old of [false,true]){const e=engine('deduction',old,{props:mode==='retract'?{retraction:'synthetic-original'}:{}});e.render();await e.settle();let tree=e.render();if(mode==='external_settlement'){named(tree,'mode').props.onChange({target:{value:mode}});tree=e.render();}e.zero();await e.dispatch(tree);results.push(e.stats);}
  for(const key of ['writes','actions','removes','uuid','refresh'])assert.equal(results[0][key],results[1][key],key);assert.equal(results[0].actions,1);
 });
 await check('Actual new leave submit retains controlled values/key and prevents action',async()=>{
  const e=engine('leave');let tree=e.render();named(tree,'startDate').props.onChange({target:{value:'2026-10-09'}});tree=e.render();form(tree).props.onSubmit({preventDefault(){}});await e.settle();tree=e.render();
  const request=nodes(tree,n=>n.type==='form'&&n.props.action)[0];assert.ok(request);const key=named(request,'idempotencyKey').props.value;e.zero();e.navigator.onLine=false;
  let prevented=false;request.props.onSubmit({preventDefault(){prevented=true;}});assert.equal(prevented,true);assert.equal(e.stats.uuid,0);assert.equal(e.stats.actions,0);
  const next=nodes(e.render(),n=>n.type==='form'&&n.props.action)[0];assert.equal(named(next,'idempotencyKey').props.value,key);assert.equal(named(next,'startDate').props.value,'2026-10-09');
  const button=nodes(next,n=>n.type===e.mod.SubmitButton||n.props.label==='إرسال الطلب')[0];assert.equal(button.props.disabled,true);assert.ok(button.props.ariaDescribedBy);
  e.navigator.onLine=true;e.emit('online');e.render();assert.equal(e.stats.actions,0);
 });
 await check('Stable SSR and listener cleanup of actual shared hook',async()=>{
  const e=engine('advance',false,{ssr:true});e.navigator.onLine=false;const tree=e.render();assert.equal(nodes(tree,n=>n.type==='button'&&n.props.type==='submit')[0].props.disabled,false);assert.equal(e.listeners.get('online').size,1);assert.equal(e.listeners.get('offline').size,1);e.unmount();assert.equal(e.listeners.get('online').size,0);assert.equal(e.listeners.get('offline').size,0);
 });
 const unresolvedJournal=JSON.stringify({version:1,actor:'11111111-1111-4111-8111-111111111111',tenant:'22222222-2222-4222-8222-222222222222',employer:'33333333-3333-4333-8333-333333333333',attempt:'77777777-7777-4777-8777-777777777777',intent:{operation:'save',advance:'55555555-5555-4555-8555-555555555555',employment:'66666666-6666-4666-8666-666666666666',expected:0,data:{reason:'سبب اصطناعي'}}});
 for(const [name,journal]of [['unresolved',unresolvedJournal],['corrupt','{}']])await check('Advance '+name+' never invites resend while offline',async()=>{
  const e=engine('advance',false,{journal});e.navigator.onLine=false;const tree=e.render();assert.equal(nodes(tree,n=>n.type===e.shared.OfflineSubmissionNotice).length,0);assert.equal(nodes(tree,n=>n.type==='fieldset')[0].props.disabled,true);assert.equal(nodes(tree,n=>n.type==='button')[0].props['aria-describedby'],undefined);
 });
 await check('Advance in-flight loss preserves recovery priority, not resend hint',async()=>{
  const e=engine('advance',false,{deferAction:true});await e.dispatch(e.render());assert.equal(e.stats.actions,1);e.navigator.onLine=false;const tree=e.render();assert.equal(nodes(tree,n=>n.type===e.shared.OfflineSubmissionNotice).length,0);assert.equal(nodes(tree,n=>n.type==='fieldset')[0].props.disabled,true);assert.equal(e.storage.size,1);
 });
 await check('Deduction in-flight loss never shows resend notice',async()=>{
  const e=engine('deduction',false,{reactPending:true});e.navigator.onLine=false;const tree=e.render();assert.equal(nodes(tree,n=>n.type===e.shared.OfflineSubmissionNotice).length,0);assert.equal(nodes(tree,n=>n.type==='button')[0].props['aria-describedby'],undefined);
 });
 for(const scenario of ['pending','no-types','stale-dates'])await check('Leave '+scenario+' excludes misleading offline resend hint',async()=>{
  const option={emptyTypes:scenario==='no-types',reactPending:false},e=engine('leave',false,option);let tree=e.render();named(tree,'startDate').props.onChange({target:{value:'2026-10-09'}});tree=e.render();form(tree).props.onSubmit({preventDefault(){}});await e.settle();
  if(scenario==='pending')option.reactPending=true;
  if(scenario==='stale-dates'){tree=e.render();named(tree,'startDate').props.onChange({target:{value:'2026-10-10'}});}
  e.navigator.onLine=false;tree=e.render();assert.equal(nodes(tree,n=>n.type===e.shared.OfflineSubmissionNotice).length,0);
 });
 const advance='src/app/tenant/[tenantId]/payroll/advances/AdvanceForm.tsx';
 const recovery=text=>text.slice(text.indexOf('export function AdvanceRecovery'),text.indexOf('type Props='));
 assert.equal(recovery(read(advance)).replace(/\r\n/g,'\n'),recovery(prior(advance)).replace(/\r\n/g,'\n'));
 for(const file of ['src/app/tenant/[tenantId]/me/attendance/MobilePunch.tsx','src/app/tenant/[tenantId]/payroll/runs/DeductionRecovery.tsx','src/app/tenant/[tenantId]/payroll/payments/usePaymentRecovery.ts','src/app/tenant/[tenantId]/leave/balances/PostBalanceForm.tsx'])assert.equal(read(file).replace(/\r\n/g,'\n'),prior(file).replace(/\r\n/g,'\n'));
 const files=['src/components/offline-submission.tsx','src/components/submit-button.tsx',advance,'src/app/tenant/[tenantId]/payroll/runs/DeductionDisposition.tsx','src/app/tenant/[tenantId]/me/leave/new/NewLeaveRequestForm.tsx'];
 const report={baseline,scope:'Actual modules/handlers with controlled React hooks, in-memory storage and synthetic actions; no native DOM/React dispatch or real Auth/SQL/provider acceptance.',advanceOperations:Object.keys(rules.labels),cases,passed:cases.length,preservedRecoveryAndAttendance:true,sourceFiles:files.map(file=>({file,sha256:crypto.createHash('sha256').update(read(file).replace(/\r\n/g,'\n')).digest('hex')}))};
 fs.writeFileSync(path.join(__dirname,'offline-c1-controlled.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({passed:cases.length,operations:report.advanceOperations,scope:report.scope}));
})().catch(error=>{console.error(error.stack);process.exitCode=1;});
