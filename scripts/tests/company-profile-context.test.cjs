/* eslint-disable @typescript-eslint/no-require-imports */
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const root=path.resolve(__dirname,'../..');
Object.assign(process.env,{NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:56321',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-key'});
function load(file,deps={}){const code=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2017}}).outputText;const m={exports:{}};new Function('require','module','exports',code)(name=>Object.hasOwn(deps,name)?deps[name]:require(name),m,m.exports);return m.exports;}
const tenant='a1000000-0000-4000-8000-000000000001',employee='a1000000-0000-4000-8000-000000000002',employment='a1000000-0000-4000-8000-000000000003';
const profile=`/tenant/${tenant}/people/${employee}`,task=`/tenant/${tenant}/people?q=E-7KQ2MX`;
const context=load('src/lib/profile-return.ts',{'./return-to':load('src/lib/return-to.ts')});
const navigation={redirect:href=>{throw Object.assign(Error('Redirect'),{href});}};
const scopedRedirect=load('src/lib/profile-action-redirect.ts',{'./profile-return':context,'next/navigation':navigation});
function setup(authenticated=true){const calls=[];const client={auth:{getUser:async()=>({data:{user:authenticated?{id:'qa'}:null}})},rpc:async(name,args)=>{calls.push({name,args});return{data:{state:'scheduled'},error:null};}};
 const server=load('src/lib/supabase/server.ts',{'@supabase/ssr':{createServerClient:()=>client},'next/headers':{cookies:async()=>({getAll:()=>[],set:()=>{}})}});
 const actions=load('src/app/tenant/[tenantId]/people/compensation-actions.ts',{'@/lib/supabase/server':server,'@/lib/profile-action-redirect':scopedRedirect});
 const form=new FormData();for(const[key,value]of Object.entries({tenantId:tenant,employeeId:employee,employmentId:employment,versionId:employment,amount:'5001.25',effectiveDate:'2026-10-16',profileReturn:task}))form.set(key,value);
 return{actions,form,calls};
}
test('context stays within the same company/profile and preserves destination state',()=>{
 const result=new URL(context.profileReturnUrl(tenant,employee,profile+'?compensation=scheduled',task),'https://workspace.invalid');
 assert.equal(result.searchParams.get('compensation'),'scheduled');assert.equal(result.searchParams.get('return'),task);
 for(const bad of ['https://outside.invalid/','//outside.invalid/',`/tenant/${employment}/people`])assert.equal(context.profileReturnUrl(tenant,employee,profile,bad),profile);
 const unrelated=`/tenant/${tenant}/people/${employment}?state=x`;assert.equal(context.profileReturnUrl(tenant,employee,unrelated,task),unrelated);
});
test('actual compensation action preserves task context without adding it to the business RPC',async()=>{
 const s=setup();const previous={tenantId:tenant,employeeId:employee,employmentId:employment,amount:'',effectiveDate:'2026-10-16',error:'',attempt:0};
 await assert.rejects(s.actions.changeCompensationAction(previous,s.form),error=>{const u=new URL(error.href,'https://workspace.invalid');return u.pathname===profile&&u.searchParams.get('compensation')==='scheduled'&&u.searchParams.get('return')===task;});
 assert.deepEqual(s.calls,[{name:'change_people_compensation',args:{p_tenant_id:tenant,p_employment_id:employment,p_effective_date:'2026-10-16',p_amount:'5001.25'}}]);
});
test('expired session retains the task through normal login without attempting a cancellation',async()=>{
 const s=setup(false);await assert.rejects(s.actions.cancelCompensationChangeAction(s.form),error=>{const login=new URL(error.href,'https://workspace.invalid'),next=new URL(login.searchParams.get('next'),'https://workspace.invalid');return login.pathname==='/auth/login'&&next.pathname===profile&&next.searchParams.get('return')===task;});assert.equal(s.calls.length,0);
});

test('policy creation and revision return to the employee while leave-origin editing keeps its request',async()=>{
 for(const revision of [false,true]) {
  const calls=[];
  const actions=load('src/app/tenant/[tenantId]/people/work-policy-actions.ts',{'next/navigation':navigation,'@/lib/profile-action-redirect':scopedRedirect,'@/lib/profile-return':context,'@/lib/supabase/server':{createSupabaseServerClient:async()=>({rpc:async(name,args)=>{calls.push({name,args});return{error:null};}})}});
  const form=new FormData();for(const[key,value]of Object.entries({tenantId:tenant,employeeId:employee,profileReturn:task,code:'day-shift',name:'Day shift',kind:'fixed',shiftStart:'09:00',shiftEnd:'17:00',workDays:'2'}))form.set(key,value);
  if(revision)form.set('templateId',employment);
  await assert.rejects(actions.saveWorkPolicyAction({error:''},form),error=>{const u=new URL(error.href,'https://workspace.invalid');return u.pathname===profile&&u.searchParams.get('tab')==='work'&&u.searchParams.get('policy')==='template-saved'&&u.searchParams.get('return')===task;});
  assert.equal(calls.length,1);assert.equal(calls[0].name,'save_time_work_policy');assert.equal(calls[0].args.p_template_id,revision?employment:null);assert.equal(Object.hasOwn(calls[0].args,'profileReturn'),false);assert.equal(Object.hasOwn(calls[0].args,'employeeId'),false);
  form.set('returnToRequest',employment);
  await assert.rejects(actions.saveWorkPolicyAction({error:''},form),error=>{const u=new URL(error.href,'https://workspace.invalid');return u.pathname.endsWith('/work-policies')&&u.searchParams.get('returnToRequest')===employment;});
 }
});

test('policy activation keeps employee context on failure without repeating the write',async()=>{
 const calls=[];
 const actions=load('src/app/tenant/[tenantId]/people/work-policy-actions.ts',{'next/navigation':navigation,'@/lib/profile-action-redirect':scopedRedirect,'@/lib/profile-return':context,'@/lib/supabase/server':{createSupabaseServerClient:async()=>({rpc:async(name,args)=>{calls.push({name,args});return{error:{message:'forbidden'}};}})}});
 const form=new FormData();for(const[key,value]of Object.entries({tenantId:tenant,employeeId:employee,profileReturn:task,policyId:employment,active:'true'}))form.set(key,value);
 await assert.rejects(actions.setWorkPolicyActiveAction(form),error=>{const u=new URL(error.href,'https://workspace.invalid');return u.pathname.endsWith('/work-policies')&&u.searchParams.get('employeeId')===employee&&u.searchParams.get('profileReturn')===task&&u.searchParams.get('state')==='failed';});
 assert.deepEqual(calls,[{name:'set_time_work_policy_active',args:{p_tenant_id:tenant,p_template_id:employment,p_active:true}}]);
 const bad=new URL(context.workPolicyCatalogUrl(tenant,employee,'https://outside.invalid/'),'https://workspace.invalid');assert.equal(bad.searchParams.has('profileReturn'),false);
 assert.equal(context.workPolicyCatalogUrl(tenant,'../../outside',task),`/tenant/${tenant}/people/work-policies`);
});
