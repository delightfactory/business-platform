'use client';

import type { ComponentProps } from 'react';
import { OfflineForm } from '@/components/offline-form';

const categoryNames = ['ordinary_day', 'ordinary_night', 'weekly_rest', 'official_holiday'];

export function OvertimeClassificationForm({ candidateMinutes, ...props }: Omit<ComponentProps<'form'>, 'onSubmit' | 'onInput'> & { candidateMinutes: number }) {
  return <OfflineForm {...props}
    onInput={(event) => {
      const input = event.target;
      if (input instanceof HTMLInputElement && categoryNames.includes(input.name)) {
        const firstCategory = event.currentTarget.elements.namedItem('ordinary_day');
        if (firstCategory instanceof HTMLInputElement) firstCategory.setCustomValidity('');
      }
    }}
    onSubmit={(event) => {
      const form = event.currentTarget;
      const data = new FormData(form);
      const minutes = categoryNames.map((name) => Number(data.get(name)));
      // Native constraints and the server retain authority over invalid fields.
      if (!minutes.every((value) => Number.isSafeInteger(value) && value >= 0) || !Number.isSafeInteger(candidateMinutes)) return;
      const total = minutes.reduce((sum, value) => sum + value, 0);
      if (total === candidateMinutes) return;
      event.preventDefault();
      const firstCategory = form.elements.namedItem('ordinary_day');
      if (firstCategory instanceof HTMLInputElement) {
        firstCategory.setCustomValidity(`المجموع الحالي ${total} دقيقة؛ يجب أن يساوي ${candidateMinutes} دقيقة بالضبط. عدّل الفئات.`);
        firstCategory.reportValidity();
      }
    }}
  />;
}
