import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import {createContext,runInContext} from 'node:vm';
const require=createRequire(import.meta.url),ts=require('typescript'),context=createContext({exports:{}});
runInContext(ts.transpileModule(readFileSync(new URL('./print-session.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText,context);
function harness(fail=false){
 const attributes=new Map(),listeners=new Map();let expiry;
 const root={setAttribute:(key,value)=>attributes.set(key,value),removeAttribute:key=>attributes.delete(key)};
 const host={addEventListener:(key,fn)=>listeners.set(key,fn),removeEventListener:key=>listeners.delete(key),setTimeout:fn=>{expiry=fn;return 1;},clearTimeout:()=>{},print:()=>{if(fail)throw new Error('modeled print failure');listeners.get('beforeprint')?.();}};
 return {root,host,attributes,listeners,expire:()=>expiry?.(),start:()=>context.exports.startPayslipPrint(root,host)};
}
// Real presentation guard with modeled DOM/events; browser media/device gates remain open.
test('authorized session enables first print and clears financial visibility after print',()=>{const h=harness();h.start();assert.equal(h.attributes.get('data-print-authorized'),'true');h.listeners.get('afterprint')();assert.equal(h.attributes.has('data-print-authorized'),false);assert.equal(h.listeners.size,0);});
test('a second native print cannot reuse the first authorization',()=>{const h=harness();h.start();h.listeners.get('beforeprint')();assert.equal(h.attributes.has('data-print-authorized'),false);});
test('context cleanup and expiry remove authorization and listeners',()=>{const h=harness(),clear=h.start();clear();clear();assert.equal(h.attributes.size,0);assert.equal(h.listeners.size,0);const other=harness();other.start();other.expire();assert.equal(other.attributes.size,0);assert.equal(other.listeners.size,0);});
test('print failure clears the authorized presentation state',()=>{const h=harness(true);assert.throws(()=>h.start(),/modeled print failure/);assert.equal(h.attributes.size,0);assert.equal(h.listeners.size,0);});
