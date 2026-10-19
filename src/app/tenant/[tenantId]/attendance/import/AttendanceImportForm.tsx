'use client';
import { Button, DataTable, Message, Select, FileInput, Checkbox, buttonClassName, Panel, KeyValueStrip } from '@/components/ui';
import { useEffect, useId, useRef, useState } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';
import {
  ATTENDANCE_MAX_BYTES, applyConfirmBatch, applyPreviewBatch, chooseWorkDate, confirmPayload, createImportSession, filterRowIds, isSelectable, isSelected,
  mappingIndexes, pageOf, pendingPreviewIds, prepareAttendanceRows, readAttendanceCsv, rejectedRowsCsv, requestRow, rowView, runBatches, selectedSaveIds,
  setAllSelected, setRowSelected, suggestAttendanceMapping, summarizeSession, type AttendanceRowView, type AttendanceSession, type AttendanceSessionRow,
} from '@/lib/attendance-import-batch.mjs';
import { confirmAttendanceCsv, previewAttendanceBatch, type BatchPreviewResult, type ConfirmState } from './actions';
import styles from '../attendance-task.module.css';

const FIELDS = [
  { key: 'employee_code', label: 'رمز الموظف', hint: 'رقم الموظف الثابت في دليل الشركة.' },
  { key: 'site_name', label: 'اسم الفرع', hint: 'يجب أن يطابق اسم فرع نشط وفريد.' },
  { key: 'happened_at', label: 'وقت الحدث', hint: <>تاريخ ووقت مع فرق توقيت، مثل <bdi className={styles.formatValue}>2026-09-30T08:30:00+02:00</bdi>.</> },
  { key: 'direction', label: 'الاتجاه', hint: 'اكتب in للدخول أو out للخروج.' },
  { key: 'source_event_key', label: 'رقم التسجيل في المصدر', hint: 'رقم ثابت من الملف الأصلي يمنع حفظ التسجيل نفسه مرتين.' },
] as const;
const FILTERS: { value: AttendanceRowView | 'all'; label: string }[] = [
  { value: 'all', label: 'كل التسجيلات' }, { value: 'ambiguous', label: 'يحتاج اختيار يوم العمل' }, { value: 'uncertain', label: 'نتيجة غير مؤكدة' },
  { value: 'ready', label: 'جاهز للحفظ' }, { value: 'unassigned', label: 'بلا بيانات عمل' }, { value: 'saved', label: 'تم الحفظ' },
  { value: 'duplicate', label: 'مكرر أو محفوظ مسبقًا' }, { value: 'rejected', label: 'مرفوض' }, { value: 'pending', label: 'لم يُفحص بعد' },
];
type LoadedFile = { name: string; headers: string[]; records: { line: number; cells: string[] }[] };
type Phase = 'idle' | 'reading' | 'mapping' | 'previewing' | 'review' | 'saving';
type Stop = { kind: string; work: 'preview' | 'save'; error: string };

