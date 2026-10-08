/* eslint-disable @typescript-eslint/no-require-imports -- Standalone source-contract regression check. */
const fs = require('node:fs');
const assert = require('node:assert/strict');
const ts = require('typescript');
function literalTable(file, name) {
  const source = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
  let table;
  function visit(node) {
    if (ts.isVariableDeclaration(node) && node.name.getText(source) === name) table = node.initializer;
    ts.forEachChild(node, visit);
  }
  visit(source);
  assert.ok(table && ts.isObjectLiteralExpression(table), `${name}: expected a literal table`);
  return Object.fromEntries(table.properties.map(property => {
    assert.ok(ts.isPropertyAssignment(property) && ts.isStringLiteral(property.initializer), `${name}: expected literal guidance`);
    return [property.name.getText(source).replace(/^['"]|['"]$/g, ''), property.initializer.text];
  }));
}
const base = 'src/app/tenant/[tenantId]/payroll/';
const guidance = literalTable(base + 'runs/rules.ts', 'issueNames');
const titles = literalTable(base + 'issue-titles.ts', 'issueTitles');
assert.deepEqual(Object.keys(titles).sort(), Object.keys(guidance).sort(), 'Every source issue needs a presentation title');
assert.ok(Object.values(titles).every(title => title.trim()), 'Titles must be nonempty');
console.log(JSON.stringify({issueCodes: Object.keys(guidance).length, titleCoverage: 'PASS'}));
