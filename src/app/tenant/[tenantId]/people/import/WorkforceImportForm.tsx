'use client';
import { Badge, Button, ButtonLink, Checkbox, DataTable, FileInput, KeyValueStrip, Message, Panel } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import { useActionState, useState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { confirmWorkforceImport, validateWorkforceCsv, type CommitImportState, type PreviewImportState } from '../import-actions';

type PreviewRow = PreviewImportState['rows'][number];

export function WorkforceImportForm({ tenantId }: { tenantId: string }) {
  const { offline, blockOfflineSubmission } = useOfflineSubmission();
  const offlineHint0 = useId();
  const offlineHint1 = useId();
  const [fileName, setFileName] = useState('');
  const [preview, previewAction, previewActionPending] = useActionState(validateWorkforceCsv, emptyPreview(tenantId));
  const [commit, commitAction, commitActionPending] = useActionState(confirmWorkforceImport, emptyCommit());
  const importableRows = preview.rows.filter((row) => row.importable);
  const selectedData = commit.staleRows ? commit.staleRows.filter((row) => row.importable).map((row) => row.data) : null;
  const shownRows = commit.staleRows ?? preview.rows;
  const rejected = shownRows.filter((row) => row.status === 'rejected');
  const selectableData = selectedData ?? importableRows.map((row) => row.data);

  const showOffline1 = offline && !commitActionPending;
  const showOffline0 = offline && !previewActionPending;
  return <div className="workforce-import">
    <form action={previewAction} className="auth-form compact-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
      <input type="hidden" name="tenantId" value={tenantId} />
      <div className="workforce-file-control">
        <span className="workforce-file-label">ملف CSV</span>
        <FileInput id="workforce-csv" className="workforce-file-native" name="file"  accept=".csv,text/csv" required
          aria-describedby="workforce-csv-hint" onChange={(event) => setFileName(event.currentTarget.files?.[0]?.name ?? '')} />
        <label className="workforce-file-trigger" htmlFor="workforce-csv">
          <span className="ui-button ui-button-ghost ui-button-md">اختيار ملف</span>
          <span className="workforce-file-name" aria-live="polite">{fileName || 'لم يتم اختيار ملف'}</span>
        </label>
      </div>
      <p id="workforce-csv-hint" className="field-hint">الحد الأقصى 256 كيلوبايت و100 صف. سيُفحص الملف قبل أي حفظ.</p>
      {preview.error && <Message tone="bad"  role="alert">{preview.error}</Message>}
      <SubmitButton label="فحص الملف" pendingLabel="جارٍ فحص الصفوف…"  ariaDescribedBy={showOffline0 ? offlineHint0 : undefined} disabled={offline}/>
    {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>

    {preview.rows.length > 0 && <Panel aria-live="polite" className="workforce-import-preview">
      <h2>نتيجة الفحص</h2>
      <KeyValueStrip items={[{ label: 'جاهز للإضافة', value: preview.readyCount }, { label: 'يحتاج مراجعتك', value: preview.warningCount }, { label: 'مرفوض', value: preview.rejectedCount }]} />
      <p className="field-hint">الصفوف ذات التحذير تستخدم جهة أو فرعًا نشطًا وحيدًا كاختيار آمن. حدّدها يدويًا إذا وافقت. لن تُضاف الصفوف المرفوضة.</p>
      {(commit.message || commit.error) && <Message tone={commit.state === 'imported' ? 'ok' : 'bad'} role={commit.state === 'imported' ? 'status' : 'alert'}>{commit.message || commit.error}</Message>}
      {commit.state === 'imported' && <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>عرض دليل الموظفين</ButtonLink>}
      {rejected.length > 0 && <Button variant="ghost"  type="button" onClick={() => downloadRejectReport(rejected)}>تنزيل تقرير الصفوف المرفوضة</Button>}
      <div className="workforce-import-table-wrap"><DataTable className="workforce-import-table"><thead><tr>
        <th>سطر الملف</th><th>رمز الموظف</th><th>الاسم</th><th>الحالة</th><th>الملاحظات</th>
      </tr></thead><tbody>{shownRows.map((row) => <tr key={row.source_row_number}>
        <td data-label="سطر الملف">{row.source_row_number}</td><td data-label="رمز الموظف"><bdi>{row.employee_code}</bdi></td><td data-label="الاسم">{row.full_name}</td>
        <td data-label="الحالة"><Badge tone={row.status === 'ready' ? 'ok' : row.status === 'warning' ? 'warn' : 'bad'}>{row.status === 'ready' ? 'جاهز' : row.status === 'warning' ? 'يحتاج مراجعة' : 'مرفوض'}</Badge></td>
        <td data-label="الملاحظات">{[...row.errors, ...row.warnings].join(' · ') || '—'}</td>
      </tr>)}</tbody></DataTable></div>

      {commit.state !== 'imported' && selectableData.length > 0 && <form action={commitAction} className="compact-form" onSubmit={(event) => { blockOfflineSubmission(event); }}>
        <input type="hidden" name="tenantId" value={tenantId} />
        {selectableData.map((data, index) => {
          const row = shownRows.find((item) => item.source_row_number === data.source_row_number);
          if (!row?.importable) return null;
          const defaultChecked = row.status === 'ready';
          return <label className="checkbox-row" key={`${row.source_row_number}-${index}`}>
            <Checkbox  name="selectedRow" value={JSON.stringify(data)} defaultChecked={defaultChecked} />
            <span>إضافة سطر الملف {row.source_row_number}: <bdi>{row.employee_code}</bdi> — {row.full_name}</span>
          </label>;
        })}
        <div className="workspace-form-actions"><SubmitButton label="إضافة الصفوف المحددة" pendingLabel="جارٍ حفظ الدفعة…"  ariaDescribedBy={showOffline1 ? offlineHint1 : undefined} disabled={offline}/>
          <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/people`}>إلغاء</ButtonLink></div>
      {showOffline1 && <OfflineSubmissionNotice id={offlineHint1} purpose="continuation" />}</form>}
    </Panel>}
  </div>;
}

function emptyPreview(tenantId: string): PreviewImportState {
  return { tenantId, rows: [], readyCount: 0, warningCount: 0, rejectedCount: 0, error: '', attempt: 0 };
}

function emptyCommit(): CommitImportState { return { state: 'idle', message: '', error: '', staleRows: null, attempt: 0 }; }

function downloadRejectReport(rows: PreviewRow[]) {
  const quote = (value: unknown) => {
    let text = String(value ?? '');
    if (/^[\s]*[=+@\-\t\r]/.test(text)) text = `'${text}`;
    return `"${text.replaceAll('"', '""')}"`;
  };
  const lines = [['source_line_hint','employee_code','full_name','reasons'].map(quote).join(',')];
  for (const row of rows) lines.push([row.source_row_number,row.employee_code,row.full_name,row.errors.join(' | ')].map(quote).join(','));
  const blob = new Blob(['\uFEFF', lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob); const link = document.createElement('a');
  link.href = url; link.download = 'workforce-import-rejects.csv'; link.click(); URL.revokeObjectURL(url);
}
