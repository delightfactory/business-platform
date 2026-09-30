'use server';

import { parsePeopleCsv } from '@/lib/people-csv-parser.mjs';
import { createSupabaseServerClient } from '@/lib/supabase/server';

const MAX_BYTES = 256 * 1024;
const MAX_ROWS = 100;
const FIELDS = ['employee_code', 'site_name', 'happened_at', 'direction', 'source_event_key'] as const;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ImportStatus = 'ready' | 'ambiguous' | 'unassigned' | 'duplicate' | 'rejected' | 'accepted';
export type ImportRow = {
  source_line_hint: number;
  employee_code: string;
  site_name: string;
  happened_at: string;
  direction: string;
  source_event_key: string;
  full_name?: string;
  work_date?: string;
  candidate_work_dates?: string[];
  status: ImportStatus;
  errors: string[];
  warnings: string[];
};
export type PreviewState = { tenantId: string; rows: ImportRow[]; ready: number; ambiguous: number; unassigned: number; duplicate: number; rejected: number; error: string; attempt: number };
export type ConfirmState = { state: 'idle' | 'processed' | 'failed'; accepted: number; ambiguous: number; unassigned: number; duplicate: number; rejected: number; rows: ImportRow[]; error: string; attempt: number };

export async function previewAttendanceCsv(previous: PreviewState, formData: FormData): Promise<PreviewState> {
  const tenantId = field(formData, 'tenantId');
  const fail = (error: string): PreviewState => ({ ...emptyPreview(tenantId), error, attempt: previous.attempt + 1 });
  if (!uuidPattern.test(tenantId)) return fail('تعذر تحديد الشركة الحالية. أعد فتح صفحة الاستيراد.');
  const file = formData.get('file');
  if (!(file instanceof File) || file.size === 0) return fail('اختر ملف CSV صالحًا.');
  if (file.size > MAX_BYTES) return fail('حجم الملف أكبر من 256 كيلوبايت.');
  if (formData.get('mappingConfirmed') !== 'on') return fail('راجع ربط الأعمدة وأكد مطابقته قبل الفحص.');
  let csv: string;
  try { csv = new TextDecoder('utf-8', { fatal: true }).decode(await file.arrayBuffer()).replace(/^\uFEFF/, ''); }
  catch { return fail('تعذر قراءة الملف بترميز UTF-8. احفظه بهذا الترميز ثم أعد المحاولة.'); }
  const parsed = parsePeopleCsv(csv);
  if (typeof parsed === 'string') return fail(parsed);
  const [header, ...records] = parsed;
  if (!header || header.cells.length < FIELDS.length || header.cells.some((cell) => cell.length > 120)) {
    return fail('تعذر قراءة عناوين الأعمدة. نزّل القالب أو اختر ملفًا بصيغة CSV صحيحة.');
  }
  const indexText = FIELDS.map((name) => field(formData, `column_${name}`));
  if (indexText.some((value) => value === '')) return fail('اربط كل حقل بعمود مختلف قبل الفحص.');
  const indexes = indexText.map(Number);
  if (indexes.some((value) => !Number.isInteger(value) || value < 0 || value >= header.cells.length)
    || new Set(indexes).size !== indexes.length) return fail('اربط كل حقل بعمود مختلف قبل الفحص.');
  const rows = records.filter((record) => record.cells.some((cell) => cell.trim() !== ''));
  if (rows.length === 0) return fail('لا يحتوي الملف على أحداث حضور.');
  if (rows.length > MAX_ROWS) return fail('يسمح الملف بحد أقصى 100 حدث في كل مرة.');
  if (rows.some((row) => row.cells.length !== header.cells.length)) return fail('يوجد صف بعدد أعمدة غير مطابق. راجع الملف ثم أعد الفحص.');
  const payload = rows.map((row) => Object.fromEntries(FIELDS.map((name, fieldIndex) => [name, row.cells[indexes[fieldIndex]].trim()])
    .concat([['source_line_hint', String(row.line)]])));
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. أعد الفحص لاحقًا.');
  const { data, error } = await supabase.rpc('preview_attendance_csv_import', { p_tenant_id: tenantId, p_rows: payload });
  if (error) return fail(error.message.includes('attendance_import_forbidden')
    ? 'تغيرت الصلاحيات أو توقفت وحدة الحضور. لم يُحفظ أي حدث.' : 'تعذر فحص الصفوف. تحقق من الملف والصلاحية ثم أعد المحاولة.');
  if (!Array.isArray(data) || data.length !== rows.length) return fail('لم تكتمل نتيجة فحص جميع الصفوف. أعد رفع الملف.');
  const mapped = data.map((row, index) => normalizeRow(row, rows[index].line, payload[index]));
  return { tenantId, rows: mapped, ready: mapped.filter((row) => row.status === 'ready').length,
    ambiguous: mapped.filter((row) => row.status === 'ambiguous').length,
    unassigned: mapped.filter((row) => row.status === 'unassigned').length,
    duplicate: mapped.filter((row) => row.status === 'duplicate').length,
    rejected: mapped.filter((row) => row.status === 'rejected').length, error: '', attempt: previous.attempt + 1 };
}

