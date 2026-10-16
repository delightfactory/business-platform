export const retentionUnits = [
  { value: 'days', label: 'يوم', seconds: 86400 },
  { value: 'hours', label: 'ساعة', seconds: 3600 },
  { value: 'minutes', label: 'دقيقة', seconds: 60 },
  { value: 'seconds', label: 'ثانية', seconds: 1 },
] as const;

export function retentionSeconds(amount: string, unit: string): number | null {
  const factor = retentionUnits.find(item => item.value === unit)?.seconds;
  if (!factor || !/^\d+$/.test(amount.trim())) return null;
  const seconds = Number(amount) * factor;
  return Number.isSafeInteger(seconds) && seconds >= 60 && seconds <= 2592000 ? seconds : null;
}

export function displayRetention(seconds?: number) {
  if (seconds === undefined) return { amount: '', unit: 'days' };
  const unit = retentionUnits.find(item => Number.isInteger(seconds / item.seconds)) ?? retentionUnits[3];
  return { amount: String(seconds / unit.seconds), unit: unit.value };
}
