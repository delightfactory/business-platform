import { ARABIC_DISPLAY_LOCALE } from './display-locale';

export const MIN_ATTENDANCE_MONTH = '2000-01';
export const MAX_ATTENDANCE_MONTH = '2100-12';
export const attendanceStates = [
  { key: 'needs_review', label: 'يحتاج مراجعة', symbol: '!', tone: 'review' },
  { key: 'ready', label: 'جاهز للمراجعة', symbol: '◐', tone: 'ready' },
  { key: 'open', label: 'قيد المتابعة', symbol: '○', tone: 'open' },
  { key: 'approved', label: 'معتمد', symbol: '✓', tone: 'approved' },
] as const;
export type AttendanceState = typeof attendanceStates[number]['key'];
export type CalendarDay = { date: string } & Record<AttendanceState, number>;
export type MonthCalendar = { month: string; days: CalendarDay[] };

export function isCivilDate(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || value.startsWith('0000')) return false;
  const parsed = new Date(`${value}T12:00:00Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0,10) === value;
}
export function isAttendanceMonth(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(value)
    && value >= MIN_ATTENDANCE_MONTH && value <= MAX_ATTENDANCE_MONTH;
}
export function cairoToday() {
  return new Intl.DateTimeFormat('en-CA',{ timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit' }).format(new Date());
}
export function adjacentDay(day: string, delta: -1 | 1): string | null {
  if (!isCivilDate(day)) return null;
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate()+delta);
  const result = date.toISOString().slice(0,10);
  return isCivilDate(result) ? result : null;
}
export function adjacentMonth(month: string, delta: -1 | 1): string | null {
  if (!isAttendanceMonth(month)) return null;
  const date = new Date(`${month}-01T12:00:00Z`);
  date.setUTCMonth(date.getUTCMonth()+delta);
  const result = date.toISOString().slice(0,7);
  return isAttendanceMonth(result) ? result : null;
}
export function calendarWeeks(month: string): (string | null)[][] {
  if (!isAttendanceMonth(month)) return [];
  const first = new Date(`${month}-01T12:00:00Z`);
  const offset = (first.getUTCDay()+1)%7; // Saturday first; no rest-day inference.
  const last = new Date(first); last.setUTCMonth(last.getUTCMonth()+1); last.setUTCDate(0);
  const cells: (string | null)[] = Array.from({ length: offset },()=>null);
  for (let n=1;n<=last.getUTCDate();n++) cells.push(`${month}-${String(n).padStart(2,'0')}`);
  while (cells.length%7) cells.push(null);
  return Array.from({length:cells.length/7},(_,n)=>cells.slice(n*7,n*7+7));
}
export function calendarDateLabel(day: string) {
  return new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE,{weekday:'long',day:'numeric',month:'long',year:'numeric',timeZone:'UTC'}).format(new Date(`${day}T12:00:00Z`));
}
export function calendarMonthLabel(month: string) {
  return new Intl.DateTimeFormat(ARABIC_DISPLAY_LOCALE,{month:'long',year:'numeric',timeZone:'UTC'}).format(new Date(`${month}-01T12:00:00Z`));
}
export function dayTotal(day: CalendarDay) {
  return attendanceStates.reduce((total,state)=>total+day[state.key],0);
}
export function dayCountLabel(day: CalendarDay | undefined) {
  return day ? attendanceStates.filter(state=>day[state.key]>0).map(state=>`${day[state.key]} ${state.label}`).join('، ') : 'لا سجلات محفوظة';
}
export function readMonthCalendar(value: unknown, month: string): MonthCalendar | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const payload=value as Record<string,unknown>;
  if (payload.month!==month || !isAttendanceMonth(month) || !Array.isArray(payload.days) || payload.days.length>31) return null;
  const days: CalendarDay[]=[]; const seen=new Set<string>();
  for (const entry of payload.days) {
    if (!entry || typeof entry!=='object' || Array.isArray(entry)) return null;
    const row=entry as Record<string,unknown>;
    if (!isCivilDate(row.date) || row.date.slice(0,7)!==month || seen.has(row.date)) return null;
    if (attendanceStates.some(({key})=>!Number.isSafeInteger(row[key]) || Number(row[key])<0)) return null;
    const day={date:row.date,open:Number(row.open),ready:Number(row.ready),needs_review:Number(row.needs_review),approved:Number(row.approved)};
    if (!Number.isSafeInteger(dayTotal(day)) || dayTotal(day)===0) return null;
    seen.add(row.date); days.push(day);
  }
  return {month,days:days.sort((a,b)=>a.date.localeCompare(b.date))};
}
