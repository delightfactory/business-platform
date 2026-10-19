import assert from 'node:assert/strict';
import test from 'node:test';
import {
  applyConfirmBatch, applyPreviewBatch, chooseWorkDate, confirmPayload, createImportSession, filterRowIds, isSelected, mappingIndexes, pageOf,
  pendingPreviewIds, prepareAttendanceRows, readAttendanceCsv, rejectedRowsCsv, requestRow, runBatches, selectedSaveIds, setAllSelected,
  setRowSelected, suggestAttendanceMapping, summarizeSession,
} from './attendance-import-batch.mjs';

// Mocked control flow only: the fake server mirrors RPC row shapes, not database behavior.
const encode = (text) => new TextEncoder().encode(text);
const header = 'employee_code,site_name,happened_at,direction,source_event_key';
const line = (i, extra = '') => `E${i % 7},Main,2026-10-01T08:00:00+02:00${extra},in,k${i}`;
function load(lines) {
  const read = readAttendanceCsv(encode([header, ...lines].join('\n')));
  assert.ok(!('error' in read), read.error);
  const indexes = mappingIndexes(suggestAttendanceMapping(read.headers), read.headers.length);
  return createImportSession(prepareAttendanceRows(read.records, indexes, read.headers.length));
}
const echo = (session, ids, status) => ({ ok: true, rows: ids.map((id) => ({ ...requestRow(session.rows[id]), status, errors: [], warnings: [] })) });
const options = (overrides) => ({ shouldStop: () => null, isCurrent: () => true, onProgress: () => {}, ...overrides });

test('strict UTF-8, size and empty-file errors are reported locally', () => {
  assert.match(readAttendanceCsv(new Uint8Array([0xff, 0xfe, 0x41])).error, /UTF-8/);
  assert.match(readAttendanceCsv(new Uint8Array()).error, /فارغ/);
  assert.match(readAttendanceCsv({ byteLength: 20 * 1024 * 1024 + 1 }).error, /20 ميجابايت/);
  assert.match(readAttendanceCsv(encode(header + '\n\n')).error, /لا يحتوي/);
});

test('Arabic aliases and legacy English headers auto-map; duplicates are not reused', () => {
  assert.deepEqual(suggestAttendanceMapping(['رقم التسجيل في المصدر', 'الاتجاه', 'وقت الحدث', 'اسم الفرع', 'رمز الموظف']), ['4', '3', '2', '1', '0']);
  assert.deepEqual(suggestAttendanceMapping([' EMPLOYEE_CODE ', 'site_name', 'x', 'direction', 'source_event_key']), ['0', '1', '', '3', '4']);
  assert.equal(mappingIndexes(['0', '0', '1', '2', '3'], 5), null);
});

test('100,000 records parse and chunk into 1,000 bounded batches without changing physical lines', () => {
  const session = load(Array.from({ length: 100_000 }, (_, i) => line(i)));
  assert.equal(session.rows.length, 100_000);
  assert.equal(session.rows[99_999].source_line_hint, 100_001);
  assert.equal(pendingPreviewIds(session).length, 100_000);
  assert.match(readAttendanceCsv(encode([header, ...Array.from({ length: 100_001 }, (_, i) => line(i))].join('\n'))).error, /صف/);
});

test('cross-batch duplicate keys follow the preview signature rule and are never sent twice', () => {
  const lines = Array.from({ length: 150 }, (_, i) => line(i));
  lines.push(` ${line(5).replace(',in,', ', IN ,')}`);
  lines.push(line(120).replace('08:00', '09:00'));
  const session = load(lines);
  assert.equal(session.rows[150].status, 'duplicate');
  assert.equal(session.rows[151].status, 'rejected');
  assert.deepEqual(pendingPreviewIds(session).length, 150);
});

test('ambiguous rows need an explicit candidate day; selection survives pages and select-all', () => {
  const session = load(Array.from({ length: 120 }, (_, i) => line(i)));
  const ids = pendingPreviewIds(session);
  applyPreviewBatch(session, ids.slice(0, 100), echo(session, ids.slice(0, 100), 'ready'));
  const tail = echo(session, ids.slice(100), 'unassigned');
  tail.rows[0] = { ...tail.rows[0], status: 'ambiguous', candidate_work_dates: ['2026-09-30', '2026-10-01'] };
  applyPreviewBatch(session, ids.slice(100), tail);
  const ambiguous = session.rows[100];
  assert.equal(isSelected(session, ambiguous), false);
  chooseWorkDate(session, 100, '2026-12-31');
  assert.equal(isSelected(session, ambiguous), false, 'non-candidate date rejected');
  chooseWorkDate(session, 100, '2026-10-01');
  assert.equal(isSelected(session, ambiguous), true);
  assert.equal(confirmPayload(session, [100])[0].workDate, '2026-10-01');
  setRowSelected(session, 3, false);
  assert.equal(pageOf(filterRowIds(session, 'all'), 3).ids.length, 20);
  assert.equal(selectedSaveIds(session).length, 119);
  setAllSelected(session, false); assert.equal(selectedSaveIds(session).length, 0);
  setAllSelected(session, true); assert.equal(selectedSaveIds(session).length, 120);
});

