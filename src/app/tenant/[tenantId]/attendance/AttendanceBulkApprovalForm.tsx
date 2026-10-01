'use client';

import { useActionState } from 'react';
import Link from 'next/link';
import { bulkApproveReadyAttendanceAction, type BulkApprovalState } from './actions';

type ReadyRow = { id: string; employee_code: string; full_name: string };
const initial: BulkApprovalState = { message: '', items: [] };

export function AttendanceBulkApprovalForm({ tenantId, date, rows }: { tenantId: string; date: string; rows: ReadyRow[] }) {
  const [state, action, pending] = useActionState(bulkApproveReadyAttendanceAction, initial);
  const labels = new Map(rows.map((row) => [row.id, `${row.full_name} · ${row.employee_code}`]));
  return <section className="attendance-bulk-panel" aria-labelledby="bulk-approval-title">
    <div className="work-policy-panel-heading">
      <h2 id="bulk-approval-title">اعتماد الأيام الجاهزة</h2>
      <p>يشمل الاعتماد الأيام المكتملة بلا استثناء فقط. يعاد فحص كل سجل قبل الحفظ؛ الحالات التي تغيّرت تُعرض كنتيجة منفصلة.</p>
    </div>
    <form action={action}>
      <input type="hidden" name="tenantId" value={tenantId} />
      <input type="hidden" name="operationalDate" value={date} />
      <ul className="attendance-bulk-list">
        {rows.map((row) => <li key={row.id}>
          <div className="attendance-bulk-choice"><label><input type="checkbox" name="instanceIds" value={row.id} />
            <span><strong>{row.full_name}</strong><small><bdi>{row.employee_code}</bdi></small></span>
          </label><Link className="secondary-button" href={`/tenant/${tenantId}/attendance/${row.id}`}>فتح السجل</Link></div>
        </li>)}
      </ul>
      <button className="primary-button" type="submit" disabled={pending}>{pending ? 'جارٍ التحقق والاعتماد…' : 'اعتماد السجلات المحددة'}</button>
    </form>
    {state.message && <div className="attendance-bulk-result" role="status" aria-live="polite">
      <p>{state.message}</p>
      {state.items.length > 0 && <ul>{state.items.map((item) => <li key={item.instance_id}>
        <span>{labels.get(item.instance_id) ?? 'سجل غير معروض في الصفحة'}</span>
        <strong>{item.state === 'approved' ? 'تم الاعتماد' : reasonLabel(item.reason_code)}</strong>
      </li>)}</ul>}
    </div>}
  </section>;
}

function reasonLabel(code?: string) {
  return code === 'leave_conflict_review_required' ? 'توجد إجازة معتمدة؛ راجع تعارض اليوم قبل اعتماد الحضور'
    : code === 'record_unavailable' ? 'السجل غير متاح في هذا اليوم'
    : code === 'access_changed' ? 'تغيّرت الصلاحية؛ لم يُعتمد السجل'
      : 'تغيّرت الحالة أو لم تعد مستوفية؛ راجع السجل';
}
