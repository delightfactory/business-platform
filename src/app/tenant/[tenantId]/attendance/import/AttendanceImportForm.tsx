'use client';

import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { parsePeopleCsv } from '@/lib/people-csv-parser.mjs';
import { confirmAttendanceCsv, previewAttendanceCsv, type ConfirmState, type ImportRow, type PreviewState } from './actions';

const FIELDS = [
  { key: 'employee_code', label: 'رمز الموظف', hint: 'رقم الموظف الثابت في دليل الشركة.' },
  { key: 'site_name', label: 'اسم الفرع', hint: 'يجب أن يطابق اسم فرع نشط وفريد.' },
  { key: 'happened_at', label: 'وقت الحدث', hint: 'تاريخ ووقت مع فرق توقيت، مثل 2026-09-30T08:30:00+02:00.' },
  { key: 'direction', label: 'الاتجاه', hint: 'اكتب in للدخول أو out للخروج.' },
  { key: 'source_event_key', label: 'معرّف الحدث في المصدر', hint: 'قيمة ثابتة تمنع تكرار استيراد الحدث نفسه.' },
] as const;
type Header = { label: string; index: number };

export function AttendanceImportForm({ tenantId }: { tenantId: string }) {
  const [fileName, setFileName] = useState('');
  const [headers, setHeaders] = useState<Header[]>([]);
  const [mappingError, setMappingError] = useState('');
  const [preview, previewAction] = useActionState(previewAttendanceCsv, emptyPreview(tenantId));
  const [commit, commitAction] = useActionState(confirmAttendanceCsv, emptyCommit());
  const [committedPreviewAttempt, setCommittedPreviewAttempt] = useState<number | null>(null);
  const showingCommitResult = commit.state === 'processed'
    && (preview.rows.length === 0 || committedPreviewAttempt === preview.attempt);
  const rows = showingCommitResult ? commit.rows : preview.rows;
  const readyRows = rows.filter((row) => row.status === 'ready');
  const unassignedRows = rows.filter((row) => row.status === 'unassigned');
  const rejectedRows = rows.filter((row) => row.status === 'rejected');

  function readHeaders(file: File | undefined) {
    setFileName(file?.name ?? ''); setHeaders([]); setMappingError('');
    if (!file) return;
    if (file.size > 256 * 1024) { setMappingError('حجم الملف أكبر من 256 كيلوبايت.'); return; }
    void file.text().then((text) => {
      const parsed = parsePeopleCsv(text.replace(/^\uFEFF/, ''));
      if (typeof parsed === 'string' || !parsed[0]?.cells.length) { setMappingError('تعذر قراءة عناوين الأعمدة. تحقق من صيغة CSV.'); return; }
      setHeaders(parsed[0].cells.map((label, index) => ({ label: label.slice(0, 120), index })));
    }).catch(() => setMappingError('تعذر قراءة الملف في المتصفح.'));
  }

  return <div className="attendance-import">
    <form action={previewAction} className="auth-form attendance-import-form">
      <input type="hidden" name="tenantId" value={tenantId}/>
      <div className="workforce-file-control">
        <span className="workforce-file-label">ملف CSV</span>
        <input id="attendance-csv" className="workforce-file-native" name="file" type="file" accept=".csv,text/csv" required
          aria-describedby="attendance-csv-hint" onChange={(event) => readHeaders(event.currentTarget.files?.[0])}/>
        <label className="workforce-file-trigger" htmlFor="attendance-csv"><span className="secondary-button">اختيار ملف</span>
          <span className="workforce-file-name" aria-live="polite">{fileName || 'لم يتم اختيار ملف'}</span></label>
      </div>
      <p id="attendance-csv-hint" className="field-hint">الحد الأقصى 256 كيلوبايت و100 حدث. الملفات المشفرة أو غير UTF-8 مرفوضة.</p>
      {headers.length > 0 && <fieldset className="attendance-import-mapping">
        <legend>اربط أعمدة الملف بالبيانات المطلوبة</legend>
        {FIELDS.map((field) => {
          const defaultIndex = headers.find((header) => header.label.trim().toLowerCase() === field.key)?.index;
          return <label className="attendance-import-map-field" key={field.key}>
            <span>{field.label}<small>{field.hint}</small></span>
            <select name={`column_${field.key}`} required defaultValue={defaultIndex === undefined ? '' : String(defaultIndex)}>
              <option value="" disabled>اختر عمودًا</option>
              {headers.map((header) => <option key={header.index} value={header.index}>العمود {header.index + 1}: {header.label || 'بلا عنوان'}</option>)}
            </select>
          </label>;
        })}
      </fieldset>}
      {mappingError && <p className="form-message error-message" role="alert">{mappingError}</p>}
      {preview.error && <p className="form-message error-message" role="alert">{preview.error}</p>}
      {preview.rows.length > 0 && <p className="field-hint">تحميل ملف جديد يمحو معاينة الملف الحالي. لن تُحفظ البيانات قبل التأكيد.</p>}
      {headers.length > 0 && <label className="checkbox-row attendance-import-confirm-map"><input type="checkbox" name="mappingConfirmed" required/>
        <span>تأكدت من ربط الأعمدة الخمسة بالطريقة الصحيحة.</span></label>}
      <div className="workspace-form-actions"><SubmitButton label="فحص ومعاينة الأحداث" pendingLabel="جارٍ فحص الصفوف…"/></div>
    </form>

    {(preview.rows.length > 0 || showingCommitResult) && <section className="attendance-import-preview" aria-live="polite">
      <h2>{showingCommitResult ? 'نتيجة الحفظ' : 'معاينة الملف'}</h2>
      <p>{showingCommitResult ? 'مقبول:' : 'جاهز للحفظ:'} {showingCommitResult ? commit.accepted : preview.ready} · بانتظار التكليف: {showingCommitResult ? commit.unassigned : preview.unassigned} · مكرر: {showingCommitResult ? commit.duplicate : preview.duplicate} · مرفوض: {showingCommitResult ? commit.rejected : preview.rejected}</p>
      {commit.error && <p className="form-message error-message" role="alert">{commit.error}</p>}
      {showingCommitResult && <p className="form-message" role="status">حُفظت الأحداث المطابقة، وأُبقيت الأحداث بلا تكليف في قائمة المراجعة دون ربطها بيوم عمل. الأحداث المرفوضة لم تُحفظ.</p>}
      {rejectedRows.length > 0 && <button className="secondary-button" type="button" onClick={() => downloadRejectReport(rejectedRows)}>تنزيل تقرير الأحداث المرفوضة</button>}
      <div className="attendance-import-table-wrap"><table className="attendance-import-table"><thead><tr>
        <th>سطر الملف</th><th>رمز الموظف</th><th>الفرع</th><th>وقت الحدث</th><th>الاتجاه</th><th>الحالة والملاحظات</th>
      </tr></thead><tbody>{rows.map((row) => <tr key={`${row.source_line_hint}-${row.source_event_key}`}>
        <td>{row.source_line_hint}</td><td><bdi>{row.employee_code}</bdi></td><td>{row.site_name}</td><td><bdi>{row.happened_at}</bdi></td><td>{row.direction === 'in' ? 'دخول' : row.direction === 'out' ? 'خروج' : row.direction}</td>
        <td>{statusLabel(row.status)}{[...row.errors, ...row.warnings].length > 0 && <small className="attendance-import-note">{[...row.errors, ...row.warnings].join(' · ')}</small>}</td>
      </tr>)}</tbody></table></div>
      {!showingCommitResult && (readyRows.length > 0 || unassignedRows.length > 0) && <form action={commitAction} className="attendance-import-confirm-form"
        onSubmit={() => setCommittedPreviewAttempt(preview.attempt)}>
        <input type="hidden" name="tenantId" value={tenantId}/>
        {readyRows.map((row) => <label className="checkbox-row" key={`${row.source_line_hint}-${row.source_event_key}`}>
          <input type="checkbox" name="selectedRow" value={JSON.stringify(row)} defaultChecked/>
          <span>حفظ تسجيل {row.direction === 'in' ? 'الدخول' : 'الخروج'} للموظف <bdi>{row.employee_code}</bdi> في <bdi>{row.work_date ?? row.happened_at}</bdi></span>
        </label>)}
        {unassignedRows.map((row) => <label className="checkbox-row" key={`${row.source_line_hint}-${row.source_event_key}`}>
          <input type="checkbox" name="selectedRow" value={JSON.stringify(row)} defaultChecked/>
          <span>حفظ الحدث في قائمة «بلا تكليف» للموظف <bdi>{row.employee_code}</bdi>؛ لن يُربط بيوم حتى تراجع الحالة.</span>
        </label>)}
        <p className="field-hint">تُفسر الأحداث داخل نافذة Work Instance المطابقة. وقد يتحول اليوم إلى حالة تحتاج مراجعة إذا اكتملت به بصمة ناقصة.</p>
        <div className="workspace-form-actions"><SubmitButton label="تأكيد حفظ الأحداث المحددة" pendingLabel="جارٍ حفظ الأحداث…"/></div>
      </form>}
    </section>}
  </div>;
}

