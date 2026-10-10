'use client';

import { Badge, Button } from '@/components/ui';
import { useState } from 'react';
import { formatDays, mappingStateClass, mappingStateLabel, type RequestDay } from '../../rules';
import styles from '../../review.module.css';

const DAY_PAGE_SIZE = 30;

export function DayBreakdown({ days, showMapping = false }: { days: RequestDay[]; showMapping?: boolean }) {
  const [page, setPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(days.length / DAY_PAGE_SIZE));
  const current = Math.min(page, totalPages);
  const from = (current - 1) * DAY_PAGE_SIZE + 1;
  const to = Math.min(days.length, current * DAY_PAGE_SIZE);
  const slice = days.slice(from - 1, to);
  const bases = new Set(days.map((day) => day.dayCountBasis));
  const [basis] = [...bases];
  const note = bases.size !== 1
    ? 'تحدد سياسة نوع الإجازة طريقة احتساب كل يوم.'
    : basis === 'calendar_days'
      ? 'أساس الاحتساب: مدة تقويمية — تُحتسب كل أيام الفترة، بما فيها الراحة والعطلات، وفق سياسة نوع الإجازة.'
      : 'أساس الاحتساب: أيام العمل فقط — أيام الراحة والعطلات لا تُحتسب.';

  return <div>
    <p className="field-hint">{note}</p>
    <ul className={styles.dayList}>
      {slice.map((day) => <li key={day.date}>
        <span>
          <bdi>{day.date}</bdi>
          {day.holidayName ? ` · ${day.holidayName}` : day.isWeeklyRest ? ' · راحة أسبوعية' : ''}
          {showMapping && day.isHalfDay
            ? <Badge className={`entity-status ${mappingStateClass(day.mappingState)}`}>
              {mappingStateLabel(day.mappingState)}</Badge>
            : null}
        </span>
        <span>{day.eligible ? `${formatDays(day.units)} يوم` : 'لا يُحتسب'}</span>
      </li>)}
    </ul>
    {totalPages > 1 && <nav className={styles.pagination} aria-label="صفحات تفاصيل أيام الطلب">
      <span role="status" aria-live="polite">صفحة {current} من {totalPages} · يوم {from}–{to} من {days.length}</span>
      <span className={styles.paginationNav}>
        <Button variant="ghost" type="button"  disabled={current <= 1}
          onClick={() => setPage(current - 1)}>السابق</Button>
        <Button variant="ghost" type="button"  disabled={current >= totalPages}
          onClick={() => setPage(current + 1)}>التالي</Button>
      </span>
    </nav>}
  </div>;
}
