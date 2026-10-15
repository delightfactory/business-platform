/* eslint-disable @typescript-eslint/no-require-imports */
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const root=path.resolve(__dirname,'../..');
function load(file){const output=ts.transpileModule(fs.readFileSync(path.join(root,file),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2017}}).outputText,m={exports:{}};new Function('require','module','exports',output)(name=>name.startsWith('@/')?load('src/'+name.slice(2)+'.ts'):require(name),m,m.exports);return m.exports;}
const {currentPeriodId}=load('src/app/tenant/[tenantId]/payroll/rules.ts');
const {payrollDestination}=load('src/components/shell/navigation-model.ts');
const {validatePayrollPeriod}=load('src/app/tenant/[tenantId]/payroll/period-scope.ts');

test('current payroll period follows saved timezone boundaries, not latest future period or host date',()=>{
 const periods=[{id:'future',starts_on:'2026-11-01',ends_on:'2026-11-30'},{id:'current',starts_on:'2026-10-01',ends_on:'2026-10-31'}];
 const saved=periods.map(p=>({...p,timezone:'Africa/Cairo'}));
 assert.equal(currentPeriodId(periods,saved,new Date('2026-10-15T12:00:00Z')),'current');
 assert.equal(currentPeriodId(periods,saved,new Date('2026-10-31T22:30:00Z')),'future');
 assert.equal(currentPeriodId(periods,saved,new Date('2026-12-15T12:00:00Z')),undefined);
 assert.equal(currentPeriodId(periods,[],new Date('2026-10-15T12:00:00Z')),undefined);
 assert.equal(currentPeriodId(periods,saved.map(p=>({...p,timezone:'invalid'})),new Date()),undefined);
});

test('payroll navigation carries explicit context only to same workspace and never replaces destination scope',()=>{
 const employer='b8000000-0000-4000-8000-000000000001',period='b8000000-0000-4000-8000-000000000002',other='b8000000-0000-4000-8000-000000000003',base='/tenant/company/payroll';
 for(const suffix of ['', '/setup','/inputs','/runs'])assert.equal(payrollDestination(base,base+suffix,employer,period),`${base}${suffix}?employer=${employer}&period=${period}`);
 assert.equal(payrollDestination(base,base+'/runs?period='+other,employer,period),`${base}/runs?period=${other}&employer=${employer}`);
 assert.equal(payrollDestination(base,base+'/runs?employer='+other,employer,period),base+'/runs?employer='+other);
 assert.equal(payrollDestination(base,'/tenant/another/payroll',employer,period),'/tenant/another/payroll');
 assert.equal(payrollDestination(base,base+'/reports?report=sheet',employer,period),base+'/reports?report=sheet&employer='+employer);
});

test('period validation retains paged history, checks the employer-scoped list and preserves input-only access',async()=>{
 for(const mode of ['run','input']){
  const calls=[],period={id:'old',starts_on:'2023-01-01',ends_on:'2023-01-31'};
  const client={rpc:async(name,args)=>{calls.push({name,args});return {data:name.endsWith('_workspace')?{period}:[period],error:null};}};
  assert.equal(await validatePayrollPeriod(client,'tenant','employer','old',[],mode),'valid');
  assert.equal(calls[0].name,`payroll_${mode}_workspace`);assert.equal(calls[1].name,`payroll_${mode}_periods`);assert.equal(calls[1].args.p_before,'2023-02-01');assert.equal(calls[0].args.p_employer,'employer');
 }
 const forbidden={rpc:async()=>({data:null,error:{code:'42501'}})};
 assert.equal(await validatePayrollPeriod(forbidden,'tenant','employer','foreign',[]),'invalid');
 const unavailable={rpc:async()=>({data:null,error:{code:'08000'}})};
 assert.equal(await validatePayrollPeriod(unavailable,'tenant','employer','old',[]),'unavailable');
});
