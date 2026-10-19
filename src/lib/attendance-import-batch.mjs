import { parsePeopleCsv } from './people-csv-parser.mjs';

// One local file is read in the browser and sent as sequential 100-row requests; the SQL limit stays 100.
export const ATTENDANCE_MAX_BYTES = 20 * 1024 * 1024;
export const ATTENDANCE_MAX_RECORDS = 100_000;
export const ATTENDANCE_BATCH_SIZE = 100;
export const ATTENDANCE_PAGE_SIZE = 50;
// confirmAttendanceCsv accepts selectedRow JSON up to 2000 chars; keep room for the chosen work date.
const ROW_JSON_LIMIT = 1900;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

export const attendanceFields = Object.freeze(['employee_code', 'site_name', 'happened_at', 'direction', 'source_event_key']);
const headerAliases = {
  employee_code: ['employee_code', 'رمز الموظف', 'كود الموظف', 'رقم الموظف'],
  site_name: ['site_name', 'اسم الفرع', 'الفرع'],
  happened_at: ['happened_at', 'وقت الحدث', 'وقت التسجيل'],
  direction: ['direction', 'الاتجاه', 'حضور أو انصراف', 'نوع التسجيل'],
  source_event_key: ['source_event_key', 'رقم التسجيل في المصدر', 'رقم التسجيل'],
};

export function readAttendanceCsv(buffer) {
  if (!buffer || buffer.byteLength === 0) return { error: 'الملف فارغ. اختر ملف CSV يحتوي على تسجيلات الحضور.' };
  if (buffer.byteLength > ATTENDANCE_MAX_BYTES) return { error: 'حجم الملف أكبر من 20 ميجابايت. قسّمه إلى ملفين واستورد كل ملف على حدة.' };
  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(buffer).replace(/^﻿/, ''); }
  catch { return { error: 'تعذر قراءة الملف بترميز UTF-8. احفظه من Excel بصيغة «CSV UTF-8» ثم اختره مرة أخرى.' }; }
  const parsed = parsePeopleCsv(text, { maxRows: ATTENDANCE_MAX_RECORDS });
  if (typeof parsed === 'string') return { error: parsed };
  const [header, ...records] = parsed;
  if (!header || header.cells.length < attendanceFields.length || header.cells.some((cell) => cell.length > 120)) {
    return { error: 'تعذر قراءة عناوين الأعمدة. نزّل الملف النموذجي أو اختر ملف CSV صحيحًا.' };
  }
  const data = records.filter((record) => record.cells.some((cell) => cell.trim() !== ''));
  if (data.length === 0) return { error: 'لا يحتوي الملف على تسجيلات حضور.' };
  return { headers: header.cells, records: data };
}

export function suggestAttendanceMapping(headers) {
  const normalized = headers.map((label) => label.replace(/^﻿/, '').trim().toLowerCase());
  const used = new Set();
  return attendanceFields.map((field) => {
    const index = normalized.findIndex((label, position) => !used.has(position) && headerAliases[field].includes(label));
    if (index < 0) return '';
    used.add(index);
    return String(index);
  });
}

export function mappingIndexes(mapping, headerCount) {
  const indexes = mapping.map((value) => (value === '' ? NaN : Number(value)));
  if (indexes.some((value) => !Number.isInteger(value) || value < 0 || value >= headerCount) || new Set(indexes).size !== indexes.length) return null;
  return indexes;
}

// Mirrors preview_attendance_csv_import's within-request rule across the whole file:
// first key occurrence is checked by the server; later identical rows are duplicates, changed rows are rejected.
export function prepareAttendanceRows(records, indexes, headerCount) {
  const seen = new Map();
  return records.map((record, id) => {
    const values = Object.fromEntries(attendanceFields.map((name, position) => [name, (record.cells[indexes[position]] ?? '').trim()]));
    const row = { id, source_line_hint: record.line, ...values, status: 'pending', errors: [], warnings: [] };
    if (record.cells.length !== headerCount) return { ...row, status: 'rejected', errors: ['عدد الأعمدة في هذا السطر لا يطابق عناوين الملف.'] };
    if (JSON.stringify(requestRow(row)).length > ROW_JSON_LIMIT) return { ...row, status: 'rejected', errors: ['بيانات هذا السطر أطول من المسموح.'] };
    const key = row.source_event_key;
    if (key === '') return row;
    const signature = [row.employee_code, row.site_name, row.happened_at, row.direction.toLowerCase()].join('\u001f');
    if (!seen.has(key)) { seen.set(key, signature); return row; }
    return seen.get(key) === signature
      ? { ...row, status: 'duplicate', warnings: ['مكرر داخل الملف؛ سيُحتسب الحدث مرة واحدة.'] }
      : { ...row, status: 'rejected', errors: ['مفتاح الحدث مكرر داخل الملف ببيانات مختلفة.'] };
  });
}

