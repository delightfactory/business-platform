const fs=require('fs'),cp=require('child_process'),crypto=require('crypto'),assert=require('assert/strict'),path=require('path');
const read=file=>fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n');
const old=file=>cp.execFileSync('git',['show','2c9905a:'+file],{encoding:'utf8'}).replace(/\r\n/g,'\n');
const hash=text=>crypto.createHash('sha256').update(text).digest('hex');
const base='src/app/tenant/[tenantId]/leave/settings/';
const calendar=base+'[employerId]/calendars/[calendarId]/page.tsx',type=base+'[employerId]/types/[typeId]/page.tsx',component=base+'SettingsTask.tsx';
const originalRevision='<details className="task-disclosure">\n      <summary className="secondary-button">إصدار جديد من تاريخ لاحق</summary>';
function restoreReadBranch(text){
 const start=text.indexOf('  if (configResult.error) {');
 const boundary=text.includes('  const calendar =')?'  const calendar =':'  const leaveType =';
 const end=text.indexOf(boundary,start);assert.ok(start>=0&&end>start);
 const delta=text.slice(start,end);assert.match(delta,/configResult.error.code === '42501'/);assert.match(delta,/!denied/);assert.match(delta,/if \(!configuration\)/);
 return (text.slice(0,start)+'  const configuration = configResult.error ? null : readConfiguration(configResult.data);\n'+text.slice(end)).replace('  if (!calendar) {','  if (!configuration || !calendar) {').replace('  if (!leaveType) {','  if (!configuration || !leaveType) {').replace('      true);\n  }\n\n  const state',"      !configResult.error || configResult.error.code !== '42501');\n  }\n\n  const state");
}
const inverse=file=>restoreReadBranch(read(file)).replace("import { SettingsTask } from '../../../SettingsTask';\n",'').replace('<SettingsTask label="إصدار جديد من تاريخ لاحق">',originalRevision).replace('<SettingsTask className={targetActive ? \'task-disclosure\' : \'task-disclosure danger-disclosure\'}\n      label={targetActive ? \'تفعيل النوع\' : \'إيقاف استخدام النوع\'}>','<details className={targetActive ? \'task-disclosure\' : \'task-disclosure danger-disclosure\'}>\n      <summary className="secondary-button">{targetActive ? \'تفعيل النوع\' : \'إيقاف استخدام النوع\'}</summary>').replaceAll('</SettingsTask>','</details>');
for(const file of [calendar,type])assert.equal(inverse(file),old(file));
assert.equal(read(base+'StatusCard.tsx').replace('className="primary-button" href={retryPath}','className="secondary-button" href={retryPath}'),old(base+'StatusCard.tsx'));
const unchangedForms=['[employerId]/calendars/[calendarId]/ReviseCalendarForm.tsx','[employerId]/types/[typeId]/ReviseTypeForm.tsx','[employerId]/types/[typeId]/TypeActivationForm.tsx'];
for(const file of unchangedForms){assert.equal(read(base+file),old(base+file));assert.match(read(base+file),/aria-busy=\{pending\}/);}
const policy=read('src/app/tenant/[tenantId]/people/work-policies/PolicyTask.tsx'),source=read(component);
for(const [start,end] of [['onToggle={(event) => {','}}>'],['onClick={(event) => {','}}>{label}']]){
 const segment=s=>s.slice(s.indexOf(start),s.indexOf(end,s.indexOf(start)));
 assert.equal(segment(source),segment(policy));
}
assert.equal(policy,old('src/app/tenant/[tenantId]/people/work-policies/PolicyTask.tsx'));
const report={baseline:'2c9905a582fc38dfdd4caddc431ee92e7c2e853a',pageInversions:2,owningFormsByteUnchanged:3,guardHandlersByteEquivalentToQualifiedPolicyTask:2,existingPolicyTaskUnchanged:true,candidateHashes:[calendar,type,component].map(file=>({file,sha256:hash(read(file))})),reusedEvidence:'ux-core-people-management-20261008/qualification.md and policy-retained-error.jpg; source-equivalent guard only, not full new parent qualification',newNative:'See settings-native-review.json; this source audit does not execute browser',visual:{codex:'NOT VISUALLY VERIFIED',claude:'NOT VISUALLY VERIFIED'},authorityAndFinancialContracts:'Unchanged byte-for-byte owning forms, page gate/action parameters preserved through inverse comparison'};
const dir='docs/07-execution/evidence/ux-self-service-auth-return-20261008';fs.writeFileSync(path.join(dir,'settings-task-checks.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
if(process.argv.includes('--reconcile')){
 const invFile='docs/04-product-specs/ux-redesign/inventory.json',regFile='docs/04-product-specs/ux-redesign/review-register.json';
 const previousSource=file=>cp.execFileSync('git',['show','324814a:'+file],{encoding:'utf8'});
 const prior=JSON.parse(previousSource(invFile)),previous=JSON.parse(previousSource(regFile)),fresh=JSON.parse(read(invFile));
 const categories=['routes','boundaries','serverActions','rpcCalls','formControls','requestBoundaries'];const map=new Map();let migrated=0,added=0;
 for(const category of categories){const files=new Set([...prior[category],...fresh[category]].map(x=>x.file));for(const file of files){const a=prior[category].filter(x=>x.file===file),b=fresh[category].filter(x=>x.file===file);if(a.length){assert.equal(a.length,b.length,file+' structural slot count');for(let i=0;i<a.length;i++){map.set(b[i].id,a[i].id);if(a[i].id!==b[i].id)migrated++;}}}}
 const reviews=new Map(previous.items.map(x=>[x.id,x]));
 const items=categories.flatMap(category=>fresh[category].map(item=>{const from=map.get(item.id),priorReview=from&&reviews.get(from);if(priorReview)return{...priorReview,id:item.id};added++;return{id:item.id,category,phase:item.phase,status:'pending',scenarioIds:[],reviewer:null,evidence:null};}));
 assert.equal(items.length,previous.items.length);assert.equal(added,0);for(const state of new Set(previous.items.map(x=>x.status)))assert.equal(items.filter(x=>x.status===state).length,previous.items.filter(x=>x.status===state).length);
 const ordered=previous.items.map(prior=>items.find(item=>map.get(item.id)===prior.id)).concat(items.filter(item=>!map.has(item.id)));assert.equal(ordered.length,items.length);assert.ok(ordered.every(Boolean));fs.writeFileSync(regFile,JSON.stringify({...previous,sourceSnapshot:'324814a0dd13adf3c32574c6879c710040b6f8c1',items:ordered},null,2)+'\n');console.log(JSON.stringify({migrated,added,priorStatesPreserved:true}));
}
