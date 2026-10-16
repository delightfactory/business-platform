import type { ReadinessItem } from '@/components/patterns/readiness-list/ReadinessList';

/** Follow dependencies; an unread or waiting step must not be skipped for a later task. */
export function readinessFocus(items: ReadinessItem[]) {
  return {
    current: items.find(item => item.state !== 'done') ?? null,
    saved: items.filter(item => item.state === 'done').length,
    unknown: items.filter(item => item.state === 'unknown').length,
    total: items.length,
  };
}