export function requestRow(row) {
  return { ...Object.fromEntries(attendanceFields.map((name) => [name, row[name]])), source_line_hint: row.source_line_hint };
}

export function createImportSession(rows) {
  return { rows, excluded: new Set(), workDates: new Map(), uncertain: new Set() };
}

export function isSelectable(session, row) {
  return !row.outcome && !session.uncertain.has(row.id) && ['ready', 'unassigned', 'ambiguous'].includes(row.status);
}
export function isSelected(session, row) {
  if (!isSelectable(session, row) || session.excluded.has(row.id)) return false;
  return row.status !== 'ambiguous' || session.workDates.has(row.id);
}
export function setRowSelected(session, id, selected) {
  if (selected) session.excluded.delete(id); else session.excluded.add(id);
}
export function setAllSelected(session, selected) {
  for (const row of session.rows) if (isSelectable(session, row)) setRowSelected(session, row.id, selected);
}
export function chooseWorkDate(session, id, date) {
  const row = session.rows[id];
  if (row?.status === 'ambiguous' && datePattern.test(date) && row.candidate_work_dates?.includes(date)) {
    session.workDates.set(id, date); session.excluded.delete(id);
  } else session.workDates.delete(id);
}

export function pendingPreviewIds(session) {
  const ids = [];
  for (const row of session.rows) if (row.status === 'pending' || session.uncertain.has(row.id)) ids.push(row.id);
  return ids;
}
export function selectedSaveIds(session) {
  const ids = [];
  for (const row of session.rows) if (isSelected(session, row)) ids.push(row.id);
  return ids;
}

export function confirmPayload(session, ids) {
  const entries = [];
  for (const id of ids) {
    const row = session.rows[id];
    const workDate = row.status === 'ambiguous' ? session.workDates.get(id) : row.work_date;
    entries.push({ row: { ...requestRow(row), ...(workDate ? { work_date: workDate } : {}) }, workDate: row.status === 'ambiguous' ? workDate : undefined });
  }
  return entries;
}

function matches(batchRows, resultRows) {
  return Array.isArray(resultRows) && resultRows.length === batchRows.length
    && resultRows.every((result, index) => result && String(result.source_event_key ?? '').trim() === batchRows[index].source_event_key
      && Number(result.source_line_hint) === batchRows[index].source_line_hint);
}

// Returns null when applied, otherwise a failure the caller must show without guessing.
export function applyPreviewBatch(session, ids, result) {
  if (!result || result.ok !== true) return { kind: result?.kind ?? 'unknown', error: result?.error ?? '' };
  const batchRows = ids.map((id) => session.rows[id]);
  if (!matches(batchRows, result.rows)) return { kind: 'unknown', error: '' };
  result.rows.forEach((value, index) => {
    const row = batchRows[index];
    const verifying = session.uncertain.delete(row.id);
    const next = { ...row, status: value.status, errors: value.errors ?? [], warnings: value.warnings ?? [],
      work_date: value.work_date, candidate_work_dates: value.candidate_work_dates, full_name: value.full_name };
    if (verifying && value.status === 'duplicate') next.outcome = 'verified_present';
    if (value.status !== 'ambiguous' || !next.candidate_work_dates?.includes(session.workDates.get(row.id))) session.workDates.delete(row.id);
    session.rows[row.id] = next;
  });
  return null;
}

