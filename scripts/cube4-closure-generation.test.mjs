import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

// Filesystem is the boundary: execute the real generator against checked-in
// predecessor SQL and capture its output, without writing files or applying SQL.
const generator=fs.readFileSync('scripts/cube4-build-closure-migration.mjs','utf8');
function generate(migrationNames=fs.readdirSync('supabase/migrations')){
 const writes=[];
 const context=vm.createContext({fs:{
  readFileSync:(...args)=>fs.readFileSync(...args),
  readdirSync:()=>migrationNames,
  writeFileSync:(filename,sql)=>writes.push({filename,sql}),
 }});
 const executable=generator.replace(/^import fs from 'node:fs';\r?\n/,'');
 vm.runInContext(executable+'\nglobalThis.literalReplacement=replaceOnce;',context);
 return {writes,replace:context.literalReplacement};
}
test('replacement tokens in generated SQL are preserved as literal text',()=>{
 const {replace}=generate();
 const replacement="pattern '^[0-9]{1,4}$' $& $` $$";
 assert.equal(replace('prefix ANCHOR suffix','ANCHOR',replacement),`prefix ${replacement} suffix`);
 assert.throws(()=>replace('ANCHOR ANCHOR','ANCHOR',replacement),/Unexpected anchor/);
});
test('actual generated payslip SQL has intact regexes and exactly one function tail',()=>{
 const {writes}=generate();assert.equal(writes.length,1);
 assert.equal(writes[0].filename,'supabase/migrations/20261003032000_cube4_review_contract_repairs.sql');
 const report=writes[0].sql.slice(writes[0].sql.indexOf('CREATE OR REPLACE FUNCTION payroll.report_payslip_lines'));
 assert.equal(report.split("'^[0-9]{1,4}$'").length-1,2);
 assert.equal(report.split('FROM resolved').length-1,1);
 assert.equal(report.split('$f$;').length-1,1);
 assert.equal(report.split('REVOKE ALL ON FUNCTION payroll.report_payslip_lines').length-1,1);
 assert.ok(report.indexOf('FROM resolved')>report.indexOf(') statutory_metadata ON'));
 assert.equal(fs.readFileSync(writes[0].filename,'utf8').replaceAll('\r\n','\n'),writes[0].sql.replaceAll('\r\n','\n'));
});
test('real migration directory has unique fourteen-digit versions',()=>{
 const names=fs.readdirSync('supabase/migrations').filter(name=>name.endsWith('.sql'));
 const versions=names.map(name=>/^(\d{14})_/.exec(name)?.[1]);
 assert.ok(versions.every(Boolean));assert.equal(new Set(versions).size,names.length);
});
test('generator refuses duplicate identities and versions after its selected target',()=>{
 const names=fs.readdirSync('supabase/migrations');
 assert.throws(()=>generate([...names,'20261003030000_collision.sql']),/duplicate migration version/);
 assert.throws(()=>generate([...names,'20261003033000_future.sql']),/Repair must follow existing migration/);
});
