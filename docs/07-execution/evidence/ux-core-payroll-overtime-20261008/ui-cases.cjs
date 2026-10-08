const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const repo=process.cwd();
const ts=require(path.join(repo,'node_modules/typescript')),react=require(path.join(repo,'node_modules/react')),ssr=require(path.join(repo,'node_modules/react-dom/server'));
const root=path.join(repo,'src/app/tenant/[tenantId]/payroll');
let response,throws=false,available=true,calls=[];
const modules=new Map();
function load(file){if(modules.has(file))return modules.get(file);const exports={};const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}}).outputText;
const requireMock=name=>name==='react/jsx-runtime'?require(path.join(repo,'node_modules/react/jsx-runtime')):name==='next/link'?{__esModule:true,default:({children,...props})=>react.createElement('a',props,children)}:name==='@/lib/supabase/server'?{createSupabaseServerClient:async()=>{if(throws)throw Error('synthetic unavailable');return available?{rpc:async(name,args)=>{calls.push({name,args});return response;}}:null;}}:name.endsWith('.css')?{__esModule:true,default:new Proxy({},{get:(_,key)=>'payroll-'+String(key)})}:load(path.resolve(path.dirname(file),name+'.ts'));
vm.runInNewContext(code,{exports,require:requireMock,Intl,Date,URLSearchParams,Set,Object,Number},{filename:file});modules.set(file,exports);return exports;}
const {readOvertimeNotice,readOvertimeCursor}=load(path.join(root,'overtime-notice.ts'));
const {OvertimeNotice}=load(path.join(root,'OvertimeNotice.tsx'));
const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
const period={id:id(30),starts_on:'2030-01-01',ends_on:'2030-02-10'};
const item={work_instance_id:id(100),operational_date:'2030-01-02',employee_code:'SYN-A',unclassified_count:1,unclassified_minutes:30,reconciliation_required:false};
const dto={contract_version:1,period,totals:{instances:1,minutes:30,reconciliation_required:0},items:[item],has_more:false,next_cursor:null};
const results=[];const scenes={};
function check(label,fn){fn();results.push({label,result:'PASS'});}
check('valid exact period accepted',()=>assert(readOvertimeNotice(dto,period)));
for(const [label,edit] of [
 ['wrong period',v=>v.period.id=id(31)],['wrong boundaries',v=>v.period.ends_on='2030-02-11'],['unknown contract',v=>v.contract_version=2],
 ['invalid real date',v=>v.items[0].operational_date='2030-02-30'],['cross period date',v=>v.items[0].operational_date='2029-12-31'],
 ['negative minutes',v=>v.totals.minutes=-1],['unsafe total',v=>v.totals.minutes=Number.MAX_SAFE_INTEGER+1],['impossible reconciliation',v=>v.totals.reconciliation_required=2],
 ['zero candidate count',v=>v.items[0].unclassified_count=0],['missing currentness',v=>delete v.items[0].reconciliation_required],
 ['invalid record identity',v=>v.items[0].work_instance_id='bad'],['long employee code',v=>v.items[0].employee_code='x'.repeat(65)],
 ['duplicate records',v=>{v.items.push(v.items[0]);v.totals.instances=2;}],['unexpected final cursor',v=>v.next_cursor=item],
 ['more without cursor',v=>v.has_more=true],['false empty',v=>{v.totals.instances=0;v.items=[];}],
 ])check('reject '+label,()=>{const v=structuredClone(dto);edit(v);assert.equal(readOvertimeNotice(v,period),null);});
