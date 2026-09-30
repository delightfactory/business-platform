'use client';

import Link from 'next/link';
import { useActionState } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { confirmWorkforceImport, validateWorkforceCsv, type CommitImportState, type PreviewImportState } from '../import-actions';

type PreviewRow = PreviewImportState['rows'][number];

export function WorkforceImportForm({ tenantId }: { tenantId: string }) {
  const [preview, previewAction] = useActionState(validateWorkforceCsv, emptyPreview(tenantId));
  const [commit, commitAction] = useActionState(confirmWorkforceImport, emptyCommit());
  const importableRows = preview.rows.filter((row) => row.importable);
  const selectedData = commit.staleRows ? commit.staleRows.filter((row) => row.importable).map((row) => row.data) : null;
  const shownRows = commit.staleRows ?? preview.rows;
  const rejected = shownRows.filter((row) => row.status === 'rejected');
  const selectableData = selectedData ?? importableRows.map((row) => row.data);

  return <div className="workforce-import">
    <form action={previewAction} className="auth-form compact-form">
      <input type="hidden" name="tenantId" value={tenantId} />
      <label htmlFor="workforce-csv">ملف CSV</label>
      <input id="workforce-csv" name="file" type="file" accept=".csv,text/csv" required />
      <p className="field-hint">الحد الأقصى 256 كيلوبايت و100 صف. سيُفحص الملف قبل أي حفظ.</p>
      {preview.error && <p className="form-message error-message" role="alert">{preview.error}</p>}
      <SubmitButton label="فحص الملف" pendingLabel="جارٍ فحص الصفوف…" />
    </form>

    {preview.rows.length > 0 && <section aria-live="polite" className="workforce-import-preview">
      <h2>نتيجة الفحص</h2>
      <p>جاهز: {preview.readyCount} · يحتاج مراجعة: {preview.warningCount} · مرفوض: {preview.rejectedCount}</p>
      <p className="field-hint">الصفوف ذات التحذير تستخدم جهة أو فرعًا نشطًا وحيدًا كاختيار آمن. حدّدها يدويًا إذا وافقت. لن تُضاف الصفوف المرفوضة.</p>
      {(commit.message || commit.error) && <p className={`form-message ${commit.state === 'imported' ? '' : 'error-message'}`} role={commit.state === 'imported' ? 'status' : 'alert'}>{commit.message || commit.error}</p>}
      {commit.state === 'imported' && <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>عرض دليل الموظفين</Link>}
      {rejected.length > 0 && <button className="secondary-button" type="button" onClick={() => downloadRejectReport(rejected)}>تنزيل تقرير الصفوف المرفوضة</button>}
      <div className="workforce-import-table-wrap"><table className="workforce-import-table"><thead><tr>
        <th>سطر الملف</th><th>رمز الموظف</th><th>الاسم</th><th>الحالة</th><th>الملاحظات</th>
      </tr></thead><tbody>{shownRows.map((row) => <tr key={row.source_row_number}>
        <td>{row.source_row_number}</td><td><bdi>{row.employee_code}</bdi></td><td>{row.full_name}</td>
        <td>{row.status === 'ready' ? 'جاهز' : row.status === 'warning' ? 'يحتاج مراجعة' : 'مرفوض'}</td>
        <td>{[...row.errors, ...row.warnings].join(' · ') || '—'}</td>
      </tr>)}</tbody></table></div>

      {commit.state !== 'imported' && selectableData.length > 0 && <form action={commitAction} className="compact-form">
        <input type="hidden" name="tenantId" value={tenantId} />
        {selectableData.map((data, index) => {
          const row = shownRows.find((item) => item.source_row_number === data.source_row_number);
          if (!row?.importable) return null;
          const defaultChecked = row.status === 'ready';
          return <label className="checkbox-row" key={`${row.source_row_number}-${index}`}>
            <input type="checkbox" name="selectedRow" value={JSON.stringify(data)} defaultChecked={defaultChecked} />
            <span>إضافة سطر الملف {row.source_row_number}: <bdi>{row.employee_code}</bdi> — {row.full_name}</span>
          </label>;
        })}
        <div className="workspace-form-actions"><SubmitButton label="إضافة الصفوف المحددة" pendingLabel="جارٍ حفظ الدفعة…" />
          <Link className="secondary-button" href={`/tenant/${tenantId}/people`}>إلغاء</Link></div>
      </form>}
    </section>}
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
