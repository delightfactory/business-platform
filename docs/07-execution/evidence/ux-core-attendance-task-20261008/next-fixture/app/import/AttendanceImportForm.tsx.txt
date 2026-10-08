'use client';

import { startTransition, useActionState, useEffect, useRef, useState, type FormEvent } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { parsePeopleCsv } from '@/lib/people-csv-parser.mjs';
import { confirmAttendanceCsv, previewAttendanceCsv, type ConfirmState, type ImportRow, type PreviewState } from './actions';
import styles from '../attendance-task.module.css';

const FIELDS = [
  { key: 'employee_code', label: 'رمز الموظف', hint: 'رقم الموظف الثابت في دليل الشركة.' },
  { key: 'site_name', label: 'اسم الفرع', hint: 'يجب أن يطابق اسم فرع نشط وفريد.' },
  { key: 'happened_at', label: 'وقت الحدث', hint: <>تاريخ ووقت مع فرق توقيت، مثل <bdi className={styles.formatValue}>2026-09-30T08:30:00+02:00</bdi>.</> },
  { key: 'direction', label: 'الاتجاه', hint: 'اكتب in للدخول أو out للخروج.' },
  { key: 'source_event_key', label: 'معرّف الحدث في المصدر', hint: 'قيمة ثابتة تمنع تكرار استيراد الحدث نفسه.' },
] as const;
type Header = { label: string; index: number };