export function AttendanceImportForm({ tenantId }: { tenantId: string }) {
  const { offline } = useOfflineSubmission();
  const offlineHint = useId();
  const [file, setFile] = useState<LoadedFile | null>(null);
  const [fileError, setFileError] = useState('');
  const [mapping, setMapping] = useState<string[]>([]);
  const [editingMapping, setEditingMapping] = useState(false);
  const [session, setSession] = useState<AttendanceSession | null>(null);
  const [, setVersion] = useState(0);
  const [phase, setPhase] = useState<Phase>('idle');
  const [progress, setProgress] = useState({ done: 0, total: 0 });
  const [stop, setStop] = useState<Stop | null>(null);
  const [pauseRequested, setPauseRequested] = useState(false);
  const [filter, setFilter] = useState<AttendanceRowView | 'all'>('all');
  const [page, setPage] = useState(1);
  // Each file/mapping revision owns a token; responses for an older token are discarded, never merged.
  const tokenRef = useRef(0);
  const pauseRef = useRef(false);
  const runningRef = useRef(false);
  useEffect(() => () => { tokenRef.current += 1; }, []);
  const busy = phase === 'reading' || phase === 'previewing' || phase === 'saving';
  const refresh = () => setVersion((value) => value + 1);

  function resetWork() {
    tokenRef.current += 1;
    setSession(null); setStop(null); setProgress({ done: 0, total: 0 }); setFilter('all'); setPage(1);
  }

  async function chooseFile(selected: File | undefined) {
    if (runningRef.current) return;
    resetWork(); setFile(null); setFileError(''); setMapping([]); setEditingMapping(false);
    if (!selected) { setPhase('idle'); return; }
    if (selected.size > ATTENDANCE_MAX_BYTES) { setFileError('حجم الملف أكبر من 20 ميجابايت. قسّمه إلى ملفين واستورد كل ملف على حدة.'); setPhase('idle'); return; }
    const token = tokenRef.current;
    setPhase('reading');
    try {
      const read = readAttendanceCsv(await selected.arrayBuffer());
      if (token !== tokenRef.current) return;
      if ('error' in read) { setFileError(read.error); setPhase('idle'); return; }
      const suggested = suggestAttendanceMapping(read.headers);
      setFile({ name: selected.name, ...read }); setMapping(suggested); setEditingMapping(suggested.includes('')); setPhase('mapping');
    } catch {
      if (token === tokenRef.current) { setFileError('تعذر قراءة الملف في المتصفح. اختره مرة أخرى.'); setPhase('idle'); }
    }
  }

  function changeMapping(position: number, value: string) {
    if (runningRef.current) return;
    resetWork(); setPhase('mapping');
    setMapping((current) => current.map((item, index) => (index === position ? value : item)));
  }

  async function run(current: AttendanceSession, work: 'preview' | 'save') {
    if (runningRef.current) return false;
    if (!navigator.onLine) { setStop({ kind: 'offline', work, error: '' }); return false; }
    runningRef.current = true; pauseRef.current = false; setPauseRequested(false); setStop(null);
    const token = tokenRef.current;
    const ids = work === 'preview' ? pendingPreviewIds(current) : selectedSaveIds(current);
    setPhase(work === 'preview' ? 'previewing' : 'saving'); setProgress({ done: 0, total: ids.length });
    const result = await runBatches<unknown>({
      ids,
      send: (batch) => work === 'preview'
        ? previewAttendanceBatch(tenantId, batch.map((id) => requestRow(current.rows[id])))
        : confirmAttendanceCsv(emptyCommit(), commitForm(tenantId, confirmPayload(current, batch))),
      apply: (batch, value) => {
        const failure = work === 'preview'
          ? applyPreviewBatch(current, batch, value as BatchPreviewResult | undefined)
          : applyConfirmBatch(current, batch, value as ConfirmState | undefined);
        refresh();
        return failure;
      },
      shouldStop: () => (!navigator.onLine ? 'offline' : pauseRef.current ? 'paused' : null),
      isCurrent: () => token === tokenRef.current,
      onProgress: (done) => setProgress({ done, total: ids.length }),
    });
    runningRef.current = false;
    if (result.state === 'stale') return false;
    setPhase('review'); setPauseRequested(false);
    if (result.state !== 'complete') setStop({ kind: result.state === 'failed' ? result.kind ?? 'unknown' : result.state, work, error: result.error ?? '' });
    if (work === 'preview' && result.state === 'complete' && summarizeSession(current).needsDate > 0) { setFilter('ambiguous'); setPage(1); }
    return result.state === 'complete';
  }

  function startPreview() {
    if (!file || runningRef.current) return;
    const indexes = mappingIndexes(mapping, file.headers.length);
    if (!indexes) return;
    resetWork();
    const next = createImportSession(prepareAttendanceRows(file.records, indexes, file.headers.length));
    setSession(next);
    void run(next, 'preview');
  }
  async function verifyAndContinue() {
    if (!session) return;
    // Uncertain rows are re-previewed first: stored keys come back as duplicates and are never resent.
    if (await run(session, 'preview')) await run(session, 'save');
  }
  function update(change: (current: AttendanceSession) => void) { if (session && !busy) { change(session); refresh(); } }

  const summary = session ? summarizeSession(session) : null;
  const mappingValid = file ? mappingIndexes(mapping, file.headers.length) !== null : false;
  const visible = session ? pageOf(filterRowIds(session, filter), page) : null;
  const hasSaves = summary ? summary.saved + summary.savedUnassigned + summary.present + summary.verifiedPresent + summary.uncertain > 0 : false;
  const step = !file ? 1 : !session ? 2 : 3;

  let primary: { label: string; kind: 'start' | 'verify' | 'preview' | 'save' } | null = null;
  if (phase === 'mapping' && !session) primary = mappingValid ? { label: 'فحص ومعاينة التسجيلات', kind: 'start' } : null;
  else if (session && phase === 'review' && (stop?.work === 'save' || (summary?.uncertain ?? 0) > 0)) primary = { label: summary?.uncertain ? 'التحقق والاستكمال' : 'متابعة الحفظ', kind: 'verify' };
  else if (session && phase === 'review' && summary && summary.pending > 0) primary = { label: 'متابعة الفحص', kind: 'preview' };
  else if (session && phase === 'review' && summary && summary.selected > 0) primary = { label: `حفظ ${summary.selected} تسجيلًا محددًا`, kind: 'save' };
  function runPrimary(kind: 'start' | 'verify' | 'preview' | 'save') {
    if (kind === 'start') startPreview();
    else if (kind === 'verify') void verifyAndContinue();
    else if (session) void run(session, kind);
  }

  return <div className={`attendance-import ${styles.importWorkspace}`}>
    <ol className={styles.steps} aria-label="مراحل استيراد الحضور">
      <li aria-current={step === 1 ? 'step' : undefined}>1. اختيار الملف</li>
      <li aria-current={step === 2 ? 'step' : undefined}>2. مطابقة الأعمدة</li>
      <li aria-current={step === 3 ? 'step' : undefined}>3. المعاينة والحفظ</li>
    </ol>
    <div className="auth-form attendance-import-form">
      <fieldset disabled={busy} className={styles.controls} aria-label="اختيار الملف وربط الأعمدة">
        <div className="workforce-file-control">
          <span className="workforce-file-label">ملف CSV</span>
          <FileInput id="attendance-csv" className="workforce-file-native" accept=".csv,text/csv" aria-describedby="attendance-csv-hint"
            onChange={(event) => void chooseFile(event.currentTarget.files?.[0])}/>
          <label className="workforce-file-trigger" htmlFor="attendance-csv"><span className={buttonClassName('ghost', 'md', '')}>{file ? 'اختيار ملف آخر' : 'اختيار ملف'}</span>
            <span className="workforce-file-name" aria-live="polite">{phase === 'reading' ? 'جارٍ قراءة الملف…' : file ? `${file.name} · ${file.records.length} تسجيل` : 'لم يتم اختيار ملف'}</span></label>
        </div>
        <p id="attendance-csv-hint" className="field-hint">ملف واحد حتى 100,000 تسجيل و20 ميجابايت بترميز UTF-8. يُقرأ الملف في متصفحك ويُرسل إلى النظام على دفعات صغيرة.</p>
        {fileError && <Message tone="bad" role="alert">{fileError}</Message>}
        {file && !editingMapping && mappingValid && <div className="attendance-import-mapping">
          <Message tone="ok" role="status">طابقنا الأعمدة الخمسة تلقائيًا: {FIELDS.map((field, index) => `${field.label} ← ${file.headers[Number(mapping[index])] || `العمود ${Number(mapping[index]) + 1}`}`).join('، ')}.</Message>
          <Button variant="ghost" onClick={() => setEditingMapping(true)}>تعديل ربط الأعمدة</Button>
        </div>}
        {file && (editingMapping || !mappingValid) && <fieldset className="attendance-import-mapping">
          <legend>اربط أعمدة الملف بالبيانات المطلوبة</legend>
          {FIELDS.map((field, position) => <label className="attendance-import-map-field" key={field.key}>
            <span>{field.label}<small>{field.hint}</small></span>
            <Select value={mapping[position] ?? ''} required onChange={(event) => changeMapping(position, event.currentTarget.value)}>
              <option value="" disabled>اختر عمودًا</option>
              {file.headers.map((label, index) => <option key={index} value={index}>العمود {index + 1}: {label.slice(0, 120) || 'بلا عنوان'}</option>)}
            </Select>
          </label>)}
          {!mappingValid && <p className="field-hint">اختر عمودًا مختلفًا لكل معلومة من المعلومات الخمس.</p>}
        </fieldset>}
        {session && <p className="field-hint">تغيير الملف أو ربط الأعمدة يمسح المعاينة الحالية. ما حُفظ فعلًا يبقى محفوظًا، ويظهر «محفوظ مسبقًا» عند فحص الملف نفسه مرة أخرى.</p>}
      </fieldset>

      {busy && phase !== 'reading' && <div className="attendance-import-progress" role="status" aria-live="polite">
        <label htmlFor="attendance-import-progress">{phase === 'previewing' ? 'جارٍ فحص التسجيلات' : 'جارٍ حفظ التسجيلات'}: {progress.done} من {progress.total}</label>
        <progress id="attendance-import-progress" max={Math.max(progress.total, 1)} value={progress.done}/>
        <Button variant="ghost" disabled={pauseRequested} onClick={() => { pauseRef.current = true; setPauseRequested(true); }}>
          {pauseRequested ? 'سيتوقف بعد اكتمال الدفعة الحالية…' : 'إيقاف بعد الدفعة الحالية'}</Button>
        <p className="field-hint">أبقِ هذه الصفحة مفتوحة حتى ينتهي العمل. التقدم محفوظ في هذه الصفحة فقط.</p>
      </div>}
      {stop && <StopMessage stop={stop} uncertain={summary?.uncertain ?? 0}/>}
      {primary && !busy && <div className="workspace-form-actions">
        <Button disabled={offline} onClick={() => runPrimary(primary.kind)} aria-describedby={offline ? offlineHint : undefined}>{primary.label}</Button>
      </div>}
      {primary && offline && !busy && <OfflineSubmissionNotice id={offlineHint} purpose="continuation"/>}
    </div>

    {session && summary && visible && <Panel className="attendance-import-preview" aria-labelledby="attendance-import-result-title">
      <h2 id="attendance-import-result-title">{hasSaves ? 'نتيجة الاستيراد حتى الآن' : 'معاينة الملف'}</h2>
      <KeyValueStrip items={hasSaves ? [
        { label: 'حُفظ وربط بيوم العمل', value: summary.saved }, { label: 'حُفظ في قائمة بلا بيانات عمل', value: summary.savedUnassigned },
        { label: 'محفوظ مسبقًا أو مكرر', value: summary.present + summary.duplicate }, { label: 'موجود في السجل بعد التحقق', value: summary.verifiedPresent },
        { label: 'يحتاج اختيار يوم', value: summary.ambiguous }, { label: 'لم يُحفظ بعد', value: summary.ready + summary.unassigned },
        { label: 'مرفوض', value: summary.rejected }, { label: 'نتيجة غير مؤكدة', value: summary.uncertain },
      ] : [
        { label: 'جاهز للحفظ', value: summary.ready }, { label: 'بلا بيانات عمل', value: summary.unassigned }, { label: 'يحتاج اختيار يوم', value: summary.ambiguous },
        { label: 'مكرر أو محفوظ مسبقًا', value: summary.duplicate }, { label: 'مرفوض', value: summary.rejected }, ...(summary.pending ? [{ label: 'لم يُفحص بعد', value: summary.pending }] : []),
      ]}/>
      {summary.pending === 0 && !hasSaves && phase !== 'saving' && <p className="field-hint">لن يُحفظ شيء قبل الضغط على زر الحفظ. التسجيلات الجاهزة والتي بلا بيانات عمل محددة تلقائيًا؛ التي بلا بيانات عمل تُحفظ في قائمة المراجعة ولا تُربط بيوم.</p>}
      {summary.needsDate > 0 && <Message tone="warn" role="note">{summary.needsDate} تسجيلًا يطابق أكثر من يوم عمل. لن يُربط أي منها تلقائيًا؛ اختر اليوم المقصود لكل تسجيل لتحديده للحفظ، أو اتركه وسيبقى هنا بعد حفظ الباقي.</Message>}
      {summary.pending === 0 && summary.selected === 0 && summary.needsDate === 0 && summary.uncertain === 0 && <p className="field-hint">لا توجد تسجيلات أخرى محددة للحفظ في هذا الملف.</p>}
      {hasSaves && <p className="field-hint">يظل اعتماد أيام العمل بحاجة إلى المراجعة المعتادة في صفحة الحضور.</p>}

      <fieldset disabled={busy} className={styles.controls} aria-label="عرض التسجيلات وتحديدها">
        <div className="workspace-form-actions">
          <label className="attendance-import-work-date">عرض
            <Select value={filter} onChange={(event) => { setFilter(event.currentTarget.value as AttendanceRowView | 'all'); setPage(1); }}>
              {FILTERS.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </Select>
          </label>
          <Button variant="ghost" onClick={() => update((current) => setAllSelected(current, true))}>تحديد كل الصالح للحفظ</Button>
          <Button variant="ghost" onClick={() => update((current) => setAllSelected(current, false))}>إلغاء تحديد الكل</Button>
          {summary.rejected > 0 && <Button variant="ghost" onClick={() => downloadRejectReport(session.rows.filter((row) => rowView(session, row) === 'rejected'))}>تنزيل تقرير المرفوض ({summary.rejected})</Button>}
        </div>
        <div className="attendance-import-table-wrap"><DataTable className="attendance-import-table"><thead><tr>
          <th>حفظ</th><th>سطر الملف</th><th>رمز الموظف</th><th>الفرع</th><th>وقت الحدث</th><th>الاتجاه</th><th>الحالة والملاحظات</th>
        </tr></thead><tbody>{visible.ids.map((id) => <ResultRow key={id} session={session} row={session.rows[id]} onChange={update}/>)}</tbody></DataTable></div>
        {visible.ids.length === 0 && <p className="field-hint">لا توجد تسجيلات في هذا العرض.</p>}
        {visible.pages > 1 && <nav className="workspace-form-actions" aria-label="صفحات التسجيلات">
          <Button variant="ghost" disabled={visible.page <= 1} onClick={() => setPage(visible.page - 1)}>السابق</Button>
          <span aria-live="polite">صفحة {visible.page} من {visible.pages}</span>
          <Button variant="ghost" disabled={visible.page >= visible.pages} onClick={() => setPage(visible.page + 1)}>التالي</Button>
        </nav>}
      </fieldset>
    </Panel>}
  </div>;
}

function ResultRow({ session, row, onChange }: { session: AttendanceSession; row: AttendanceSessionRow; onChange: (change: (current: AttendanceSession) => void) => void }) {
  const view = rowView(session, row);
  const selectable = isSelectable(session, row);
  const needsDate = selectable && row.status === 'ambiguous';
  const notes = [...row.errors, ...row.warnings];
  return <tr>
    <td data-label="حفظ">{selectable
      ? <Checkbox checked={isSelected(session, row)} disabled={needsDate && !session.workDates.has(row.id)} aria-label={`حفظ السطر ${row.source_line_hint}`}
        onChange={(event) => { const checked = event.currentTarget.checked; onChange((current) => setRowSelected(current, row.id, checked)); }}/>
      : '—'}</td>
    <td data-label="سطر الملف">{row.source_line_hint}</td><td data-label="رمز الموظف"><bdi>{row.employee_code}</bdi></td><td data-label="الفرع">{row.site_name}</td>
    <td data-label="وقت الحدث"><bdi>{row.happened_at}</bdi></td><td data-label="الاتجاه">{row.direction === 'in' ? 'دخول' : row.direction === 'out' ? 'خروج' : row.direction}</td>
    <td data-label="الحالة والملاحظات">{statusLabel(view, row)}
      {needsDate && <label className="attendance-import-work-date">اختر يوم العمل المقصود
        <Select value={session.workDates.get(row.id) ?? ''} onChange={(event) => { const date = event.currentTarget.value; onChange((current) => chooseWorkDate(current, row.id, date)); }}>
          <option value="">لم يُحدد</option>
          {(row.candidate_work_dates ?? []).map((date) => <option key={date} value={date}>{date}</option>)}
        </Select></label>}
      {notes.length > 0 && <small className="attendance-import-note">{notes.join(' · ')}</small>}</td>
  </tr>;
}

function StopMessage({ stop, uncertain }: { stop: Stop; uncertain: number }) {
  const saving = stop.work === 'save';
  const text = stop.kind === 'paused' ? (saving ? 'توقف الحفظ بعد اكتمال الدفعة الحالية. الأرقام أدناه تشمل كل ما حُفظ حتى الآن.' : 'توقف الفحص بعد اكتمال الدفعة الحالية. لم يُحفظ أي تسجيل.')
    : stop.kind === 'offline' ? 'الاتصال غير متاح، فلم تُرسل دفعات جديدة. النتائج المؤكدة باقية أدناه؛ تابع عند عودة الاتصال.'
    : saving && uncertain > 0 ? `لم تصل نتيجة آخر دفعة (${uncertain} تسجيلًا)، وقد يكون بعضها حُفظ. لن نعيد إرسالها تلقائيًا. اضغط «التحقق والاستكمال» لنفحصها أولًا: ما حُفظ منها سيظهر «موجود في السجل بعد التحقق»، ثم نكمل حفظ باقي المحدد.`
    : `${stop.error || (saving ? 'تعذر حفظ الدفعة الحالية.' : 'تعذر فحص إحدى الدفعات. لم يُحفظ أي تسجيل أثناء الفحص.')} ${saving ? 'الدفعات المؤكدة قبلها باقية كما هي.' : ''}`;
  return <Message tone={stop.kind === 'paused' ? 'info' : 'bad'} role="alert">{text}{stop.kind === 'auth' && ' راجع صلاحيتك مع مسؤول الشركة قبل المتابعة.'}
    {' '}إذا أغلقت الصفحة، اختر الملف نفسه وافحصه مرة أخرى؛ ما حُفظ سيظهر «محفوظ مسبقًا» ولن يتكرر.</Message>;
}

function commitForm(tenantId: string, entries: { row: Record<string, string | number>; workDate?: string }[]) {
  const form = new FormData();
  form.set('tenantId', tenantId);
  for (const entry of entries) {
    form.append('selectedRow', JSON.stringify(entry.row));
    if (entry.workDate) form.set(`workDate_${entry.row.source_line_hint}`, entry.workDate);
  }
  return form;
}
function emptyCommit(): ConfirmState { return { state: 'idle', accepted: 0, ambiguous: 0, unassigned: 0, duplicate: 0, rejected: 0, rows: [], error: '', attempt: 0 }; }
function statusLabel(view: AttendanceRowView, row: AttendanceSessionRow) {
  if (view === 'saved') return row.outcome === 'saved_unassigned' ? 'حُفظ في قائمة بلا بيانات عمل' : 'تم الحفظ';
  if (view === 'duplicate') return row.outcome === 'verified_present' ? 'موجود في السجل بعد التحقق' : row.outcome === 'present' ? 'محفوظ مسبقًا' : 'مكرر أو محفوظ مسبقًا';
  return ({ pending: 'لم يُفحص بعد', ready: 'جاهز', ambiguous: 'يحتاج اختيار يوم العمل', unassigned: 'بلا بيانات عمل', rejected: 'مرفوض', accepted: 'تم الحفظ', uncertain: 'نتيجة غير مؤكدة' } as const)[view];
}
function downloadRejectReport(rows: AttendanceSessionRow[]) {
  const url = URL.createObjectURL(new Blob([rejectedRowsCsv(rows)], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a'); link.href = url; link.download = 'attendance-import-rejects.csv'; link.click(); URL.revokeObjectURL(url);
}