test('midway transport failure keeps confirmed batches, marks only the uncertain batch, and verify re-previews before resuming', async () => {
  const session = load(Array.from({ length: 250 }, (_, i) => line(i)));
  const ids = pendingPreviewIds(session);
  for (let offset = 0; offset < ids.length; offset += 100) applyPreviewBatch(session, ids.slice(offset, offset + 100), echo(session, ids.slice(offset, offset + 100), 'ready'));
  const sent = [];
  const save = await runBatches(options({ ids: selectedSaveIds(session), send: async (batch) => {
    sent.push(batch);
    if (sent.length === 2) throw new Error('network');
    return { state: 'processed', rows: batch.map((id) => ({ ...requestRow(session.rows[id]), status: 'accepted' })), error: '' };
  }, apply: (batch, result) => applyConfirmBatch(session, batch, result) }));
  assert.equal(save.state, 'failed'); assert.equal(save.done, 100); assert.equal(sent.length, 2, 'stops; no automatic resend');
  let summary = summarizeSession(session);
  assert.equal(summary.saved, 100); assert.equal(summary.uncertain, 100); assert.equal(summary.ready, 50);
  assert.ok(!selectedSaveIds(session).some((id) => session.uncertain.has(id)), 'uncertain rows are not resent');
  const verifyIds = pendingPreviewIds(session);
  assert.deepEqual(verifyIds, sent[1]);
  const verify = echo(session, verifyIds, 'duplicate');
  verify.rows.slice(60).forEach((row) => { row.status = 'ready'; });
  assert.equal(applyPreviewBatch(session, verifyIds, verify), null);
  summary = summarizeSession(session);
  assert.equal(summary.verifiedPresent, 60); assert.equal(summary.uncertain, 0); assert.equal(summary.ready, 90);
  assert.equal(selectedSaveIds(session).length, 90);
});

test('malformed or mismatched results stop the loop and RPC-raised errors do not mark rows uncertain', async () => {
  const session = load(Array.from({ length: 3 }, (_, i) => line(i)));
  const ids = pendingPreviewIds(session);
  assert.deepEqual(applyPreviewBatch(session, ids, { ok: true, rows: [] }), { kind: 'unknown', error: '' });
  assert.equal(pendingPreviewIds(session).length, 3, 'nothing applied');
  applyPreviewBatch(session, ids, echo(session, ids, 'ready'));
  const swapped = { state: 'processed', rows: [...ids].reverse().map((id) => ({ ...requestRow(session.rows[id]), status: 'accepted' })) };
  assert.equal(applyConfirmBatch(session, ids, swapped).kind, 'unknown');
  assert.equal(session.uncertain.size, 3);
  session.uncertain.clear();
  assert.equal(applyConfirmBatch(session, ids, { state: 'failed', rows: [], error: 'x', errorKind: 'not_saved' }).kind, 'not_saved');
  assert.equal(session.uncertain.size, 0);
});

test('pause and offline are checked only between batches; stale responses are discarded', async () => {
  let pause = false; let current = true; const applied = [];
  const run = await runBatches(options({ ids: [1, 2, 3, 4], size: 2, send: async (batch) => { pause = true; return batch; },
    apply: (batch) => { applied.push(batch); return null; }, shouldStop: () => (pause ? 'paused' : null) }));
  assert.deepEqual([run.state, run.done, applied.length], ['paused', 2, 1]);
  const stale = await runBatches(options({ ids: [1], send: async () => { current = false; return []; }, apply: () => { throw new Error('must not apply'); }, isCurrent: () => current }));
  assert.equal(stale.state, 'stale');
  const offline = await runBatches(options({ ids: [1], send: async () => { throw new Error('no'); }, apply: () => null, shouldStop: () => 'offline' }));
  assert.deepEqual([offline.state, offline.done], ['offline', 0]);
});

test('confirm ambiguous result keeps the row available for a new explicit date', () => {
  const session = load([line(1), line(2)]);
  const ids = pendingPreviewIds(session);
  applyPreviewBatch(session, ids, echo(session, ids, 'ready'));
  const result = { state: 'processed', rows: ids.map((id, i) => ({ ...requestRow(session.rows[id]), status: i ? 'accepted' : 'ambiguous', candidate_work_dates: ['2026-10-01'] })) };
  applyConfirmBatch(session, ids, result);
  assert.equal(filterRowIds(session, 'ambiguous').length, 1);
  chooseWorkDate(session, 0, '2026-10-01');
  assert.deepEqual(selectedSaveIds(session), [0]);
});

test('rejected report neutralizes spreadsheet formulas and quotes values', () => {
  const csv = rejectedRowsCsv([{ source_line_hint: 2, employee_code: '=HYPERLINK("x")', site_name: '+1', happened_at: '@a', direction: '-b', source_event_key: 'k,1', errors: ['سبب'] }]);
  assert.match(csv, /"'=HYPERLINK\(""x""\)"/);
  assert.match(csv, /"'\+1","'@a","'-b","k,1","سبب"/);
});