export function AttendanceImportForm({ tenantId }: { tenantId: string }) {
  const [fileName, setFileName] = useState('');
  const [headers, setHeaders] = useState<Header[]>([]);
  const [mappingError, setMappingError] = useState('');
  const [rawPreview, previewAction, previewPending] = useActionState(previewAttendanceCsv, emptyPreview(tenantId));
  const [rawCommit, commitAction, commitPending] = useActionState(confirmAttendanceCsv, emptyCommit());
  const revisionRef = useRef(0);
  const inFlight = useRef(false);
  const [revision, setRevision] = useState(0);
  const [previewBinding, setPreviewBinding] = useState<{ revision: number; attempt: number } | null>(null);
  const [commitBinding, setCommitBinding] = useState<{ revision: number; previewAttempt: number; attempt: number; retainedResult: ConfirmState | null } | null>(null);
  const busy = previewPending || commitPending;
  useEffect(() => { if (!busy) inFlight.current = false; }, [busy]);
  const previewCurrent = !previewPending && previewBinding?.revision === revision && previewBinding.attempt === rawPreview.attempt;
  const preview = previewCurrent ? rawPreview : emptyPreview(tenantId);
  const commitCurrent = previewCurrent && commitBinding?.revision === revision
    && commitBinding.previewAttempt === preview.attempt && (commitBinding.attempt === rawCommit.attempt
      || (commitPending && commitBinding.retainedResult !== null && rawCommit.attempt === commitBinding.attempt - 1));
  const commit = commitCurrent ? rawCommit : emptyCommit();
  const confirmedResult = commitCurrent
    ? (commit.state === 'processed' ? commit : commitBinding?.retainedResult ?? null)
    : null;
  const showingCommitResult = confirmedResult !== null;
  const rows = confirmedResult ? confirmedResult.rows : preview.rows;
  const readyRows = rows.filter((row) => row.status === 'ready');
  const ambiguousRows = rows.filter((row) => row.status === 'ambiguous');
  const unassignedRows = rows.filter((row) => row.status === 'unassigned');
  const rejectedRows = rows.filter((row) => row.status === 'rejected');

  function invalidateSelection() { const next = ++revisionRef.current; setRevision(next); return next; }

  function submitPreview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (inFlight.current) return;
    const payload = new FormData(event.currentTarget);
    inFlight.current = true;
    setPreviewBinding({ revision: revisionRef.current, attempt: rawPreview.attempt + 1 });
    setCommitBinding(null);
    startTransition(() => previewAction(payload));
  }

  function submitCommit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (inFlight.current || !previewCurrent) return;
    const payload = new FormData(event.currentTarget);
    inFlight.current = true;
    setCommitBinding({ revision: revisionRef.current, previewAttempt: preview.attempt, attempt: rawCommit.attempt + 1, retainedResult: confirmedResult });
    startTransition(() => commitAction(payload));
  }

  function readHeaders(file: File | undefined) {
    if (inFlight.current) return;
    const selectionRevision = invalidateSelection();
    setFileName(file?.name ?? ''); setHeaders([]); setMappingError('');
    if (!file) return;
    if (file.size > 256 * 1024) { setMappingError('حجم الملف أكبر من 256 كيلوبايت.'); return; }
    void file.text().then((text) => {
      if (selectionRevision !== revisionRef.current) return;
      const parsed = parsePeopleCsv(text.replace(/^\uFEFF/, ''));
      if (typeof parsed === 'string' || !parsed[0]?.cells.length) { setMappingError('تعذر قراءة عناوين الأعمدة. تحقق من صيغة CSV.'); return; }
      setHeaders(parsed[0].cells.map((label, index) => ({ label: label.slice(0, 120), index })));
    }).catch(() => { if (selectionRevision === revisionRef.current) setMappingError('تعذر قراءة الملف في المتصفح.'); });
  }

  return <div className="attendance-import">
    <ol className={styles.steps} aria-label="مراحل استيراد الحضور">
      <li aria-current={headers.length === 0 ? 'step' : undefined}>1. اختيار الملف</li>
      <li aria-current={headers.length > 0 && preview.rows.length === 0 ? 'step' : undefined}>2. مطابقة الأعمدة الخمسة</li>
      <li aria-current={preview.rows.length > 0 ? 'step' : undefined}>3. المعاينة والتأكيد</li>
    </ol>
    <fieldset disabled={busy} className={styles.controls} aria-label="اختيار الملف ومراجعة الأحداث">
    <form action={previewAction} onSubmit={submitPreview} aria-busy={previewPending} className="auth-form attendance-import-form">
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
            <select name={`column_${field.key}`} required defaultValue={defaultIndex === undefined ? '' : String(defaultIndex)} onChange={() => invalidateSelection()}>
              <option value="" disabled>اختر عمودًا</option>
              {headers.map((header) => <option key={header.index} value={header.index}>العمود {header.index + 1}: {header.label || 'بلا عنوان'}</option>)}
            </select>
          </label>;
        })}
      </fieldset>}
      {mappingError && <p className="form-message error-message" role="alert">{mappingError}</p>}
      {preview.error && <p className="form-message error-message" role="alert">{preview.error}</p>}
      {preview.rows.length > 0 && <p className="field-hint">تحميل ملف جديد يمحو معاينة الملف الحالي. لن تُحفظ البيانات قبل التأكيد.</p>}
      {headers.length > 0 && <label className="checkbox-row attendance-import-confirm-map"><input key={revision} type="checkbox" name="mappingConfirmed" required/>
        <span>تأكدت من ربط الأعمدة الخمسة بالطريقة الصحيحة.</span></label>}
      <div className="workspace-form-actions"><SubmitButton disabled={busy} label={previewPending ? 'جارٍ فحص الصفوف…' : 'فحص ومعاينة الأحداث'} pendingLabel="جارٍ فحص الصفوف…"/></div>
    </form>

    {(preview.rows.length > 0 || showingCommitResult) && <section className="attendance-import-preview" aria-live="polite">
      <h2>{showingCommitResult ? 'آخر نتيجة حفظ مؤكدة' : 'معاينة الملف'}</h2>
      <p>{confirmedResult ? 'مقبول:' : 'جاهز للحفظ:'} {confirmedResult ? confirmedResult.accepted : preview.ready} · يحتاج اختيار يوم: {confirmedResult ? confirmedResult.ambiguous : preview.ambiguous} · بانتظار التكليف: {confirmedResult ? confirmedResult.unassigned : preview.unassigned} · مكرر: {confirmedResult ? confirmedResult.duplicate : preview.duplicate} · مرفوض: {confirmedResult ? confirmedResult.rejected : preview.rejected}</p>
      {commit.error && <p className="form-message error-message" role="alert">{commit.error}</p>}
      {showingCommitResult && commit.state === 'processed' && <p className="form-message" role="status">حُفظت الأحداث المطابقة، وأُبقيت الأحداث بلا تكليف في قائمة المراجعة دون ربطها بيوم عمل. الأحداث التي تحتاج اختيار يوم لم تُربط بعد، والمرفوضة لم تُحفظ.</p>}
      {showingCommitResult && <p className="field-hint">هذه نتيجة آخر تأكيد فقط. الأحداث التي حُفظت في تأكيد سابق تظل محفوظة.</p>}
      {showingCommitResult && commit.state === 'failed' && <p className="field-hint">النتيجة المعروضة من آخر حفظ مؤكد، وليست نتيجة المحاولة الأخيرة. تحقّق من السجل قبل إعادة التأكيد.</p>}
      {!showingCommitResult && readyRows.length === 0 && ambiguousRows.length === 0 && unassignedRows.length === 0 && <p className="field-hint">لا توجد أحداث يمكن تأكيد حفظها في هذه المعاينة. راجع الملاحظات؛ الأحداث المكررة لا تُحفظ مرة أخرى.</p>}
      {rejectedRows.length > 0 && <button className="secondary-button" type="button" onClick={() => downloadRejectReport(rejectedRows)}>تنزيل تقرير الأحداث المرفوضة</button>}
      <div className="attendance-import-table-wrap"><table className="attendance-import-table"><thead><tr>
        <th>سطر الملف</th><th>رمز الموظف</th><th>الفرع</th><th>وقت الحدث</th><th>الاتجاه</th><th>الحالة والملاحظات</th>
      </tr></thead><tbody>{rows.map((row) => <tr key={`${row.source_line_hint}-${row.source_event_key}`}>
        <td>{row.source_line_hint}</td><td><bdi>{row.employee_code}</bdi></td><td>{row.site_name}</td><td><bdi>{row.happened_at}</bdi></td><td>{row.direction === 'in' ? 'دخول' : row.direction === 'out' ? 'خروج' : row.direction}</td>
        <td>{statusLabel(row.status)}{[...row.errors, ...row.warnings].length > 0 && <small className="attendance-import-note">{[...row.errors, ...row.warnings].join(' · ')}</small>}</td>
      </tr>)}</tbody></table></div>
      {!showingCommitResult && (readyRows.length > 0 || ambiguousRows.length > 0 || unassignedRows.length > 0) && <form action={commitAction} className="attendance-import-confirm-form"
        onSubmit={submitCommit} aria-busy={commitPending}>
        <input type="hidden" name="tenantId" value={tenantId}/>
        {readyRows.map((row) => <label className="checkbox-row" key={`${row.source_line_hint}-${row.source_event_key}`}>
          <input type="checkbox" name="selectedRow" value={JSON.stringify(row)} defaultChecked/>
          <span>حفظ تسجيل {row.direction === 'in' ? 'الدخول' : 'الخروج'} للموظف <bdi>{row.employee_code}</bdi> في <bdi>{row.work_date ?? row.happened_at}</bdi></span>
        </label>)}
        {ambiguousRows.map((row) => <div className="attendance-import-ambiguous" key={`${row.source_line_hint}-${row.source_event_key}`}>
          <label className="checkbox-row">
            <input type="checkbox" name="selectedRow" value={JSON.stringify(row)} defaultChecked
              onChange={(event) => { const dateSelect = event.currentTarget.closest('.attendance-import-ambiguous')?.querySelector('select'); if (dateSelect) dateSelect.required = event.currentTarget.checked; }}/>
            <span>تسجيل {row.direction === 'in' ? 'الدخول' : 'الخروج'} للموظف <bdi>{row.employee_code}</bdi> يطابق أكثر من يوم عمل.</span>
          </label>
          <label className="attendance-import-work-date">اختر يوم العمل المقصود
            <select name={`workDate_${row.source_line_hint}`} defaultValue="" required>
              <option value="">اختر تاريخًا</option>
              {(row.candidate_work_dates ?? []).map((date) => <option key={date} value={date}>{date}</option>)}
            </select>
          </label>
          <p className="form-message form-error" role="note">لن يُربط الحدث بأي يوم تلقائيًا. اختر أحد الأيام المطابقة قبل التأكيد؛ ويعيد النظام فحص الاختيار وقت الحفظ.</p>
        </div>)}
        {unassignedRows.map((row) => <label className="checkbox-row" key={`${row.source_line_hint}-${row.source_event_key}`}>
          <input type="checkbox" name="selectedRow" value={JSON.stringify(row)} defaultChecked/>
          <span>حفظ الحدث في قائمة «بلا تكليف» للموظف <bdi>{row.employee_code}</bdi>؛ لن يُربط بيوم حتى تراجع الحالة.</span>
        </label>)}
        <p className="field-hint">تُفسر الأحداث داخل نافذة يوم العمل المطابقة. وقد يتحول اليوم إلى حالة تحتاج مراجعة إذا اكتملت به بصمة ناقصة.</p>
        <div className="workspace-form-actions"><SubmitButton disabled={busy} label={commitPending ? 'جارٍ حفظ الأحداث…' : 'تأكيد حفظ الأحداث المحددة'} pendingLabel="جارٍ حفظ الأحداث…"/></div>
      </form>}
      {showingCommitResult && ambiguousRows.length > 0 && <form action={commitAction} className="attendance-import-confirm-form attendance-import-ambiguous-retry"
        onSubmit={submitCommit} aria-busy={commitPending}>
        <input type="hidden" name="tenantId" value={tenantId}/>
        <p className="form-message form-error" role="alert">{commit.state === 'failed' ? `تضمنت آخر نتيجة حفظ مؤكدة ${ambiguousRows.length} حدثًا يحتاج اختيار يوم. اختيارك محفوظ؛ تحقّق من السجل قبل إعادة التأكيد.` : `لم يُربط ${ambiguousRows.length} حدثًا لأن تاريخ العمل لم يُحدد. اختر تاريخًا من النتائج الحالية ثم أعد التأكيد.`}</p>
        {ambiguousRows.map((row) => <div className="attendance-import-ambiguous" key={`${row.source_line_hint}-${row.source_event_key}`}>
          <input type="hidden" name="selectedRow" value={JSON.stringify(row)}/>
          <label className="attendance-import-work-date">{row.direction === 'in' ? 'دخول' : 'خروج'} · الموظف <bdi>{row.employee_code}</bdi> · اختر يوم العمل
            <select name={`workDate_${row.source_line_hint}`} defaultValue="" required>
              <option value="">اختر تاريخًا</option>
              {(row.candidate_work_dates ?? []).map((date) => <option key={date} value={date}>{date}</option>)}
            </select>
          </label>
        </div>)}
        <div className="workspace-form-actions"><SubmitButton disabled={busy} label={commitPending ? 'جارٍ إعادة الفحص والحفظ…' : 'تأكيد الأيام المختارة'} pendingLabel="جارٍ إعادة الفحص والحفظ…"/></div>
      </form>}
    </section>}
    </fieldset>
  </div>;
}

function emptyPreview(tenantId: string): PreviewState { return { tenantId, rows: [], ready: 0, ambiguous: 0, unassigned: 0, duplicate: 0, rejected: 0, error: '', attempt: 0 }; }
function emptyCommit(): ConfirmState { return { state: 'idle', accepted: 0, ambiguous: 0, unassigned: 0, duplicate: 0, rejected: 0, rows: [], error: '', attempt: 0 }; }
function statusLabel(status: ImportRow['status']) { return ({ ready: 'جاهز', ambiguous: 'يحتاج اختيار يوم العمل', unassigned: 'بلا تكليف', duplicate: 'مكرر', rejected: 'مرفوض', accepted: 'تم الحفظ' } as const)[status]; }
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
