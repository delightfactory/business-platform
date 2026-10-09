'use client';

import { useRef, useState, useSyncExternalStore, type ReactNode } from 'react';
import * as Tabs from '@radix-ui/react-tabs';
import { Icon, type IconName } from '@/components/ui';
import styles from './profile-tabs.module.css';

export type ProfileArea = 'overview' | 'work' | 'compensation' | 'account' | 'employment';
type Area = { value: ProfileArea; label: string; content: ReactNode };
const areaIcons: Record<ProfileArea, IconName> = { overview: 'user', work: 'building', compensation: 'wallet', account: 'shield', employment: 'file' };
const subscribe = () => () => {};

export function EmployeeProfileTabs({ initialTab, areas }: { initialTab: ProfileArea; areas: Area[] }) {
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
    setSelected(value as ProfileArea);
  }

  return <Tabs.Root ref={root} value={selected} onValueChange={selectArea} dir="rtl" activationMode="manual">
    <Tabs.List className={styles.tabList} aria-label="أقسام ملف الموظف" hidden={!ready}>
      {areas.map((area) => <Tabs.Trigger className={styles.tab} key={area.value} value={area.value}>
        <Icon name={areaIcons[area.value]} size={17} />{area.label}
      </Tabs.Trigger>)}
    </Tabs.List>
    <p className={styles.notice} role="status" aria-live="polite">{notice}</p>
    {areas.map((area) => <Tabs.Content className={styles.panel} key={area.value} value={area.value}
      forceMount hidden={ready && selected !== area.value}>
      {area.content}
    </Tabs.Content>)}
  </Tabs.Root>;
}
