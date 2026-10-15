/* eslint-disable @typescript-eslint/no-require-imports */
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const root=path.resolve(__dirname,'../..');
Object.assign(process.env,{NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:56321',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-key'});
function load(file,deps){const output=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;const loaded={exports:{}};new Function('require','module','exports',output)(name=>Object.hasOwn(deps,name)?deps[name]:require(name),loaded,loaded.exports);return loaded.exports;}
const tenant='a1000000-0000-4000-8000-000000000001',employer='a1000000-0000-4000-8000-000000000002',site='a1000000-0000-4000-8000-000000000003',employee='a1000000-0000-4000-8000-000000000004';
function system(results){const calls=[];const client={rpc:async(name,args)=>{calls.push({name,args});const result=results.shift();if(result instanceof Error)throw result;return result;}};
 const server=load('src/lib/supabase/server.ts',{'@supabase/ssr':{createServerClient:()=>client},'next/headers':{cookies:async()=>({getAll:()=>[],set:()=>{}})}});
 const {createEmployeeAction}=load('src/app/tenant/[tenantId]/people/actions.ts',{'@/lib/supabase/server':server,'next/navigation':{redirect:href=>{throw Object.assign(Error('Redirect'),{href});}}});
 const form=new FormData();for(const [key,value]of Object.entries({tenantId:tenant,code:'E-7KQ2MX',name:'موظف اختبار',employerId:employer,siteId:site,startDate:'2026-10-15',payBasis:'monthly',amount:'1234.50'}))form.set(key,value);
 const initial={code:'E-7KQ2MX',name:'',employerId:employer,siteId:site,departmentId:'',jobId:'',startDate:'2026-10-15',payBasis:'monthly',amount:'',payrollEligible:false,error:'',attempt:0};
 return {createEmployeeAction,form,initial,calls};
}
test('unknown creation followed by duplicate retains the same code and directs review instead of another identity',async()=>{
 const s=system([Error('connection interrupted'),{error:{message:'duplicate key employees_code_per_tenant_idx'},data:null}]);
 const unknown=await s.createEmployeeAction(s.initial,s.form);assert.equal(unknown.uncertainCode,'E-7KQ2MX');assert.equal(unknown.amount,'1234.50');assert.match(unknown.error,/تحقق في دليل/);assert.equal(s.calls.length,1);
 const duplicate=await s.createEmployeeAction(unknown,s.form);assert.equal(duplicate.code,'E-7KQ2MX');assert.equal(duplicate.uncertainCode,duplicate.code);assert.match(duplicate.error,/المحاولة السابقة/);assert.equal(s.calls.length,2);
});
test('malformed or unclassified outcomes remain uncertain; no automatic retry',async()=>{
 for(const response of [{data:{},error:null},{data:null,error:{message:'gateway timeout'}}]){const s=system([response]);const result=await s.createEmployeeAction(s.initial,s.form);assert.equal(result.uncertainCode,result.code);assert.equal(s.calls.length,1);assert.doesNotMatch(result.error,/لم يُحفظ/);}
});
test('ordinary duplicate and changed code after an uncertain attempt do not claim earlier success',async()=>{
 for(const previous of [undefined,{uncertainCode:'E-OLD234'}]){const s=system([{error:{message:'employees_code_per_tenant_idx'}}]);const result=await s.createEmployeeAction({...s.initial,...previous},s.form);assert.match(result.error,/اختر رمزًا آخر/);assert.equal(result.uncertainCode,undefined);}
});
test('confirmed creation opens the returned employee; validation prevents invalid writes',async()=>{
 const s=system([{data:{employee_id:employee},error:null}]);await assert.rejects(s.createEmployeeAction(s.initial,s.form),error=>error.href===`/tenant/${tenant}/people/${employee}?state=created`);assert.equal(s.calls.length,1);assert.equal(s.calls[0].args.p_base_amount,'1234.50');
 s.form.set('siteId','invalid');const invalid=await s.createEmployeeAction(s.initial,s.form);assert.match(invalid.error,/الفرع/);assert.equal(s.calls.length,1);
});
