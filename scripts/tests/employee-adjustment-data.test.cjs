/* eslint-disable @typescript-eslint/no-require-imports */
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const root=path.resolve(__dirname,'../..');
function load(file,deps={}){
 const compiled=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const loaded={exports:{}};
 new Function('require','module','exports',compiled)(name=>Object.hasOwn(deps,name)?deps[name]:require(name),loaded,loaded.exports);
 return loaded.exports;
}
const base='src/app/tenant/[tenantId]/payroll/';
const rules=load(base+'rules.ts',{'@/lib/display-locale':load('src/lib/display-locale.ts')});
test('approval and cancellation preserve absent legacy fields and numeric saved amounts for CAS',async()=>{
 const component='f1000000-0000-4000-8000-000000000001';
 for(const saved of [
  {component_id:component,amount:'500',reason:'legacy earning'},
  {component_id:component,amount:'100',reason:'legacy deduction',reference:'old decision'},
  {component_id:component,amount:100,reason:'reviewed deduction',reference:'decision',deduction_category:'employer_penalty'},
 ])for(const operation of ['approve','cancel']){
  let sent;
  const client={auth:{getUser:async()=>({data:{user:{id:'actor'}}})},rpc:async(name,args)=>{sent=args.p_data;return{data:{id:component,revision:2,status:operation==='approve'?'approved':'cancelled'},error:null};}};
  const {inputAction}=load(base+'inputs/actions.ts',{
   '@/lib/supabase/server':{createSupabaseServerClient:async()=>client},'next/cache':{revalidatePath:()=>{}},'../rules':rules,
   './rules':load(base+'inputs/rules.ts'),'./manual-source':load(base+'inputs/manual-source.ts'),'./saved-adjustment':load(base+'inputs/saved-adjustment.ts'),
  });
  const form=new FormData();
  for(const [key,value]of Object.entries({tenant:component,employer:component,employment:component,period:component,kind:'adjustment',operation,from:'2026-10-01',until:'2026-11-01',component_id:component,amount:String(saved.amount),reason:saved.reason,reference:saved.reference??'',deduction_category:saved.deduction_category??'',consent_reference:''}))form.set(key,value);
  const response=await inputAction({error:'',saved:false,head:component,revision:1,attempt:'',signature:'',status:'draft',adjustment_data:saved},form);
  assert.equal(response.saved,true);assert.deepEqual(sent,saved);
 }
});