function emptyPreview(tenantId: string): PreviewState { return { tenantId, rows: [], ready: 0, unassigned: 0, duplicate: 0, rejected: 0, error: '', attempt: 0 }; }
function emptyCommit(): ConfirmState { return { state: 'idle', accepted: 0, unassigned: 0, duplicate: 0, rejected: 0, rows: [], error: '', attempt: 0 }; }
function statusLabel(status: ImportRow['status']) { return ({ ready: 'جاهز', unassigned: 'بلا تكليف', duplicate: 'مكرر', rejected: 'مرفوض', accepted: 'تم الحفظ' } as const)[status]; }
function downloadRejectReport(rows: ImportRow[]) {
  const quote = (value: unknown) => {
    let text = String(value ?? '');
    if (/^[\s]*[=+@\-\t\r]/.test(text)) text = `'${text}`;
    return `"${text.replaceAll('"', '""')}"`;
  };
  const lines = [['source_line_hint','employee_code','site_name','happened_at','direction','reasons'].map(quote).join(',')];
  for (const row of rows) lines.push([row.source_line_hint,row.employee_code,row.site_name,row.happened_at,row.direction,row.errors.join(' | ')].map(quote).join(','));
  const blob = new Blob(['\uFEFF',lines.join('\r\n')],{type:'text/csv;charset=utf-8'}); const url=URL.createObjectURL(blob);
  const link=document.createElement('a'); link.href=url; link.download='attendance-import-rejects.csv'; link.click(); URL.revokeObjectURL(url);
}
