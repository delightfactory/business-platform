import assert from 'node:assert/strict';
import test from 'node:test';
import { parsePeopleCsv, mapWorkforceCsvHeaders, workforceCsvColumns } from './people-csv-parser.mjs';
import { readFileSync } from 'node:fs';

test('parses UTF-8 CSV quoting, embedded commas, escaped quotes, and CRLF', () => {
  assert.deepEqual(parsePeopleCsv('code,name\r\nA-1,"سارة, علي"\r\nA-2,"قالت ""مرحبًا"""\r\n'), [
    { line: 1, cells: ['code', 'name'] }, { line: 2, cells: ['A-1', 'سارة, علي'] },
    { line: 3, cells: ['A-2', 'قالت "مرحبًا"'] },
  ]);
});

test('keeps quoted newlines inside one cell', () => {
  assert.deepEqual(parsePeopleCsv('code,name\nA-1,"اسم\nممتد"'), [
    { line: 1, cells: ['code', 'name'] }, { line: 2, cells: ['A-1', 'اسم\nممتد'] },
  ]);
});

test('preserves physical start lines when blank and multiline records occur', () => {
  const records = parsePeopleCsv('code,name\r\n\r\nA-1,"اسم\r\nممتد"\r\n\r\nA-2,اسم');
  assert.deepEqual(records, [
    { line: 1, cells: ['code', 'name'] }, { line: 2, cells: [''] },
    { line: 3, cells: ['A-1', 'اسم\r\nممتد'] }, { line: 5, cells: [''] },
    { line: 6, cells: ['A-2', 'اسم'] },
  ]);
});

test('rejects malformed, unclosed, or post-quote text', () => {
  assert.match(parsePeopleCsv('a,b\n"broken'), /اقتباس غير مغلق/);
  assert.match(parsePeopleCsv('a,b\n"x"oops'), /بعد علامة إغلاق/);
  assert.match(parsePeopleCsv('a,b\npre"x"'), /تنسيق علامات الاقتباس/);
});

test('bounds row and field sizes', () => {
  assert.match(parsePeopleCsv('h\n' + Array.from({ length: 102 }, (_, i) => `r${i}`).join('\n')), /100 صف/);
  assert.match(parsePeopleCsv('h\n' + 'x'.repeat(4001)), /أطول من الحد/);
});

test('maxRows is opt-in: default stays 100, attendance can request 100,000', () => {
  const rows = (count) => 'h\n' + Array.from({ length: count }, (_, i) => `r${i}`).join('\n');
  assert.equal(parsePeopleCsv(rows(100)).length, 101);
  assert.match(parsePeopleCsv(rows(101)), /100 صف/);
  assert.equal(parsePeopleCsv(rows(101), { maxRows: 100_000 }).length, 102);
  assert.equal(parsePeopleCsv(rows(100_000), { maxRows: 100_000 }).length, 100_001);
  assert.match(parsePeopleCsv(rows(100_001), { maxRows: 100_000 }), /صف/);
  assert.match(parsePeopleCsv('h\n"x', { maxRows: 100_000 }), /اقتباس غير مغلق/);
});

test('downloaded Arabic template has an Excel UTF-8 BOM and every canonical column exactly once', () => {
  const bytes = readFileSync(new URL('../../public/templates/workforce-import.csv', import.meta.url));
  assert.deepEqual([...bytes.subarray(0, 3)], [0xef, 0xbb, 0xbf]);
  const parsed = parsePeopleCsv(bytes.toString('utf8'));
  assert.ok(Array.isArray(parsed));
  assert.equal(parsed.length, 1, 'template must not contain a fictitious employee to import');
  assert.deepEqual(mapWorkforceCsvHeaders(parsed[0].cells), workforceCsvColumns.map(([key]) => key));
  assert.match(parsed[0].cells.join(','), /الاسم الكامل/);
});

test('legacy English headers remain accepted with case and whitespace differences', () => {
  const headers = workforceCsvColumns.map(([key]) => ` ${key.toUpperCase()} `);
  assert.deepEqual(mapWorkforceCsvHeaders(headers), workforceCsvColumns.map(([key]) => key));
});

test('mixed, reordered Arabic and English headers map values without moving physical row numbers', () => {
  const csv = 'full_name,رمز الموظف,الأجر الأساسي,طريقة الأجر,الفرع,جهة العمل,تاريخ بدء العمل,مشمول بالرواتب,job_code,رمز القسم\r\n\r\n"سارة, علي",,9000,monthly,القاهرة,الشركة,2026-10-16,true,,\r\n';
  const parsed = parsePeopleCsv(csv);
  assert.ok(Array.isArray(parsed));
  const mapping = mapWorkforceCsvHeaders(parsed[0].cells);
  assert.ok(Array.isArray(mapping));
  const row = parsed[2];
  assert.equal(row.line, 3);
  const data = Object.fromEntries(mapping.map((key, index) => [key, row.cells[index].trim()]));
  assert.deepEqual(data, { full_name: 'سارة, علي', employee_code: '', base_amount: '9000',
    pay_basis: 'monthly', site_name: 'القاهرة', employer_name: 'الشركة', start_date: '2026-10-16',
    payroll_eligible: 'true', job_code: '', department_code: '' });
});

test('rejects missing, extra, unknown and duplicate columns including cross-language duplicates', () => {
  const headers = workforceCsvColumns.map(([key]) => key);
  assert.match(mapWorkforceCsvHeaders(undefined), /العشرة/);
  assert.match(mapWorkforceCsvHeaders(headers.slice(1)), /العشرة/);
  assert.match(mapWorkforceCsvHeaders([...headers, 'unknown']), /العشرة/);
  assert.match(mapWorkforceCsvHeaders(['عنوان خاطئ', ...headers.slice(1)]), /غير معروف/);
  assert.match(mapWorkforceCsvHeaders(['__proto__', ...headers.slice(1)]), /غير معروف/);
  assert.match(mapWorkforceCsvHeaders(['full_name', ...headers.slice(1)]), /مكرر/);
  assert.match(mapWorkforceCsvHeaders(['الاسم الكامل', ...headers.slice(1)]), /مكرر/);
});
