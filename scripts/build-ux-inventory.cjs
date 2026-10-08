/* eslint-disable @typescript-eslint/no-require-imports -- Standalone CommonJS audit CLI supports NODE_PATH for isolated dependency runtimes. */
/* Source-only inventory. It does not execute application code or inspect runtime secrets. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const ts = require('typescript');
const root = process.cwd();
const output = path.join(root, 'docs/04-product-specs/ux-redesign');
const digest = full => crypto.createHash('sha256').update(/\.png$/i.test(full) ? fs.readFileSync(full) : fs.readFileSync(full,'utf8').replace(/\r\n/g,'\n')).digest('hex');
function walk(dir) { return fs.readdirSync(dir, {withFileTypes:true}).flatMap(e => e.isDirectory() ? walk(path.join(dir,e.name)) : [path.join(dir,e.name)]); }
function phase(file) {
  if (file.includes('/operator/')) return 'R3';
  if (file.includes('/auth/') || file === 'src/proxy.ts' || /\/tenant\/select\//.test(file)) return 'R2';
  if (/\/people\//.test(file) || /people-csv|employee-account-delivery/.test(file)) return 'R4';
  if (/\/attendance\//.test(file) || file.includes('attendance-channel')) return 'R5';
  if (/\/payroll\//.test(file)) return 'R7';
  if (/\/leave\//.test(file) || /\/me\//.test(file)) return 'R6';
  if (/\/(users|branding|entities-sites)\//.test(file)) return 'R2';
  if (file === 'src/app/tenant/[tenantId]/page.tsx') return 'R8';
  return 'R1';
}
const files = walk(path.join(root,'src')).sort().map(full => ({full,file:path.relative(root,full).split(path.sep).join('/')}));
const result = {schema:'business-platform.ux-inventory.v1', sourceHead:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(), files:[], routes:[], boundaries:[], serverActions:[], rpcCalls:[], formControls:[]};
for (const {full,file} of files) {
  const text = fs.readFileSync(full,'utf8');
  result.files.push({file,phase:phase(file),sha256:digest(full)});
  if (!/\.(tsx?|mjs)$/.test(file) || /\.test\.|\.d\.mts$/.test(file)) continue;
  const sf = ts.createSourceFile(file,text,ts.ScriptTarget.Latest,true,file.endsWith('.tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);
  const line = n => sf.getLineAndCharacterOfPosition(n.getStart(sf)).line+1;
  const directive = body => body?.statements?.some(s=>ts.isExpressionStatement(s)&&ts.isStringLiteral(s.expression)&&s.expression.text==='use server');
  const moduleServer = directive(sf);
  const exported = n => n?.modifiers?.some(m=>m.kind===ts.SyntaxKind.ExportKeyword);
  if (/\/page\.tsx$|\/route\.ts$/.test(file)) {
    const url = '/'+file.slice('src/app/'.length).replace(/\/(page\.tsx|route\.ts)$/,'').replace(/^page\.tsx$/,'');
    result.routes.push({id:`ROUTE:${file}`,file,url,kind:file.endsWith('page.tsx')?'page':'endpoint',phase:phase(file)});
  }
  if (/\/(layout|loading|error|not-found|template|default|global-error)\.tsx$/.test(file)) result.boundaries.push({id:`BOUNDARY:${file}`,file,phase:phase(file)});
  function rpcNames(node, into=[]) {
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.name.text==='rpc') {
      const arg=node.arguments[0]; into.push(arg && ts.isStringLiteralLike(arg)?arg.text:`DYNAMIC:${arg?.getText(sf)??'missing'}`);
    }
    ts.forEachChild(node,c=>rpcNames(c,into)); return [...new Set(into)];
  }
  function visit(node) {
    if ((ts.isFunctionDeclaration(node)||ts.isArrowFunction(node)||ts.isFunctionExpression(node)) && node.body && (directive(node.body)||(moduleServer&&(exported(node)||(ts.isVariableDeclaration(node.parent)&&exported(node.parent.parent?.parent)))))) {
      const name = node.name?.text ?? (ts.isVariableDeclaration(node.parent)?node.parent.name.getText(sf):`inline@${line(node)}`);
      const variants=[];
      for(const parameter of node.parameters??[]) if(parameter.type && ts.isUnionTypeNode(parameter.type)) for(const type of parameter.type.types) if(ts.isLiteralTypeNode(type)&&ts.isStringLiteral(type.literal)) variants.push({parameter:parameter.name.getText(sf),value:type.literal.text});
      const branches=[];
      function collect(n) {if(ts.isSwitchStatement(n)) for(const c of n.caseBlock.clauses) if(ts.isCaseClause(c)&&ts.isStringLiteral(c.expression)) branches.push({discriminator:n.expression.getText(sf),value:c.expression.text});if(ts.isBinaryExpression(n)&&[ts.SyntaxKind.EqualsEqualsEqualsToken,ts.SyntaxKind.EqualsEqualsToken].includes(n.operatorToken.kind)&&ts.isStringLiteral(n.right)&&/^(operation|command|action|decision|kind|type)$/.test(n.left.getText(sf)))branches.push({discriminator:n.left.getText(sf),value:n.right.text});ts.forEachChild(n,collect);}
      collect(node.body);
      result.serverActions.push({id:`ACTION:${file}#${name}`,file,line:line(node),name,phase:phase(file),inline:!moduleServer,rpcs:rpcNames(node.body),variants,branches});
    }
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)&&node.expression.name.text==='rpc') {
      const arg=node.arguments[0];const literal=arg&&ts.isStringLiteralLike(arg);let candidates=[];
      if(arg&&ts.isIdentifier(arg)) {function find(n){if(ts.isBinaryExpression(n)&&n.operatorToken.kind===ts.SyntaxKind.EqualsToken&&n.left.getText(sf)===arg.text&&ts.isStringLiteralLike(n.right))candidates.push(n.right.text);if(ts.isVariableDeclaration(n)&&n.name.getText(sf)===arg.text&&n.initializer&&ts.isStringLiteralLike(n.initializer))candidates.push(n.initializer.text);ts.forEachChild(n,find);}find(sf);}
      result.rpcCalls.push({id:`RPC:${file}:${line(node)}:${node.pos}`,file,line:line(node),phase:phase(file),name:literal?arg.text:null,expression:literal?null:arg?.getText(sf),candidates:[...new Set(candidates)],resolution:literal?'literal':candidates.length?'finite-candidates-need-manual-check':'unresolved-needs-manual-check'});
    }
    if(ts.isJsxOpeningElement(node)||ts.isJsxSelfClosingElement(node)) {
      const tag=node.tagName.getText(sf);if(['form','button','input','select','textarea','SubmitButton','OfflineSubmitButton','Tabs.Trigger','Form','Dialog.Close','summary','PolicyTask','EmployerSelector'].includes(tag)) {const attrs={};for(const a of node.attributes.properties)if(ts.isJsxAttribute(a)&&['action','formAction','name','type','aria-label','label','pendingLabel','disabled','value'].includes(a.name.text))attrs[a.name.text]=a.initializer?.getText(sf)??true;result.formControls.push({id:`CONTROL:${file}:${line(node)}:${node.pos}`,file,line:line(node),tag,phase:phase(file),attributes:attrs});}
    }
    ts.forEachChild(node,visit);
  }
  visit(sf);
}
const known=['R1','R2','R3','R4','R5','R6','R7','R8'];
result.requestBoundaries=['src/proxy.ts','next.config.ts'].map(file=>({id:`REQUEST:${file}`,file,phase:file === 'src/proxy.ts' ? 'R2' : 'R1',reviewPhases:['R1','R2'],sha256:digest(path.join(root,file))}));
result.fingerprintPolicy='sha256-utf8-normalized-LF; PNG raw bytes';
for(const list of [result.files,result.routes,result.boundaries,result.serverActions,result.rpcCalls,result.formControls]) for(const item of list) if(!known.includes(item.phase)) throw Error(`Unassigned source ${item.file}`);
result.summary={sourceFiles:result.files.length,pages:result.routes.filter(r=>r.kind==='page').length,endpoints:result.routes.filter(r=>r.kind==='endpoint').length,boundaries:result.boundaries.length,serverActions:result.serverActions.length,rpcCallSites:result.rpcCalls.length,uniqueLiteralRpcs:new Set(result.rpcCalls.map(r=>r.name).filter(Boolean)).size,dynamicRpcSites:result.rpcCalls.filter(r=>!r.name).length,formControls:result.formControls.length,sourceAssignmentComplete:true,semanticScenarioReviewComplete:false,executionCoverageComplete:false};
fs.mkdirSync(output,{recursive:true});fs.writeFileSync(path.join(output,'inventory.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify(result.summary));