export async function confirmAttendanceCsv(previous: ConfirmState, formData: FormData): Promise<ConfirmState> {
  const tenantId = field(formData, 'tenantId');
  const fail = (error: string): ConfirmState => ({ state: 'failed', accepted: 0, ambiguous: 0, unassigned: 0, duplicate: 0, rejected: 0, rows: [], error, attempt: previous.attempt + 1 });
  if (!uuidPattern.test(tenantId)) return fail('تعذر تحديد الشركة الحالية. أعد فتح صفحة الاستيراد.');
  const selected = formData.getAll('selectedRow');
  if (selected.length < 1 || selected.length > MAX_ROWS) return fail('حدد حدثًا واحدًا على الأقل ولا تتجاوز 100 حدث.');
  let rows: Record<string, unknown>[];
  try {
    rows = selected.map((value) => {
      if (typeof value !== 'string' || value.length > 2000) throw new Error('invalid');
      const row = JSON.parse(value) as Record<string, unknown>;
      if (!row || typeof row !== 'object' || Array.isArray(row)) throw new Error('invalid');
      const sourceLine = Number(row.source_line_hint);
      const chosenDate = field(formData, `workDate_${sourceLine}`);
      const submittedDate = chosenDate || (typeof row.work_date === 'string' ? row.work_date : '');
      return {
        ...Object.fromEntries(FIELDS.map((name) => [name, typeof row[name] === 'string' ? row[name] : ''])),
        source_line_hint: Number.isInteger(sourceLine) && sourceLine > 0 ? sourceLine : undefined,
        ...( /^\d{4}-\d{2}-\d{2}$/.test(submittedDate) ? { work_date: submittedDate } : {}),
      };
    });
  } catch { return fail('تعذر قراءة الصفوف المحددة. أعد فحص الملف.'); }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. لم يُحفظ أي حدث.');
  const { data, error } = await supabase.rpc('confirm_attendance_csv_import', { p_tenant_id: tenantId, p_rows: rows });
  if (error) return fail(error.message.includes('attendance_import_forbidden')
    ? 'تغيرت الصلاحيات أو توقفت وحدة الحضور. لم يُحفظ أي حدث.' : 'تعذر تأكيد الاستيراد. لم تتغير الصفوف التي تعذر حفظها. أعد الفحص.');
  if (!isObject(data) || !Array.isArray(data.rows)) return fail('تعذر قراءة نتيجة الاستيراد. حدّث الصفحة وتحقق من سجل الحضور.');
  const resultRows = data.rows.map((row, index) => normalizeRow(row, Number(rows[index]?.source_line_hint) || index + 1, rows[index]));
  return { state: 'processed', accepted: numberValue(data.accepted_count), ambiguous: numberValue(data.ambiguous_count), unassigned: numberValue(data.unassigned_count), duplicate: numberValue(data.duplicate_count),
    rejected: numberValue(data.rejected_count), rows: resultRows, error: '', attempt: previous.attempt + 1 };
}

function normalizeRow(value: unknown, line: number, fallback: Record<string, unknown>): ImportRow {
  const row = isObject(value) ? value : {};
  const errors = Array.isArray(row.errors) ? row.errors.filter((item): item is string => typeof item === 'string') : [];
  const warnings = Array.isArray(row.warnings) ? row.warnings.filter((item): item is string => typeof item === 'string') : [];
  const status: ImportStatus = ['ready', 'ambiguous', 'unassigned', 'duplicate', 'rejected', 'accepted'].includes(String(row.status)) ? row.status as ImportStatus : 'rejected';
  const candidateWorkDates = Array.isArray(row.candidate_work_dates)
    ? row.candidate_work_dates.filter((item): item is string => typeof item === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(item))
    : [];
  return {
    source_line_hint: Number(row.source_line_hint) || line,
    employee_code: stringValue(row.employee_code ?? fallback.employee_code), site_name: stringValue(row.site_name ?? fallback.site_name),
    happened_at: stringValue(row.happened_at ?? fallback.happened_at), direction: stringValue(row.direction ?? fallback.direction),
    source_event_key: stringValue(row.source_event_key ?? fallback.source_event_key),
    ...(typeof row.full_name === 'string' ? { full_name: row.full_name } : {}),
    ...(typeof row.work_date === 'string' ? { work_date: row.work_date } : {}), status, errors, warnings,
    ...(candidateWorkDates.length ? { candidate_work_dates: candidateWorkDates } : {}),
  };
}
function emptyPreview(tenantId: string): PreviewState { return { tenantId, rows: [], ready: 0, ambiguous: 0, unassigned: 0, duplicate: 0, rejected: 0, error: '', attempt: 0 }; }
function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isObject(value: unknown): value is Record<string, unknown> { return Boolean(value && typeof value === 'object' && !Array.isArray(value)); }
function stringValue(value: unknown) { return typeof value === 'string' || typeof value === 'number' ? String(value) : ''; }
function numberValue(value: unknown) { return typeof value === 'number' && Number.isFinite(value) ? value : 0; }
