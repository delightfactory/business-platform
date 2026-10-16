'use client';

import { useRef, useState, useSyncExternalStore, type ReactNode } from 'react';
import * as Tabs from '@radix-ui/react-tabs';
import { useRouter } from 'next/navigation';
import { Icon, type IconName } from '@/components/ui';
import styles from './profile-tabs.module.css';

export type ProfileArea = 'overview' | 'work' | 'compensation' | 'account' | 'employment' | 'attendance' | 'leave' | 'payroll' | 'advances';
type Area = { value: ProfileArea; label: string; content: ReactNode; href?: string };
const areaIcons: Record<ProfileArea, IconName> = { overview: 'user', work: 'building', compensation: 'wallet', account: 'shield', employment: 'file', attendance: 'clock', leave: 'calendar', payroll: 'wallet', advances: 'wallet' };
const subscribe = () => () => {};

export function EmployeeProfileTabs({ initialTab, areas, baseHref }: { initialTab: ProfileArea; areas: Area[]; baseHref: string }) {
  const router = useRouter();
  const [selected, setSelected] = useState(initialTab);
  const [notice, setNotice] = useState('');
  const root = useRef<HTMLDivElement>(null);
  const ready = useSyncExternalStore(subscribe, () => true, () => false);

  function selectArea(value: string) {
    if (!areas.some((area) => area.value === value)) return;
    const active = root.current?.querySelector('[role="tabpanel"][data-state="active"]');
    if (active?.querySelector('[aria-busy="true"]')) {
      setNotice('انتظر ظهور نتيجة العملية قبل الانتقال إلى قسم آخر.');
      return;
    }
    setNotice('');
    const destination = areas.find(area => area.value === value)?.href;
    if (destination) { setNotice('جارٍ تحميل السجل…'); router.push(destination); return; }
    setSelected(value as ProfileArea);
    const url = new URL(window.location.href);
    url.searchParams.set('tab', value);
    url.searchParams.delete('activityAfter');
    window.history.replaceState(null, '', url.pathname + url.search + url.hash);
  }

  return <Tabs.Root ref={root} value={selected} onValueChange={selectArea} dir="rtl" activationMode="manual">
    <noscript><nav aria-label="أقسام ملف الموظف">{areas.map(area => <a key={area.value} href={`${baseHref}${baseHref.includes('?') ? '&' : '?'}tab=${area.value}`}>{area.label} </a>)}</nav></noscript>
    <Tabs.List className={styles.tabList} aria-label="أقسام ملف الموظف" hidden={!ready}>
      {areas.map((area) => <Tabs.Trigger className={styles.tab} key={area.value} value={area.value}>
        <Icon name={areaIcons[area.value]} size={17} />{area.label}
      </Tabs.Trigger>)}
    </Tabs.List>
    <p className={styles.notice} role="status" aria-live="polite">{notice}</p>
    {areas.map((area) => <Tabs.Content className={styles.panel} key={area.value} value={area.value}
      forceMount hidden={selected !== area.value}>
      {area.content}
    </Tabs.Content>)}
  </Tabs.Root>;
}
