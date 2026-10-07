/* eslint-disable @typescript-eslint/no-require-imports -- CommonJS characterization CLI loads transpiled source and isolated runtime dependencies. */
// Bounded source characterization: real auth source, stubbed provider/Next boundary.
// No application server, real credentials, project environment files or network.
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const ts=require('typescript');
const {execFileSync}=require('node:child_process');
const {NextRequest,NextResponse}=require('next/server');
const root=process.argv[2];
const artifactDir=process.argv[3];
if(!root||!artifactDir)throw Error('Pass explicit repository root and existing artifact directory');
const report={kind:'source-characterization-not-runtime-UAT',sourceHead:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),cases:[]};
function load(file,imports={},env={}){
 const source=fs.readFileSync(path.join(root,file),'utf8');
 const code=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const context={exports:{},URL,Response,FormData,process:{env},require:name=>{if(Object.hasOwn(imports,name))return imports[name];throw Error(`Unexpected import: ${name}`);}};
 vm.runInNewContext(code,context,{filename:file,timeout:2000});return context.exports;
}
async function test(id,run){try{await run();report.cases.push({id,status:'pass'});}catch(error){report.cases.push({id,status:'fail',error:String(error.message)});}}
const safe=load('src/app/auth/safe-next.ts').safeAuthNext;
const tenant='11111111-1111-4111-8111-111111111111';
const accepted=[`/tenant/${tenant}`,`/tenant/${tenant}/users/invite`,`/tenant/${tenant}/entities-sites/${tenant}/sites/new`,'/operator','/operator/onboarding',`/auth/invitations/accept?id=${tenant}&issuance=1`,`/auth/membership-invitations/accept?id=${tenant}&issuance=123456789`,`/tenant/${tenant}/payroll/runs?employer=${tenant}&period=${tenant}`];
const rejected=['https://external.invalid','//external.invalid','/tenant/select',`/tenant/${tenant}/attendance`,`/tenant/${tenant}/leave`,`/tenant/${tenant}/people`,`/tenant/${tenant}/me`,'/operator/statutory',`/auth/invitations/accept?id=${tenant}&issuance=0`,`/auth/invitations/accept?id=${tenant}&issuance=1000000000`,`/auth/invitations/accept?issuance=1&id=${tenant}`,`/tenant/${tenant}/payroll?x=%0a`,`/tenant/${tenant}/payroll?x=%0D`,`/tenant/${tenant}/payroll?x=%00`,`/tenant/${tenant}/payroll#fragment`,`/tenant/${tenant}/payroll?x=has space`,`/tenant/${tenant}/payroll?x=\\`,`/tenant/${tenant}/payroll?x=${'a'.repeat(8200)}`];
function redirect(destination){throw Object.assign(new Error('redirect'),{destination});}
function form(values){const result=new FormData();for(const [key,value] of Object.entries(values))result.set(key,value);return result;}
function client(overrides={}){return {auth:{signInWithPassword:async()=>({error:null}),resetPasswordForEmail:async()=>({error:null}),getUser:async()=>({data:{user:{id:'synthetic-user'}}}),updateUser:async()=>({error:null}),signOut:async()=>({error:null}),...overrides.auth},rpc:overrides.rpc??(async()=>({data:[{tenant_id:tenant}],error:null}))};}
function actions(supabase=client(),env={},factoryError=false){
 const config={NEXT_PUBLIC_SUPABASE_URL:'https://provider.example.invalid',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-test-only',...env};
 if(!supabase)config.NEXT_PUBLIC_SUPABASE_URL='';
 const server=load('src/lib/supabase/server.ts',{'next/headers':{cookies:async()=>({getAll:()=>[],set(){}})},'@supabase/ssr':{createServerClient:()=>{if(factoryError)throw Error('synthetic SDK construction failure');return supabase;}}},config);
 return load('src/app/auth/actions.ts',{'next/navigation':{redirect},'@/lib/supabase/server':server,'./safe-next':{safeAuthNext:safe}},config);
}
async function destination(run){try{await run();throw Error('Missing redirect');}catch(error){if(!error.destination)throw error;return error.destination;}}
function callback(env,exchange={error:null},cookies=false){let calls=0;const mod=load('src/app/auth/callback/route.ts',{'next/server':{NextResponse},'@supabase/ssr':{createServerClient:(_url,_key,options)=>({auth:{exchangeCodeForSession:async()=>{calls++;if(cookies)options.cookies.setAll([{name:'synthetic-session',value:'synthetic-test-only',options:{httpOnly:true}}],{'X-Synthetic-SSR':'present'});if(exchange.throw)throw Error('synthetic exchange throw');return exchange;}}})}},env);return {GET:mod.GET,calls:()=>calls};}
const validEnv={NEXT_PUBLIC_APP_URL:'https://platform.example.invalid',NEXT_PUBLIC_SUPABASE_URL:'https://provider.example.invalid',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-test-only'};
function request(code){return new NextRequest(`https://request.example.invalid/auth/callback${code?'?code=synthetic-code':''}`);}
(async()=>{
 for(let i=0;i<accepted.length;i++)await test(`NEXT-ALLOW-${i+1}`,()=>assert.equal(safe(accepted[i]),accepted[i]));
 for(let i=0;i<rejected.length;i++)await test(`NEXT-REJECT-${i+1}`,()=>assert.equal(safe(rejected[i]),''));
 const login={email:'synthetic@example.invalid',password:'synthetic-test-only'};
 await test('LOGIN-MISSING',async()=>assert.equal(await destination(()=>actions().signInAction(form({email:' '}))),'/auth/login?state=invalid'));
 await test('LOGIN-SETUP-SAFE-NEXT',async()=>assert.equal(await destination(()=>actions(null).signInAction(form({...login,next:'/operator'}))),'/auth/login?state=setup&next=%2Foperator'));
 await test('LOGIN-PROVIDER-INVALID',async()=>assert.equal(await destination(()=>actions(client({auth:{signInWithPassword:async()=>({error:{message:'synthetic'}})}})).signInAction(form(login))),'/auth/login?state=invalid'));
 await test('LOGIN-SAFE-NEXT',async()=>assert.equal(await destination(()=>actions().signInAction(form({...login,next:'/operator'}))),'/operator'));
 await test('LOGIN-ONE-MEMBERSHIP',async()=>assert.equal(await destination(()=>actions().signInAction(form(login))),`/tenant/${tenant}`));
 await test('LOGIN-MANY',async()=>assert.equal(await destination(()=>actions(client({rpc:async()=>({data:[{},{}]})})).signInAction(form(login))),'/tenant/select'));
 for(const [id,data] of [['EMPTY',[]],['BAD-ID',[{tenant_id:'bad'}]],['NULL',null],['NONARRAY',{}]])await test(`LOGIN-FALLBACK-${id}`,async()=>assert.equal(await destination(()=>actions(client({rpc:async()=>({data,error:{code:'synthetic'}})})).signInAction(form(login))),'/operator'));
 await test('LOGIN-THROW-UNHANDLED',async()=>assert.rejects(()=>actions(client({auth:{signInWithPassword:async()=>{throw Error('synthetic provider throw');}}})).signInAction(form(login)),/synthetic provider throw/));
 for(const [id,provider,env] of [['NO-CLIENT',null,{}],['NO-ORIGIN',client(),{}],['INVALID-ORIGIN',client(),{NEXT_PUBLIC_APP_URL:'invalid'}],['NONHTTPS',client(),{NEXT_PUBLIC_APP_URL:'http://external.invalid'}],['RETURNED-ERROR',client({auth:{resetPasswordForEmail:async()=>({error:{message:'synthetic'}})}}),validEnv],['THROWN-ERROR',client({auth:{resetPasswordForEmail:async()=>{throw Error('synthetic reset throw');}}}),validEnv]])await test(`RESET-UNIFORM-${id}`,async()=>assert.equal(await destination(()=>actions(provider,env).requestPasswordResetAction(form({email:login.email}))),'/auth/forgot-password?state=sent'));
 await test('RESET-SAFE-TARGET',async()=>{let target;await destination(()=>actions(client({auth:{resetPasswordForEmail:async(_email,options)=>{target=options.redirectTo;return {error:null};}}}),validEnv).requestPasswordResetAction(form({email:login.email})));assert.equal(target,'https://platform.example.invalid/auth/callback');});
 const update={password:'synthetic-test-only',confirmation:'synthetic-test-only'};
 await test('UPDATE-SHORT',async()=>assert.equal(await destination(()=>actions().updatePasswordAction(form({password:'short',confirmation:'short'}))),'/auth/password/update?state=invalid'));
 await test('UPDATE-MISMATCH',async()=>assert.equal(await destination(()=>actions().updatePasswordAction(form({...update,confirmation:'different-synthetic'}))),'/auth/password/update?state=invalid'));
 await test('UPDATE-NO-CLIENT',async()=>assert.equal(await destination(()=>actions(null).updatePasswordAction(form(update))),'/auth/login?state=setup'));
 await test('UPDATE-NO-USER',async()=>assert.equal(await destination(()=>actions(client({auth:{getUser:async()=>({data:{user:null}})}})).updatePasswordAction(form(update))),'/auth/forgot-password?state=expired'));
 await test('UPDATE-PROVIDER-FAILED',async()=>assert.equal(await destination(()=>actions(client({auth:{updateUser:async()=>({error:{message:'synthetic'}})}})).updatePasswordAction(form(update))),'/auth/password/update?state=failed'));
 await test('UPDATE-SUCCESS-LOCAL-LOGOUT',async()=>{let scope;assert.equal(await destination(()=>actions(client({auth:{signOut:async options=>{scope=options.scope;return {error:null};}}})).updatePasswordAction(form(update))),'/auth/login?state=updated');assert.equal(scope,'local');});
 await test('BASELINE-UPDATE-LOGOUT-ERROR-IGNORED',async()=>assert.equal(await destination(()=>actions(client({auth:{signOut:async()=>({error:{message:'synthetic'}})}})).updatePasswordAction(form(update))),'/auth/login?state=updated'));
 await test('LOGOUT-NO-CLIENT',async()=>assert.equal(await destination(()=>actions(null).signOutAction()),'/auth/login?state=signed-out'));
 await test('BASELINE-LOGOUT-ERROR-IGNORED',async()=>assert.equal(await destination(()=>actions(client({auth:{signOut:async()=>({error:{message:'synthetic'}})}})).signOutAction()),'/auth/login?state=signed-out'));
 for(const [id,env] of [['MISSING',{}],['INVALID',{...validEnv,NEXT_PUBLIC_APP_URL:'invalid'}],['INSECURE',{...validEnv,NEXT_PUBLIC_APP_URL:'http://external.invalid'}]])await test(`CALLBACK-503-${id}`,async()=>{const cb=callback(env);const result=await cb.GET(request(true));assert.equal(result.status,503);assert.match(result.headers.get('Cache-Control'),/no-store/);assert.equal(cb.calls(),0);});
 await test('BASELINE-CALLBACK-NO-CODE',async()=>{const cb=callback(validEnv);const result=await cb.GET(request(false));assert.equal(result.headers.get('Location'),'https://platform.example.invalid/auth/forgot-password?state=expired');assert.equal(cb.calls(),0);assert.equal(result.headers.get('Cache-Control'),null);});
 await test('BASELINE-CALLBACK-EXCHANGE-ERROR',async()=>{const cb=callback(validEnv,{error:{message:'synthetic'}},true);const result=await cb.GET(request(true));assert.match(result.headers.get('Location'),/state=expired$/);assert.equal(result.cookies.getAll().length,0);assert.equal(result.headers.get('Cache-Control'),null);});
 await test('CALLBACK-SUCCESS-HEADERS-COOKIES',async()=>{const cb=callback(validEnv,{error:null},true);const result=await cb.GET(request(true));assert.equal(result.headers.get('Location'),'https://platform.example.invalid/auth/password/update');assert.match(result.headers.get('Cache-Control'),/no-store/);assert.equal(result.cookies.getAll().length,1);assert.equal(result.headers.get('X-Synthetic-SSR'),'present');});
 await test('CALLBACK-THROW-UNHANDLED',async()=>assert.rejects(()=>callback(validEnv,{throw:true}).GET(request(true)),/synthetic exchange throw/));
 report.passed=report.cases.filter(item=>item.status==='pass').length;report.failed=report.cases.length-report.passed;
 console.log(JSON.stringify({kind:report.kind,cases:report.cases.length,passed:report.passed,failed:report.failed}));
 fs.writeFileSync(path.join(artifactDir,'auth-core-source-checks.json'),JSON.stringify(report,null,2)+'\n');
 if(report.failed){console.log(JSON.stringify(report.cases.filter(item=>item.status==='fail')));process.exitCode=1;}
})();
