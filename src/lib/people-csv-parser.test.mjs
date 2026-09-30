import assert from 'node:assert/strict';
import test from 'node:test';
import { parsePeopleCsv } from './people-csv-parser.mjs';

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
