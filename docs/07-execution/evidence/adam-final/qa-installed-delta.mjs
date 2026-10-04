import fs from 'node:fs';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
const test=process.argv[2], phase=process.argv[3];
if(!/^cube4_[a-z0-9_]+\.test\.sql$/.test(test??'')||! /^[a-z0-9-]+$/.test(phase??''))throw Error('Explicit test/phase required');
const target='business_platform_cube4_adam_positive_qa';
const source=fs.readFileSync('implementation/supabase/tests/'+test,'utf8').replaceAll('\r\n','\n');
let body=source.replaceAll('business_platform_cube4_adam_closure_qa',target).replaceAll('business_platform_cube4_upgrade_qa',target).replaceAll('business_platform_cube4_fresh_qa',target);
const migration=process.argv[4];
if(migration){if(migration!=='20261003058000_cube4_linked_correction_consumption_completion.sql')throw Error('Only current uninstalled delta permitted');body=body.replace('BEGIN;',()=> 'BEGIN;\n'+fs.readFileSync('implementation/supabase/migrations/'+migration,'utf8')+'\n');}
if(!body.includes('ROLLBACK;'))throw Error('Rollback fixture required');
const name='qa-installed-'+phase;if(fs.existsSync(name+'.json'))throw Error('Frozen evidence exists');
const r=spawnSync('docker',['exec','-i','supabase_db_business-platform','psql','-X','-U','postgres','-d',target,'-v','ON_ERROR_STOP=1'],{input:body,encoding:'utf8',maxBuffer:24e6});
const log=(r.stdout??'')+(r.stderr??'');fs.writeFileSync(name+'.log',log);
const plan=log.match(/1\.\.(\d+)/),pass=r.status===0&&!!plan&&!/not ok \d+|Looks like you failed/i.test(log);
const e={test,migration:migration??null,database:target,baseline:185,sourceSHA:'99250d891623c8e9acb8a407beab71d81ec31fe0',status:pass?'BOUNDED_INSTALLED_DELTA_PASS':'FAIL_ROLLED_BACK',testSHA256:crypto.createHash('sha256').update(source).digest('hex'),executedSHA256:crypto.createHash('sha256').update(body).digest('hex'),fixtureRolledBack:true,assertions:plan?Number(plan[1]):null,exitCode:r.status,atUTC:new Date().toISOString(),officialLegalAcceptance:false};
fs.writeFileSync(name+'.json',JSON.stringify(e,null,2)+'\n');console.log(JSON.stringify(e));if(!pass)console.log(log.slice(-8000));process.exit(pass?0:1);
