const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const cp = require('node:child_process');
const repo = process.cwd();
const ts = require(path.join(repo, 'node_modules/typescript'));
const { NextRequest, NextResponse } = require(path.join(repo, 'node_modules/next/server'));
const original = cp.execFileSync('git', ['show', '6fc2e33a461272a09a733b5bc61aa6406df146f4:proxy.ts'], {cwd: repo, encoding:'utf8'});
const current = fs.readFileSync(path.join(repo, 'src/proxy.ts'), 'utf8');
assert.equal(current.replace(/\r\n/g,'\n'), original.replace(/\r\n/g,'\n'));
const source = fs.readFileSync(path.join(repo, 'src/lib/supabase/proxy.ts'), 'utf8');
const hash = text => crypto.createHash('sha256').update(text.replace(/\r\n/g,'\n')).digest('hex');
const cases = [];
async function check(name, run) { await run(); cases.push({name, status:'pass'}); }
function load(env, factory) {
  const compiledModule = {exports:{}};
  vm.runInNewContext(ts.transpileModule(source, {compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText,
    {module:compiledModule,exports:compiledModule.exports,process:{env},require:name => {
      if(name==='next/server') return {NextResponse};
      if(name==='@supabase/ssr') return {createServerClient:factory};
      throw Error('Unexpected import');
    }});
  return compiledModule.exports.updateSession;
}
const env = {NEXT_PUBLIC_SUPABASE_URL:'https://synthetic.invalid',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'synthetic-public-test-value'};
const request = () => new NextRequest('http://127.0.0.1:3617/tenant/synthetic/me', {headers:{cookie:'qa_session=old; qa_other=retained'}});
function noStore(response) {
  assert.match(response.headers.get('cache-control'), /private.*no-store/);
  assert.equal(response.headers.get('pragma'),'no-cache');
  assert.equal(response.headers.get('expires'),'0');
}
(async()=> {
  await check('Convention implementation and matcher unchanged',async()=>assert.equal(current.replace(/\r\n/g,'\n'),original.replace(/\r\n/g,'\n')));
  for(const missing of ['NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY']) await check('Missing '+missing+' performs no provider call',async()=> {
    const local = {...env}; delete local[missing];
    const response = await load(local,()=>{throw Error('Must not construct client');})(request());
    noStore(response); assert.equal(response.cookies.getAll().length,0);
  });
  await check('Claims verified exactly once without rotation',async()=> {
    let calls=0; const req=request();
    const response=await load(env,(url,key,options)=>{
      assert.equal(url,env.NEXT_PUBLIC_SUPABASE_URL);assert.equal(key,env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
      assert.equal(options.cookies.getAll().find(c=>c.name==='qa_other').value,'retained');
      return {auth:{getClaims:async()=>{calls++;return {data:{claims:{sub:'synthetic'}},error:null};}}};
    })(req);
    assert.equal(calls,1);noStore(response);assert.equal(response.cookies.getAll().length,0);
  });
  await check('Rotation forwards request and response cookies, options and provider headers',async()=> {
    const req=request();
    const response=await load(env,(_url,_key,options)=>({auth:{getClaims:async()=>{
      options.cookies.setAll([{name:'qa_session',value:'new',options:{httpOnly:true,sameSite:'lax',path:'/',maxAge:60}}],{'x-qa-provider':'retained'});
      assert.equal(options.cookies.getAll().find(c=>c.name==='qa_session').value,'new');
      return {data:{claims:{sub:'synthetic'}},error:null};
    }}}))(req);
    noStore(response); assert.equal(req.cookies.get('qa_session').value,'new');
    assert.equal(req.cookies.get('qa_other').value,'retained');
    assert.match(response.headers.get('x-middleware-request-cookie'),/qa_session=new/);
    assert.match(response.headers.get('x-middleware-request-cookie'),/qa_other=retained/);
    assert.equal(response.cookies.get('qa_session').value,'new');
    assert.match(response.headers.get('set-cookie'),/HttpOnly/);
    assert.match(response.headers.get('set-cookie'),/SameSite=lax/);
    assert.match(response.headers.get('set-cookie'),/Max-Age=60/);
    assert.equal(response.headers.get('x-qa-provider'),'retained');
  });
  await check('Repeated rotation returns latest cookie response',async()=> {
    const req=request();const response=await load(env,(_u,_k,o)=>({auth:{getClaims:async()=>{
      o.cookies.setAll([{name:'qa_session',value:'first',options:{path:'/'}}]);
      o.cookies.setAll([{name:'qa_session',value:'last',options:{path:'/'}}]);
      return {data:null,error:null};
    }}}))(req);
    assert.equal(req.cookies.get('qa_session').value,'last');assert.equal(response.cookies.get('qa_session').value,'last');noStore(response);
  });
  await check('Returned claims error preserves existing pass-through, no invented authority',async()=> {
    const response=await load(env,()=>({auth:{getClaims:async()=>({data:null,error:{code:'synthetic_invalid'}})}}))(request());
    noStore(response);assert.equal(response.headers.get('location'),null);assert.equal(response.cookies.getAll().length,0);
  });
  await check('Thrown provider failure is propagated, no hidden retry',async()=> {
    let calls=0;await assert.rejects(load(env,()=>({auth:{getClaims:async()=>{calls++;throw Error('synthetic provider failure');}}}))(request()),/synthetic provider failure/);assert.equal(calls,1);
  });
  const report={schema:'business-platform.proxy-registration-tests.v1',baseline:cp.execFileSync('git',['rev-parse','HEAD'],{cwd:repo,encoding:'utf8'}).trim(),entrySha256:hash(current),helperSha256:hash(source),scope:'Actual helper with native NextRequest/NextResponse; synthetic SDK only. No live auth/role/expiry qualification.',cases};
  fs.writeFileSync(path.join(__dirname,'proxy-registration-controlled.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({passed:cases.length,sourceIdentical:true,scope:report.scope}));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
