import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync,execFileSync} from 'node:child_process';
const repo=path.resolve('implementation'),container='supabase_db_business-platform',db='business_platform_cube4_adam_final_qa';
const out='final-cube4-qualification';fs.mkdirSync(out,{recursive:true});
const result=path.join(out,'result.json');if(fs.existsSync(result))throw Error('Frozen qualification exists');
const git=(...args)=>execFileSync('git',['-c',`safe.directory=${repo.replaceAll('\\','/')}`,...args],{cwd:repo,encoding:'utf8'}).trim();
if(git('status','--porcelain','--untracked-files=no'))throw Error('Tracked source must be clean');
const hash=s=>crypto.createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
const e={status:'RUNNING',SHA:git('rev-parse','HEAD'),tree:git('rev-parse','HEAD^{tree}'),database:db,container,startedUTC:new Date().toISOString(),migrations:[],tests:[],officialLegalAcceptance:false,fullCubeAcceptance:false,fixtureBoundary:'Only external issuer suppliers are scoped NONLEGAL test doubles. Actual producer, authorization, math, finalization, consumption, correction and mandatory audit remain unchanged.',reusedEvidence:['cube-4-adam-debt-ui-evidence.json','cube-4-adam-grouped-payslip-evidence.json','cube-4-adam-fixed30-evidence.json'],remaining:'Official dated tax/insurance packages and representative expected results/coverage evidence remain unavailable; no official release/retirement/distribution qualification is claimed.'};
const save=()=>fs.writeFileSync(result,JSON.stringify(e,null,2)+'\n');save();
function docker(name,args,input){const r=spawnSync('docker',args,{input:input?Buffer.from(input.replaceAll('\r\n','\n'),'utf8'):undefined,encoding:'utf8',maxBuffer:32e6,timeout:120000});const log=(r.stdout??'')+(r.stderr??'');fs.writeFileSync(path.join(out,name+'.log'),log);if(r.status!==0)throw Error(name+':'+log.slice(-1800));return log;}
try{
 if(docker('name-check',['exec',container,'psql','-X','-U','postgres','-d','postgres','-At','-c',`SELECT datname FROM pg_database WHERE datname='${db}'`]).trim())throw Error('Final isolated QA already exists; inspect instead');
 docker('create',['exec',container,'createdb','-U','postgres','--template=template0',db]);
 let engine=fs.readFileSync('engine-isolated-schema.sql','utf8').replaceAll('\r\n','\n');e.engineSchemaSHA256=hash(engine);e.engineSchemaOnly=true;e.noDataCopied=true;
 const exclusions=['people_capture_employee_account_provision','tenant_branding_object_insert','tenant_branding_object_read'];
 for(const name of exclusions){const sections=engine.split(/(?=--\n-- Name: )/),matches=sections.filter(s=>s.startsWith('--\n-- Name: ')&&s.split('\n')[1].includes(name));if(matches.length!==1)throw Error('Engine exclusion identity '+name);engine=sections.filter(s=>!matches.includes(s)).join('');}e.engineApplicationExclusions=exclusions;
 docker('engine',['exec','-i',container,'psql','-X','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-1'],engine);
 docker('extensions',['exec','-i',container,'psql','-X','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-1'],'CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions; CREATE EXTENSION pgtap WITH SCHEMA public; GRANT USAGE ON SCHEMA auth TO anon,authenticated,service_role;');
 for(const file of fs.readdirSync(path.join(repo,'supabase/migrations')).filter(x=>x.endsWith('.sql')).sort()){
  const sql=fs.readFileSync(path.join(repo,'supabase/migrations',file),'utf8');docker(file.slice(0,-4),['exec','-i',container,'psql','-X','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-1'],sql);e.migrations.push({file,SHA256:hash(sql)});save();if(e.migrations.length%30===0)console.log('Replayed migrations '+e.migrations.length);
 }
 const tests=['cube4_qualified_linked_correction_consumption.test.sql','cube4_qualified_mixed_correction_consumption.test.sql','cube4_qualified_leave_correction_closure.test.sql','cube4_qualified_time_correction_closure.test.sql','cube4_qualified_carry_after_unpaid_replacement.test.sql','cube4_qualified_ending_report_handoff.test.sql','cube4_debt_disposition_authority.test.sql','cube4_recurring_debt_authority_catalog.test.sql'];
 for(const target of [db,'business_platform_cube4_adam_positive_qa'])for(const test of tests){
  const source=fs.readFileSync(path.join(repo,'supabase/tests',test),'utf8');
  const body=source.replaceAll('business_platform_cube4_adam_positive_qa',target).replaceAll('business_platform_cube4_adam_closure_qa',target).replaceAll('business_platform_cube4_upgrade_qa',target).replaceAll('business_platform_cube4_fresh_qa',target);
  const log=docker(target+'-'+test.slice(0,-4),['exec','-i',container,'psql','-X','-U','postgres','-d',target,'-v','ON_ERROR_STOP=1'],body);
  const plan=log.match(/1\.\.(\d+)/);if(!plan||/not ok \d+|Looks like you failed/i.test(log))throw Error('Qualification test failed '+test+' on '+target);
  const row={database:target,test,SHA256:hash(source),executedSHA256:hash(body),assertions:Number(plan[1]),status:'PASS',rollback:true};e.tests.push(row);save();console.log(JSON.stringify(row));
 }
 e.emptyFixtureCheck=docker('no-retained-fixtures',['exec',container,'psql','-X','-U','postgres','-d',db,'-At','-c','SELECT current_database(),version(); SELECT count(*) FROM auth.users; SELECT count(*) FROM payroll.final_contexts;']);
 if(git('rev-parse','HEAD')!==e.SHA||git('rev-parse','HEAD^{tree}')!==e.tree||git('status','--porcelain','--untracked-files=no'))throw Error('Source changed during qualification');
 e.status='BOUNDED_FRESH_AND_UPGRADE_QUALIFICATION_PASS';e.totalAssertions=e.tests.reduce((n,x)=>n+x.assertions,0);e.completedUTC=new Date().toISOString();save();console.log(JSON.stringify({status:e.status,SHA:e.SHA,tree:e.tree,migrations:e.migrations.length,assertions:e.totalAssertions,officialLegalAcceptance:false,fullCubeAcceptance:false}));
}catch(error){e.status='FAIL_STOPPED';e.error=error.message;e.completedUTC=new Date().toISOString();save();throw error;}
