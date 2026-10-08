const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const root=__dirname,repo=process.cwd(),component='src/app/tenant/[tenantId]/attendance/sources/ChannelForms.tsx';
const lf=p=>fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n');
assert.equal(lf(path.join(repo,component)),lf(path.join(root,'next-fixture/app/channels/ChannelForms.tsx')),'fixture must match actual component');
const rows=JSON.parse(fs.readFileSync(path.join(root,'form-runtime-evidence.json'),'utf8'));
const common=['source','name','kind','site','enabled','reason'],mobile=['geofence','retention_seconds'],geo=['latitude','longitude','radius_m','tolerance_m','max_accuracy_m','max_age_seconds','failure_action'];
const expectedModes=['disable','noGeo','createExternal','editExternal','createMobileNoGeo','createMobileGeo','editMobileGeo'];
assert.deepEqual(rows.map(r=>r.mode).sort(),expectedModes.sort());
const results=rows.map(r=>{
 const reply=JSON.parse(r.result.status.slice(r.result.status.indexOf('{'))),pairs=reply.pairs,values=Object.fromEntries(pairs);
 assert.equal(reply.tenantId,'33333333-3333-4333-8333-333333333333');assert.equal(reply.operation,'save');
 assert.equal(r.result.busy,'false');assert.equal(values.reason,r.result.reason);assert.ok(values.reason);
 const external=r.mode.includes('External'),geofenced=['disable','createMobileGeo','editMobileGeo'].includes(r.mode),creating=r.mode.startsWith('create');
 assert.deepEqual(pairs.map(p=>p[0]).sort(),[...common,...(external?[]:mobile),...(geofenced?geo:[])].sort(),'exact field set and no duplicates');
 assert.equal(values.kind,external?'external':'mobile');assert.equal(values.enabled,r.mode==='disable'?'false':'true');
 assert.equal(values.source,creating?'':'11111111-1111-4111-8111-111111111111');
 assert.equal(values.site,r.mode==='createExternal'?'':'22222222-2222-4222-8222-222222222222');
 if(!external){assert.equal(values.geofence,geofenced?'true':'false');assert.equal(values.retention_seconds,'3600');}
 if(geofenced)for(const [k,v] of Object.entries({latitude:'0',longitude:'0',radius_m:'100',tolerance_m:'20',max_accuracy_m:'30',max_age_seconds:'60',failure_action:'review'}))assert.equal(values[k],v);
 if(r.pending){assert.equal(r.pending.busy,'true');assert.equal(r.pending.allDisabled,true);assert.equal(r.result.focusRole,'status');}
 return {mode:r.mode,exactFields:true,reasonRetained:true,syntheticFailureOnly:true,pendingRecorded:!!r.pending,focusRecorded:r.result.focusRole==='status'};
});
const out={candidate:require('child_process').execFileSync('git',['rev-parse','HEAD'],{cwd:repo,encoding:'utf8'}).trim(),component,componentSha256:crypto.createHash('sha256').update(lf(path.join(repo,component))).digest('hex'),cases:results,scope:'Actual SourceForm and Next runtime; synthetic delayed failure action, no SDK/auth/database/location capture. Disable pending observed separately, focus not recorded. No real save or role acceptance; no visual acceptance claim.'};
fs.writeFileSync(path.join(root,'form-runtime-validation.json'),JSON.stringify(out,null,2)+'\n');console.log(JSON.stringify(out));
