/* Evidence runner: only the exact, network-isolated synthetic QA container. */
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const name='codex-ux-payroll-overtime-20261008';
const inspected=cp.spawnSync('docker',['inspect',name],{encoding:'utf8',windowsHide:true});
if(inspected.status!==0)throw Error('Recorded QA container unavailable; do not use another database');
const container=JSON.parse(inspected.stdout)[0];
if(container.Id!=='04b7c00e511f2e5d0f5a913af5b5bd1ea3b14dc0eae7df05295ac419e3c49ce7'||container.Config.Labels['codex.task']!=='ux-core-payroll-overtime-20261008'||container.HostConfig.NetworkMode!=='none'||Object.keys(container.NetworkSettings.Ports).length||!container.State.Running)throw Error('Recorded isolated QA boundary not live; stop');
const choice=process.argv[2];
if(!['full','delta'].includes(choice))throw Error('Use full or delta only');
const sql=fs.readFileSync(path.join(__dirname,choice==='full'?'read-contract.test.sql':'read-delta.test.sql'),'utf8');
const result=cp.spawnSync('docker',['exec','-i',name,'psql','-U','postgres','-d','postgres','-X','-q','-A','-t','-v','ON_ERROR_STOP=1'],{input:sql,encoding:'utf8',windowsHide:true,timeout:120000});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exitCode=result.status??1;