check('empty query cursor absent',()=>assert.equal(readOvertimeCursor({},period),null));
check('partial query cursor invalid',()=>assert.equal(readOvertimeCursor({overtime_date:item.operational_date},period),'invalid'));
check('triple query cursor valid',()=>assert.equal(readOvertimeCursor({overtime_date:item.operational_date,overtime_code:item.employee_code,overtime_instance:item.work_instance_id},period).work_instance_id,item.work_instance_id));
const props={tenantId:id(1),employer:id(20),period,query:{q:'بحث جهة',review_q:'بحث موظف'}};
async function render(data,error=null,query=props.query){response={data,error};calls=[];return ssr.renderToStaticMarkup(await OvertimeNotice({...props,query}));}
(async()=>{
 let html=await render(dto);scenes.nonzero=html;check('source record direct actionable entry',()=>assert(html.includes(`/attendance/${item.work_instance_id}`)));
 check('nonblocking instance wording not days',()=>{assert(html.includes('سجل حضور معتمد'));assert(html.includes('تنبيه غير مانع'));assert(!html.includes('primary-button'));});
 html=await render({...dto,items:[],totals:{instances:0,minutes:0,reconciliation_required:0}});scenes.empty=html;check('empty is approved-source only',()=>{assert(html.includes('لا يوجد إضافي غير مصنف في سجلات الحضور المعتمدة'));assert(!html.includes('/attendance/'));});
 html=await render(null,{code:'42501',message:'payroll_overtime_view_forbidden'});scenes.denied=html;check('denied no protected records or retry loop',()=>{assert(html.includes('صلاحية حضور إضافية'));assert(!html.includes('إعادة تحميل'));assert(!html.includes('payroll_overtime'));});
 html=await render(null,{code:'42501',message:'payroll_overtime_cursor_forbidden'});scenes.failure=html;check('changed code offers generic restart not authorization',()=>{assert(html.includes('إعادة تحميل التنبيه من البداية'));assert(!html.includes('صلاحية حضور إضافية'));assert(!html.includes('overtime_instance='));assert(html.includes('review_q='));});
 html=await render({bad:'shape'});check('malformed read never zero',()=>assert(html.includes('لا يمكن تأكيد العدد')));
 throws=true;html=await render(dto);throws=false;check('thrown client contained',()=>assert(html.includes('تعذر التحقق')));
 available=false;html=await render(dto);available=true;check('missing client contained',()=>assert(html.includes('تعذر التحقق')));
 const pageItems=Array.from({length:20},(_,n)=>({...item,work_instance_id:id(5000+n),employee_code:'S'+(5000+n),operational_date:'2030-01-20',unclassified_minutes:10}));const more={...dto,items:pageItems,totals:{instances:304,minutes:3105,reconciliation_required:1},has_more:true,next_cursor:{operational_date:pageItems[19].operational_date,employee_code:pageItems[19].employee_code,work_instance_id:pageItems[19].work_instance_id}};
 html=await render(more);scenes.more=html;check('full total plus bounded next triple preserves context',()=>{assert(html.includes('overtime_date='));assert(html.includes('overtime_code='));assert(html.includes('overtime_instance='));assert(html.includes('review_q='));assert(html.includes('q='));assert(html.includes('تغيّر سياق'));});
 html=await render(dto,null,{...props.query,overtime_date:'invalid'});check('invalid cursor contains no RPC',()=>{assert.equal(calls.length,0);assert(html.includes('إعادة تحميل'));});
 const query={...props.query,overtime_date:item.operational_date,overtime_code:item.employee_code,overtime_instance:item.work_instance_id};
 html=await render({...dto,items:[]},null,query);check('resolved last page offers first-page recovery',()=>{assert(html.includes('لم تعد هناك سجلات بعد موضع التصفح'));assert(html.includes('بداية القائمة'));assert.equal(calls[0].args.p_after_instance,item.work_instance_id);});
 fs.writeFileSync(path.join(__dirname,'ui-results.json'),JSON.stringify({scope:'Actual helper and async Server Component, controlled SDK; not provider/hydration/full-parent/visual acceptance',cases:results.length,results},null,2)+'\n');
 fs.writeFileSync(path.join(__dirname,'scenes.json'),JSON.stringify(scenes,null,2));console.log(JSON.stringify({cases:results.length,pass:results.every(r=>r.result==='PASS')}));
})().catch(e=>{console.error(e);process.exitCode=1;});
