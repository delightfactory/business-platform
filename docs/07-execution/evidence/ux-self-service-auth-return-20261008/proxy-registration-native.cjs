const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),net=require('node:net'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const repo=process.cwd();
const port=3617, base='http://127.0.0.1:'+port;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const occupied=()=>new Promise(resolve=>{const s=net.connect(port,'127.0.0.1');s.once('connect',()=>{s.destroy();resolve(true);});s.once('error',()=>resolve(false));});
(async()=>{
 assert.equal(await occupied(),false,'Owned port is occupied; do not stop another task');
 const manifest=JSON.parse(fs.readFileSync(path.join(repo,'.next/server/functions-config-manifest.json')));
 assert.ok(manifest.functions['/_middleware'],'Missing actual compiled Proxy registration');
 const env={...process.env,NEXT_PUBLIC_SUPABASE_URL:'',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:''};
 const child=cp.spawn(process.execPath,[path.join(repo,'node_modules/next/dist/bin/next'),'start','--hostname','127.0.0.1','--port',String(port)],{cwd:repo,env,stdio:['ignore','pipe','pipe'],windowsHide:true});
 let exited=false; const done=new Promise(resolve=>child.once('exit',code=>{exited=true;resolve(code);}));
 // Do not emit server output or environment values.
 child.stdout.resume();child.stderr.resume();
 const checks=[];
 try {
  let ready=false;for(let i=0;i<100&&!exited;i++){if(await occupied()){ready=true;break;}await pause(100);}assert.ok(ready,'Owned production server did not become ready');
  for(const route of ['/auth/login','/auth/callback','/tenant/select','/tenant/synthetic/me']){
   const response=await fetch(base+route,{redirect:'manual'});
   assert.match(response.headers.get('cache-control'),/no-store/);
   assert.equal(response.headers.get('pragma'),'no-cache');assert.equal(response.headers.get('expires'),'0');
   checks.push({route,status:response.status,cacheControl:response.headers.get('cache-control'),pragma:response.headers.get('pragma'),expires:response.headers.get('expires')});
   await response.arrayBuffer();
  }
  for(const route of ['/sw.js','/offline.html','/manifest.webmanifest','/pwa/offline.css','/pwa/offline.js','/pwa/cairo-400.woff2']){
   const response=await fetch(base+route);assert.equal(response.status,200);
   assert.equal(response.headers.get('pragma'),null,'Excluded asset ran Proxy');
   const bytes=Buffer.from(await response.arrayBuffer());
   checks.push({route,status:response.status,bytes:bytes.length,bodySha256:crypto.createHash('sha256').update(bytes).digest('hex'),cacheControl:response.headers.get('cache-control'),proxyPragma:false});
  }
  fs.writeFileSync(path.join(__dirname,'proxy-registration-native.json'),JSON.stringify({schema:'business-platform.proxy-registration-native.v1',scope:'Actual repository production Next server; missing provider config, anonymous only. No live session/role qualification.',compiledFunctions:manifest.functions,checks},null,2)+'\n');
 } finally {if(!exited)child.kill();await done;assert.equal(await occupied(),false,'Owned server listener remains');}
 console.log(JSON.stringify({passed:checks.length,actualCompiledProxy:true,ownedServerRetired:true}));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
