'use client';
import { useId, useState } from 'react';
import { Button, Input } from '@/components/ui';
import styles from './allocation-stepper.module.css';

const categories = [['ordinary_day', 'عادي نهاري'], ['ordinary_night', 'عادي ليلي'], ['weekly_rest', 'راحة أسبوعية'], ['official_holiday', 'عطلة رسمية']] as const;
export function AllocationStepper({ minutes }: { minutes: number }) {
  const id = useId();
  const [values, setValues] = useState<Record<string, string>>(Object.fromEntries(categories.map(([name]) => [name, '0'])));
  const total = Object.values(values).reduce((sum, value) => sum + (Number(value) || 0), 0);
  const remaining = minutes - total;
  return <fieldset className={styles.allocation}><legend>توزيع دقائق العمل الإضافي</legend>
    <div className={styles.summary} role="status"><strong>{minutes} دقيقة</strong><span>{remaining === 0 ? 'تم توزيع كامل الكمية' : remaining > 0 ? `متبقٍ ${remaining} دقيقة` : `زائد ${-remaining} دقيقة — عدّل التوزيع`}</span></div>
    {categories.map(([name, label]) => <div key={name} className={styles.row}><label htmlFor={`${id}-${name}`}>{label}</label><div className={styles.controls}>
      <Button variant="ghost" aria-label={`تقليل ${label} 15 دقيقة`} disabled={Number(values[name]) <= 0} onClick={event => { clearTotalError(event.currentTarget.form); setValues(current => ({ ...current, [name]: String(Math.max(0, Number(current[name]) - 15)) })); }}>−</Button>
      <Input id={`${id}-${name}`} name={name} type="number" min={0} max={minutes} step={1} required value={values[name]} onChange={event => setValues(current => ({ ...current, [name]: event.target.value }))} />
      <Button variant="ghost" aria-label={`زيادة ${label} حتى 15 دقيقة`} disabled={remaining <= 0} onClick={event => { clearTotalError(event.currentTarget.form); setValues(current => ({ ...current, [name]: String((Number(current[name]) || 0) + Math.min(15, remaining)) })); }}>+</Button>
    </div></div>)}
    <p>يمكن إدخال عدد الدقائق مباشرة. يجب توزيع الكمية كاملة قبل الاعتماد.</p>
  </fieldset>;
}
function clearTotalError(form: HTMLFormElement | null) {
  const field = form?.elements.namedItem('ordinary_day');
  if (field instanceof HTMLInputElement) field.setCustomValidity('');
}
