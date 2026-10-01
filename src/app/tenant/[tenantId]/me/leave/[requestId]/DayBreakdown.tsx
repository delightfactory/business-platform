'use client';

import { useState } from 'react';
import { dayCountBasisLabel, type RequestDay } from '../form-rules';
import { formatDays } from '../states';
import styles from '../leave.module.css';

const DAY_PAGE_SIZE = 30;

export function DayBreakdown({ days }: { days: RequestDay[] }) {
  const [page, setPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(days.length / DAY_PAGE_SIZE));
  const current = Math.min(page, totalPages);
  const from = (current - 1) * DAY_PAGE_SIZE + 1;
  const to = Math.min(days.length, current * DAY_PAGE_SIZE);
  const slice = days.slice(from - 1, to);
  const bases = new Set(days.map((day) => day.day_count_basis));
  const [basis] = [...bases];
  const note = bases.size !== 1
    ? 'تحدد سياسة نوع الإجازة طريقة احتساب كل يوم.'
    : basis === 'calendar_days'
      ? `أساس الاحتساب: ${dayCountBasisLabel('calendar_days')} — تُحتسب كل أيام الفترة، بما فيها الراحة والعطلات، وفق سياسة نوع الإجازة.`
      : `أساس الاحتساب: ${dayCountBasisLabel('working_days')} — تُحتسب أيام العمل فقط؛ أيام الراحة والعطلات لا تُحتسب.`;

  return <div>
    <p className="field-hint">{note}</p>
    <ul className={styles.dayList}>
      {slice.map((day) => <li key={day.date}>
        <span><bdi>{day.date}</bdi>{day.holiday_name ? ` · ${day.holiday_name}` : day.is_weekly_rest ? ' · راحة أسبوعية' : ''}</span>
        <span>{day.eligible ? `${formatDays(day.units)} يوم` : 'لا يُحتسب'}</span>
      </li>)}
    </ul>
    {totalPages > 1 && <nav className={styles.pagination} aria-label="صفحات تفاصيل أيام الطلب">
      <span role="status" aria-live="polite">صفحة {current} من {totalPages} · يوم {from}–{to} من {days.length}</span>
      <span className={styles.paginationNav}>
        <button type="button" className="secondary-button" disabled={current <= 1}
          onClick={() => setPage(current - 1)}>السابق</button>
        <button type="button" className="secondary-button" disabled={current >= totalPages}
          onClick={() => setPage(current + 1)}>التالي</button>
      </span>
    </nav>}
  </div>;
}
