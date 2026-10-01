'use client';

import { useState } from 'react';
import { MAX_HOLIDAY_ROWS, MAX_NAME_LENGTH, WEEKDAY_LABELS, type HolidayRow } from './rules';
import styles from './settings.module.css';

export function CalendarRuleFields({
  idPrefix,
  restDays,
  holidays,
  disabled,
}: {
  idPrefix: string;
  restDays: number[];
  holidays: HolidayRow[];
  disabled: boolean;
}) {
  const [rows, setRows] = useState<HolidayRow[]>(() => holidays);

  function addRow() {
    if (rows.length >= MAX_HOLIDAY_ROWS) return;
    setRows([...rows, { date: '', name: '' }]);
  }

  function removeRow(index: number) {
    setRows(rows.filter((_, position) => position !== index));
  }

  function updateRow(index: number, patch: Partial<HolidayRow>) {
    setRows(rows.map((row, position) => (position === index ? { ...row, ...patch } : row)));
  }

  return <>
    <fieldset className={styles.optionGroup} disabled={disabled}>
      <legend>أيام الراحة الأسبوعية</legend>
      <p className={styles.optionGroupHint}>تُستثنى الأيام المحددة من احتساب أيام العمل في التقويم. لا يوجد عدد إلزامي؛ اختر ما يناسب سياسة شركتك.</p>
      <div className={styles.optionGrid}>
        {WEEKDAY_LABELS.map((label, day) => (
          <label className={styles.option} key={day}>
            <input type="checkbox" name="restDay" value={day} defaultChecked={restDays.includes(day)} />
            <span>{label}</span>
          </label>
        ))}
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={disabled}>
      <legend>العطلات</legend>
      <p className={styles.optionGroupHint}>كل عطلة صف مستقل بتاريخها واسمها ضمن فترة سريان التقويم (بحد أقصى {MAX_HOLIDAY_ROWS} عطلة في الإصدار).</p>
      <div className={styles.holidayRows}>
        {rows.map((row, index) => (
          <div className={styles.holidayRow} key={index}>
            <label className={styles.visuallyHidden} htmlFor={`${idPrefix}-holiday-date-${index}`}>
              {`تاريخ العطلة رقم ${index + 1}`}
            </label>
            <input
              id={`${idPrefix}-holiday-date-${index}`}
              name="holidayDate"
              type="date"
              value={row.date}
              onChange={(event) => updateRow(index, { date: event.target.value })}
            />
            <label className={styles.visuallyHidden} htmlFor={`${idPrefix}-holiday-name-${index}`}>
              {`اسم العطلة رقم ${index + 1}`}
            </label>
            <input
              id={`${idPrefix}-holiday-name-${index}`}
              name="holidayName"
              type="text"
              maxLength={MAX_NAME_LENGTH}
              placeholder="اسم العطلة"
              value={row.name}
              onChange={(event) => updateRow(index, { name: event.target.value })}
            />
            <button className="secondary-button" type="button" onClick={() => removeRow(index)}>
              إزالة
            </button>
          </div>
        ))}
      </div>
      <div className={styles.rowActions}>
        <button className="secondary-button" type="button" onClick={addRow}
          disabled={rows.length >= MAX_HOLIDAY_ROWS}>
          إضافة عطلة
        </button>
        <span className="field-hint">{rows.length === 0 ? 'لا توجد عطلات محددة بعد.' : `${rows.length} صف${rows.length === 1 ? '' : ' عطلة'}.`}</span>
      </div>
    </fieldset>
  </>;
}
