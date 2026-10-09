'use client';

import { Button, Checkbox, Input } from '@/components/ui';
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
      <p className={styles.optionGroupHint}>اختر أيام الراحة حسب سياسة الشركة. لا تُحسب ضمن أيام العمل، ولا يلزم اختيار عدد محدد.</p>
      <div className={styles.optionGrid}>
        {WEEKDAY_LABELS.map((label, day) => (
          <label className={styles.option} key={day}>
            <Checkbox  name="restDay" value={day} defaultChecked={restDays.includes(day)} />
            <span>{label}</span>
          </label>
        ))}
      </div>
    </fieldset>

    <fieldset className={styles.optionGroup} disabled={disabled}>
      <legend>العطلات</legend>
      <p className={styles.optionGroupHint}>أضف اسم كل عطلة وتاريخها ضمن فترة التقويم، حتى {MAX_HOLIDAY_ROWS} عطلة لكل مجموعة إعدادات.</p>
      <div className={styles.holidayRows}>
        {rows.map((row, index) => (
          <div className={styles.holidayRow} key={index}>
            <label className={styles.visuallyHidden} htmlFor={`${idPrefix}-holiday-date-${index}`}>
              {`تاريخ العطلة رقم ${index + 1}`}
            </label>
            <Input
              id={`${idPrefix}-holiday-date-${index}`}
              name="holidayDate"
              type="date"
              value={row.date}
              onChange={(event) => updateRow(index, { date: event.target.value })}
            />
            <label className={styles.visuallyHidden} htmlFor={`${idPrefix}-holiday-name-${index}`}>
              {`اسم العطلة رقم ${index + 1}`}
            </label>
            <Input
              id={`${idPrefix}-holiday-name-${index}`}
              name="holidayName"
              type="text"
              maxLength={MAX_NAME_LENGTH}
              placeholder="اسم العطلة"
              value={row.name}
              onChange={(event) => updateRow(index, { name: event.target.value })}
            />
            <Button variant="ghost"  type="button" onClick={() => removeRow(index)}>
              إزالة
            </Button>
          </div>
        ))}
      </div>
      <div className={styles.rowActions}>
        <Button variant="ghost"  type="button" onClick={addRow}
          disabled={rows.length >= MAX_HOLIDAY_ROWS}>
          إضافة عطلة
        </Button>
        <span className="field-hint">{rows.length === 0 ? 'لا توجد عطلات محددة بعد.' : `${rows.length} صف${rows.length === 1 ? '' : ' عطلة'}.`}</span>
      </div>
    </fieldset>
  </>;
}