const confirmOutcomes = { accepted: 'saved', unassigned: 'saved_unassigned', duplicate: 'present', rejected: 'save_rejected' };
export function applyConfirmBatch(session, ids, result) {
  const batchRows = ids.map((id) => session.rows[id]);
  if (!result || result.state !== 'processed') {
    const kind = result?.errorKind ?? 'unknown';
    if (kind === 'unknown') for (const id of ids) session.uncertain.add(id);
    return { kind, error: result?.error ?? '' };
  }
  if (!matches(batchRows, result.rows)) { for (const id of ids) session.uncertain.add(id); return { kind: 'unknown', error: '' }; }
  result.rows.forEach((value, index) => {
    const row = batchRows[index];
    const next = { ...row, status: value.status === 'accepted' ? row.status : value.status, errors: value.errors ?? [], warnings: value.warnings ?? [] };
    if (confirmOutcomes[value.status]) next.outcome = confirmOutcomes[value.status];
    if (value.status === 'ambiguous') { next.candidate_work_dates = value.candidate_work_dates; session.workDates.delete(row.id); }
    session.rows[row.id] = next;
  });
  return null;
}

// Sequential loop: never parallel, checks stop conditions only between requests, never retries a write.
export async function runBatches({ ids, size = ATTENDANCE_BATCH_SIZE, send, apply, shouldStop, isCurrent, onProgress }) {
  for (let offset = 0; offset < ids.length; offset += size) {
    const stop = shouldStop();
    if (stop) return { state: stop, done: offset };
    const batch = ids.slice(offset, offset + size);
    let result;
    try { result = await send(batch); } catch { result = undefined; }
    if (!isCurrent()) return { state: 'stale', done: offset };
    const failure = apply(batch, result);
    if (failure) return { state: 'failed', done: offset, ...failure };
    onProgress(offset + batch.length);
  }
  return { state: 'complete', done: ids.length };
}

export function rowView(session, row) {
  if (session.uncertain.has(row.id)) return 'uncertain';
  if (row.outcome === 'saved' || row.outcome === 'saved_unassigned') return 'saved';
  if (row.outcome === 'present' || row.outcome === 'verified_present') return 'duplicate';
  return row.status;
}

export function summarizeSession(session) {
  const counts = { total: session.rows.length, pending: 0, ready: 0, unassigned: 0, ambiguous: 0, duplicate: 0, rejected: 0,
    saved: 0, savedUnassigned: 0, present: 0, verifiedPresent: 0, uncertain: 0, selected: 0, needsDate: 0 };
  for (const row of session.rows) {
    if (session.uncertain.has(row.id)) { counts.uncertain += 1; continue; }
    if (row.outcome === 'saved') counts.saved += 1;
    else if (row.outcome === 'saved_unassigned') counts.savedUnassigned += 1;
    else if (row.outcome === 'present') counts.present += 1;
    else if (row.outcome === 'verified_present') counts.verifiedPresent += 1;
    else if (row.status in counts) counts[row.status] += 1;
    if (isSelected(session, row)) counts.selected += 1;
    if (!row.outcome && row.status === 'ambiguous' && !session.workDates.has(row.id)) counts.needsDate += 1;
  }
  return counts;
}

export function filterRowIds(session, filter) {
  const ids = [];
  for (const row of session.rows) if (filter === 'all' || rowView(session, row) === filter) ids.push(row.id);
  return ids;
}

export function pageOf(ids, page, size = ATTENDANCE_PAGE_SIZE) {
  const pages = Math.max(1, Math.ceil(ids.length / size));
  const current = Math.min(Math.max(1, page), pages);
  return { page: current, pages, ids: ids.slice((current - 1) * size, current * size) };
}

export function rejectedRowsCsv(rows) {
  const quote = (value) => {
    let text = String(value ?? '');
    if (/^[\s]*[=+@\-\t\r|%]/.test(text)) text = `'${text}`;
    return `"${text.replaceAll('"', '""')}"`;
  };
  const lines = [['سطر الملف', 'رمز الموظف', 'الفرع', 'وقت الحدث', 'الاتجاه', 'رقم التسجيل في المصدر', 'السبب'].map(quote).join(',')];
  for (const row of rows) lines.push([row.source_line_hint, row.employee_code, row.site_name, row.happened_at, row.direction, row.source_event_key, row.errors.join(' | ')].map(quote).join(','));
  return `﻿${lines.join('\r\n')}`;
}
