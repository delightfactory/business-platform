const fs=require('fs'),path=require('path'),cp=require('child_process'),assert=require('assert/strict'),crypto=require('crypto');
const repo=process.cwd(),baseline='ea615008cb7b8721717dc3ba64d77388df48480f';
const read=f=>fs.readFileSync(path.join(repo,f),'utf8').replace(/\r\n/g,'\n'),prior=f=>cp.execFileSync('git',['show',baseline+':'+f],{encoding:'utf8'}).replace(/\r\n/g,'\n');
const hash=s=>crypto.createHash('sha256').update(s).digest('hex'),cases=[];
const candidates=JSON.parse(fs.readFileSync(path.join(__dirname,'offline-c10-candidates.json'),'utf8')).map(c=>({...c,text:read(c.file)}));
(async function suite(){
 async function check(name,run){await run();cases.push({name,status:'pass'});}
 for(const c of candidates.filter(c=>c.file.startsWith('src/app/')))await check(c.file+' exact original authority/actions/fields/conditions retained',()=>{
  let inverted=c.text.replace("import { OfflineForm } from '@/components/offline-form';\nimport { OfflineSubmitButton } from '@/components/offline-submit-button';\n",'').replaceAll('<OfflineForm','<form').replaceAll('</OfflineForm','</form').replaceAll('<OfflineSubmitButton','<SubmitButton');
  if(!inverted.includes("import { SubmitButton } from '@/components/submit-button';")){const orig=prior(c.file),line="import { SubmitButton } from '@/components/submit-button';\n",index=orig.indexOf(line);assert.ok(index>=0);inverted=inverted.slice(0,index)+line+inverted.slice(index);}
  assert.equal(inverted,prior(c.file));assert.equal(hash(c.text),c.candidateHash);
 });
 await check('unchanged shared wrapper/child/guard reuse C9 and C8 evidence',()=>{for(const f of ['src/components/offline-form.tsx','src/components/offline-submit-button.tsx','src/components/submit-button.tsx','src/components/offline-submission.tsx'])assert.equal(read(f),prior(f));});
 const sites=JSON.parse(fs.readFileSync(path.join(__dirname,'offline-c10-sites.json'),'utf8'));
 for(const site of sites)await check(site.file+' '+site.action+' explicit reviewed form/control pair',()=>{assert.ok(site.baselineForm.includes('<SubmitButton'));assert.equal((site.baselineForm.match(/<SubmitButton/g)||[]).length,1);assert.notEqual(site.action,'{signOutAction}');assert.ok(!/method="get"/.test(site.baselineForm));});
 const fingerprints=[];for(const f of cp.execFileSync('git',['ls-files','src','supabase'],{encoding:'utf8'}).trim().split('\n')){if(candidates.some(c=>c.file===f))continue;const bytes=fs.readFileSync(path.join(repo,f)),before=cp.execFileSync('git',['show',baseline+':'+f]);const digest=b=>crypto.createHash('sha256').update(/\.(?:png|jpg|woff2?)$/.test(f)?b:b.toString('utf8').replace(/\r\n/g,'\n')).digest('hex');assert.equal(digest(bytes),digest(before),f);fingerprints.push({file:f,sha256:digest(bytes)});}
 const report={schema:'offline-c10-controlled.v1',baseline,count:cases.length,forms:sites.length,cases,pass:true,sourceCandidates:candidates.map(({file,baselineHash,candidateHash})=>({file,baselineHash,candidateHash})),unchangedSources:fingerprints,limits:['Mechanically inverted exact nine Auth baseline pages: authority/actions/fields/conditional rendering unchanged; not actual role UAT','Shared OfflineForm/child/guard unchanged; reuse C9/C8 source/controlled evidence without repeating checks. Native hydration/no-JS remains separate','Auth provider/session/token/role not exercised; actual native own-form pending/unique ids/full visual/real AuthSQL/financial R0-R8 gates OPEN']};
 fs.writeFileSync(__dirname+'/offline-c10-controlled.json',JSON.stringify(report,null,2)+'\n');console.log({pass:true,cases:cases.length,forms:sites.length,unchangedSources:fingerprints.length});
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
