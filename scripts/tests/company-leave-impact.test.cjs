/* eslint-disable @typescript-eslint/no-require-imports */
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const root=path.resolve(__dirname,'../..');
Object.assign(process.env,{NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:56321',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-key'});
function load(file,deps={}){const code=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2017}}).outputText,m={exports:{}};new Function('require','module','exports',code)(name=>Object.hasOwn(deps,name)?deps[name]:require(name),m,m.exports);return m.exports;}
const input={tenantId:'a7000000-0000-4000-8000-000000000001',typeId:'a7000000-0000-4000-8000-000000000002',start:'2026-10-16',end:'2026-10-16',halfDay:false,part:null};
function response(){return{state:'ready',input:{type:input.typeId,start:input.start,end:input.end,half_day:false,part:null},total_units:'1.00',tracked_units:'1.00',days:[{date:input.start,eligible:true,units:'1.00',is_weekly_rest:false,holiday_name:null,pay_effect:'paid',balance_mode:'tracked',halfday_state:null}],balance:{state:'shown',accounts:[],available_days:'99999999.99',shortfall_days:'0.00',after_approval_days:'99999998.99'}};}
function setup(result,authenticated=true){const calls=[];const client={auth:{getUser:async()=>({data:{user:authenticated?{id:'qa'}:null}})},rpc:async(name,args)=>{calls.push({name,args});return result;}};
 const server=load('src/lib/supabase/server.ts',{'@supabase/ssr':{createServerClient:()=>client},'next/headers':{cookies:async()=>({getAll:()=>[],set:()=>{}})}});
 const actions=load('src/app/tenant/[tenantId]/leave/impact-actions.ts',{'@/lib/supabase/server':server,'@/lib/leave-impact':load('src/lib/leave-impact.ts'),'../me/leave/form-rules':load('src/app/tenant/[tenantId]/me/leave/form-rules.ts')});return{...actions,calls};}
test('own and HR preview use separate authorized RPC scopes and preserve exact decimal display facts',async()=>{
 for(const hr of [false,true]){const data=response(),s=setup({data,error:null}),request=hr?{...input,employeeId:'a7000000-0000-4000-8000-000000000003',employmentId:'a7000000-0000-4000-8000-000000000004'}:input;
  const result=await s.loadLeaveImpact(request);assert.deepEqual(result.impact,data);assert.equal(result.impact.balance.available_days,'99999999.99');assert.equal(s.calls.length,1);assert.equal(s.calls[0].name,hr?'leave_hr_request_preview':'leave_my_request_preview');assert.equal(Object.hasOwn(s.calls[0].args,'p_employee'),hr);
 }
});
test('mismatched input echoes and float amounts cannot become a current successful preview',async()=>{
 for(const mutate of [data=>{data.input.start='2026-10-17';},data=>{data.balance.available_days=1;}]){const data=response();mutate(data);const s=setup({data,error:null});assert.equal((await s.loadLeaveImpact(input)).impact.state,'unavailable');assert.equal(s.calls.length,1);}
});
test('permission and session failures stay unavailable without a guessed zero or automatic retry',async()=>{
 const forbidden=setup({data:null,error:{code:'42501'}}),result=await forbidden.loadLeaveImpact(input);assert.deepEqual(result.impact,{state:'unavailable',reason:'forbidden'});assert.equal(forbidden.calls.length,1);
 const expired=setup(null,false);assert.equal((await expired.loadLeaveImpact(input)).impact.reason,'session');assert.equal(expired.calls.length,0);
});
