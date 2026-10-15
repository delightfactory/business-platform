/* eslint-disable @typescript-eslint/no-require-imports */
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const root=path.resolve(__dirname,'../..');
Object.assign(process.env,{NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:56321',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-key'});
function load(file,deps){const compiled=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;const loaded={exports:{}};new Function('require','module','exports',compiled)(name=>Object.hasOwn(deps,name)?deps[name]:require(name),loaded,loaded.exports);return loaded.exports;}
function setup(canManage=true){let uploads=0,saves=0;const client={auth:{getUser:async()=>({data:{user:{id:'qa'}}})},rpc:async name=>{if(name==='save_tenant_branding')saves++;return{data:{can_manage_branding:canManage},error:null};},storage:{from:()=>({upload:async()=>{uploads++;return{error:{message:'Storage unavailable'}};}})}};
 const server=load('src/lib/supabase/server.ts',{'@supabase/ssr':{createServerClient:()=>client},'next/headers':{cookies:async()=>({getAll:()=>[],set:()=>{}})}});
 const {saveTenantBrandingFormAction}=load('src/app/tenant/[tenantId]/branding/actions.ts',{'@/lib/supabase/server':server,'@/lib/supabase/admin':{createSupabaseAdminClient:()=>null},'next/navigation':{redirect:()=>{throw Error('Unexpected redirect');}}});
 const form=new FormData();for(const[key,value]of Object.entries({tenantId:'a1000000-0000-4000-8000-000000000001',displayName:'هوية اختبار',color:'teal',reason:'إعداد هوية الشركة'}))form.set(key,value);
 // Signature is sufficient for the existing server validation boundary; no real image is uploaded.
 form.set('logo',new File([new Uint8Array([137,80,78,71,13,10,26,10])],'qa.png',{type:'image/png'}));
 return{save:()=>saveTenantBrandingFormAction({error:''},form),form,counts:()=>({uploads,saves})};
}
test('storage upload rejection returns an error without saving changed branding',async()=>{const s=setup();assert.match((await s.save()).error,/تعذر رفع الصورة/);assert.deepEqual(s.counts(),{uploads:1,saves:0});assert.equal(s.form.get('displayName'),'هوية اختبار');});
test('lost branding authority does not upload or mutate identity',async()=>{const s=setup(false);assert.match((await s.save()).error,/مسؤول الشركة/);assert.deepEqual(s.counts(),{uploads:0,saves:0});});
test('invalid image content is rejected before storage or branding writes',async()=>{const s=setup();s.form.set('logo',new File(['invalid'],'qa.png',{type:'image/png'}));assert.match((await s.save()).error,/PNG/);assert.deepEqual(s.counts(),{uploads:0,saves:0});});
