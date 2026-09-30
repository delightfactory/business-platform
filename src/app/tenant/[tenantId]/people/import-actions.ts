'use server';

import { createSupabaseServerClient } from '@/lib/supabase/server';
import { parsePeopleCsv } from '@/lib/people-csv-parser.mjs';

const MAX_BYTES = 256 * 1024;
const MAX_ROWS = 100;
const HEADERS = ['employee_code','full_name','employer_name','site_name','start_date','pay_basis','base_amount','payroll_eligible','department_code','job_code'];
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ImportData = {
  source_row_number: number; employee_code: string; full_name: string; employer_name: string; site_name: string;
  start_date: string; pay_basis: string; base_amount: string; payroll_eligible: string;
  department_code: string; job_code: string; employer_id: string | null; site_id: string | null;
  department_id: string | null; job_id: string | null; start_date_value: string | null;
  amount_value: number | null; payroll_eligible_value: boolean | null;
};
export type PreviewImportRow = { source_row_number: number; employee_code: string; full_name: string;
  status: 'ready' | 'warning' | 'rejected'; importable: boolean; errors: string[]; warnings: string[]; data: ImportData };
export type PreviewImportState = { tenantId: string; rows: PreviewImportRow[]; readyCount: number; warningCount: number;
  rejectedCount: number; error: string; attempt: number };
export type CommitImportState = { state: 'idle' | 'imported' | 'stale' | 'failed'; message: string; error: string;
  staleRows: PreviewImportRow[] | null; attempt: number };

export async function validateWorkforceCsv(previous: PreviewImportState, formData: FormData): Promise<PreviewImportState> {
  const tenantId = text(formData.get('tenantId'));
  const fail = (error: string): PreviewImportState => ({ ...emptyPreview(tenantId), error, attempt: previous.attempt + 1 });
  if (!uuidPattern.test(tenantId)) return fail('تعذر تحديد الشركة الحالية. أعد فتح صفحة الاستيراد.');
  const file = formData.get('file');
  if (!(file instanceof File) || file.size === 0) return fail('اختر ملف CSV صالحًا.');
  if (file.size > MAX_BYTES) return fail('حجم الملف أكبر من 256 كيلوبايت.');
  let csv: string;
  try { csv = new TextDecoder('utf-8', { fatal: true }).decode(await file.arrayBuffer()).replace(/^\uFEFF/, ''); }
  catch { return fail('تعذر قراءة الملف بترميز UTF-8. احفظه بهذا الترميز ثم أعد المحاولة.'); }
  const parsed = parsePeopleCsv(csv);
  if (typeof parsed === 'string') return fail(parsed);
  const [headerRecord, ...records] = parsed;
  const headers = headerRecord?.cells;
  if (!headers || headers.length !== HEADERS.length || headers.some((header, index) => header.trim().toLowerCase() !== HEADERS[index])) {
    return fail('الأعمدة لا تطابق قالب استيراد الموظفين. نزّل القالب وأعد ترتيب الأعمدة كما هو.');
  }
  const rows = records.filter((record) => record.cells.some((cell) => cell.trim() !== ''));
  if (rows.length === 0) return fail('لا يحتوي الملف على صفوف موظفين.');
  if (rows.length > MAX_ROWS) return fail('يسمح الملف بحد أقصى 100 صف في كل مرة.');
  if (rows.some((row) => row.cells.length !== HEADERS.length)) return fail('يوجد صف بعدد أعمدة غير مطابق للقالب. لم يُحفظ أي شيء.');
  const payload = rows.map((record) => Object.fromEntries(HEADERS.map((key, col) => [key, record.cells[col].trim()])
    .concat([['source_row_number', String(record.line)]])));
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. أعد الفحص لاحقًا.');
  const { data, error } = await supabase.rpc('preview_people_workforce_import', { p_tenant_id: tenantId, p_rows: payload });
  if (error) return fail(error.message.includes('people_import_forbidden')
    ? 'تغيرت الصلاحيات أو لم تعد خدمة الموارد البشرية مفعّلة. لم يُحفظ أي شيء.'
    : 'تعذر فحص الملف. راجع الصلاحيات واتصال الشركة ثم أعد المحاولة.');
  if (!Array.isArray(data)) return fail('تعذر قراءة نتيجة الفحص. أعد المحاولة.');
  const parsedRows = data as PreviewImportRow[];
  if (parsedRows.length !== rows.length) return fail('لم تكتمل نتيجة فحص جميع الصفوف؛ أعد رفع الملف.');
  return { tenantId, rows: parsedRows, readyCount: parsedRows.filter((row) => row.status === 'ready').length,
    warningCount: parsedRows.filter((row) => row.status === 'warning').length,
    rejectedCount: parsedRows.filter((row) => row.status === 'rejected').length, error: '', attempt: previous.attempt + 1 };
}

export async function confirmWorkforceImport(previous: CommitImportState, formData: FormData): Promise<CommitImportState> {
  const tenantId = text(formData.get('tenantId'));
  const fail = (error: string): CommitImportState => ({ state: 'failed', message: '', error, staleRows: null, attempt: previous.attempt + 1 });
  if (!uuidPattern.test(tenantId)) return fail('تعذر تحديد الشركة الحالية. أعد فتح صفحة الاستيراد.');
  const selected = formData.getAll('selectedRow');
  if (selected.length < 1 || selected.length > MAX_ROWS) return fail('حدد صفًا واحدًا على الأقل ولا تتجاوز 100 صف.');
  let rows: Record<string, unknown>[];
  try {
    rows = selected.map((value) => {
      if (typeof value !== 'string' || value.length > 12000) throw new Error('invalid');
      const row = JSON.parse(value) as Record<string, unknown>;
      if (!row || typeof row !== 'object' || Array.isArray(row)) throw new Error('invalid');
      return row;
    });
  } catch { return fail('تعذر قراءة الصفوف المحددة. أعد فحص الملف.'); }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الاتصال غير متاح الآن. لم يُحفظ أي موظف.');
  const { data, error } = await supabase.rpc('confirm_people_workforce_import', { p_tenant_id: tenantId, p_rows: rows });
  if (error) return fail(error.message.includes('people_import_forbidden')
    ? 'تغيرت الصلاحيات أو لم تعد خدمة الموارد البشرية مفعّلة. لم يُحفظ أي موظف.'
    : 'تعذر تأكيد الاستيراد. لم تُحفظ دفعة جزئية؛ أعد فحص الملف.');
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  if (result?.state === 'imported' && typeof result.imported_count === 'number') return {
    state: 'imported', message: `تمت إضافة ${result.imported_count} موظفًا بنجاح.`, error: '', staleRows: null, attempt: previous.attempt + 1,
  };
  const staleRows = Array.isArray(result?.results) ? result.results as PreviewImportRow[] : null;
  return { state: 'stale', message: '', error: typeof result?.message === 'string' ? result.message
    : 'تغيرت بعض البيانات منذ الفحص؛ لم يُضف أي موظف. راجع الصفوف وافحص الملف مرة أخرى.', staleRows,
    attempt: previous.attempt + 1 };
}

function emptyPreview(tenantId: string): PreviewImportState {
  return { tenantId, rows: [], readyCount: 0, warningCount: 0, rejectedCount: 0, error: '', attempt: 0 };
}
function text(value: FormDataEntryValue | null) { return typeof value === 'string' ? value.trim() : ''; }
