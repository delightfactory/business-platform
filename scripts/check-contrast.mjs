import fs from 'node:fs';
const css=fs.readFileSync(new URL('../src/styles/tokens.css',import.meta.url),'utf8');
const declarations=block=>Object.fromEntries([...block.matchAll(/--([\w-]+)\s*:\s*(#[a-fA-F0-9]{3,6})\s*;/g)].map(([,key,value])=>[key,value]));
const light=declarations(css.match(/:root\s*\{([\s\S]*?)\}/)[1]);
const dark={...light,...declarations(css.match(/:root\[data-theme="dark"\]\s*\{([\s\S]*?)\}/)[1])};
const luminance=hex=>{const full=hex.length===4?'#'+[...hex.slice(1)].map(c=>c+c).join(''):hex;return full.slice(1).match(/../g).map(v=>parseInt(v,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0)};
const pairs=[['ink','surface'],['ink-2','surface'],['muted','surface'],['muted','bg'],['money','surface'],['ok-text','ok-bg'],['warn-text','warn-bg'],['bad-text','bad-bg'],['info-text','info-bg'],['brand-ink','brand'],['brand-text','brand-soft'],['pass-ink','pass'],['pass-muted','pass'],['pass-accent-ink','pass-accent'],['toast-ink','toast-bg']];
let failures=0;
for(const [mode,base] of [['light',light],['dark',dark]])for(const brand of ['teal','blue','violet','emerald']){const selector=mode==='light'?`[data-brand="${brand}"]`:`:root[data-theme="dark"] [data-brand="${brand}"]`;const start=css.indexOf(selector+'{');const overrides=declarations(css.slice(start+selector.length+1,css.indexOf('}',start)));const values={...base,...overrides};for(const [ink,surface] of pairs){const a=luminance(values[ink]),b=luminance(values[surface]);const ratio=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);if(ratio<4.5){console.error(`${mode}/${brand}: ${ink}/${surface} ${ratio.toFixed(2)} < 4.5`);failures++;}}}
if(failures)process.exitCode=1;else console.log('Concept C text contrast: all 120 pairs pass WCAG AA.');
