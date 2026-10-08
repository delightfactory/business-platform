const fs=require('fs'),vm=require('vm'),root=__dirname;let source=fs.readFileSync(root+'/offline-c6-tests.cjs','utf8');source=source.slice(0,source.indexOf('(async function suite'));
async function delta(){
 const root=__dirname;
 const get=part=>candidates.find(c=>c.file.includes(part)).file;
 const row={source_line_hint:2,source_event_key:'QA-event',employee_code:'QA',site_name:'QA',happened_at:'2026-10-09T08:00:00+02:00',direction:'in',status:'ambiguous',errors:[],warnings:[],candidate_work_dates:['2026-10-09','2026-10-10']};
 const options={previewResponse:{rows:[row],ambiguous:1},commitResponse:{state:'processed',rows:[row],accepted:0,ambiguous:1,unassigned:0,duplicate:0,rejected:0,error:''}},e=engine(get('AttendanceImport'),false,options);
 await e.dispatch(e.ready());
 // Controlled React boundary must expose the native action pending cycle to the original inFlight-clearing effect.
 options.pending=true;e.ready();options.pending=false;e.ready();
 await e.dispatch(e.ready(),{formIndex:1});options.pending=true;e.ready();options.pending=false;e.ready();
 let t=e.ready();const form=nodes(t,n=>n.type==='form'&&n.props.className?.includes('ambiguous-retry'))[0];assert.ok(form,'actual retained result retry form');
 const before=fieldSnapshot(t);e.zero();e.navigator.onLine=false;await e.dispatch(t,{formIndex:1});t=e.ready();assert.equal(e.stats.actions,0);assert.deepEqual(fieldSnapshot(t),before);const notice=nodes(nodes(t,n=>n.type==='form'&&n.props.className?.includes('ambiguous-retry'))[0],n=>n.type===e.shared.OfflineSubmissionNotice)[0];assert.ok(notice);e.navigator.onLine=true;e.ready();assert.equal(e.stats.actions,0);
 const a=engine(get('OnboardingForm'));await a.dispatch(a.ready());a.props.actorId=ids[2];t=a.ready();const fields=fieldSnapshot(t);assert.equal(nodes(t,n=>n.type==='button'&&n.props.onClick).length,1);a.zero();a.navigator.onLine=false;await nodes(t,n=>n.type==='button'&&n.props.onClick)[0].props.onClick();await a.drain();assert.equal(a.stats.actions,0);assert.deepEqual(fieldSnapshot(a.ready()),fields);
 const report=JSON.parse(fs.readFileSync(root+'/offline-c6-controlled.json'));assert.equal(report.count,37);report.cases.push({name:'confirmed import ambiguous retry offline retains result and selected dates',status:'pass'},{name:'onboarding actor changed preserves original attempt and recovery guard',status:'pass'});report.count=report.cases.length;report.targetedDelta='Two additional state gates only;37 passed cases and671 source fingerprints reused without rerun';
 fs.writeFileSync(root+'/offline-c6-controlled.json',JSON.stringify(report,null,2)+'\n');console.log({pass:true,total:report.count,deltaCases:2,reusedCases:37,reusedFingerprints:671});
}
const script=source+'\n('+delta.toString()+')().catch(e=>{console.error(e);process.exitCode=1;});';vm.runInThisContext('(function(require,__dirname){'+script+'\n})',{filename:__filename})(require,root);
