'use client';

import { useRef, useState } from 'react';
import { Button, Disclosure, Icon } from '@/components/ui';
import styles from './attendance-pass.module.css';

export function SlideToConfirm({ label, disabled, onConfirm }: { label: string; disabled: boolean; onConfirm: () => void }) {
  const [progress, setProgress] = useState(0);
  const [hint, setHint] = useState(false);
  const origin = useRef<number | null>(null);
  function confirm() {
    if (disabled) return;
    setProgress(0);
    setHint(false);
    onConfirm();
  }
  return <div className={styles.confirm}>
    <div className={styles.slide}>
      <span aria-hidden="true"><Icon name="arrowLeft" /> اسحب لتأكيد {label}</span>
      <input type="range" min={0} max={100} value={progress} disabled={disabled}
        aria-label={`تأكيد ${label}: اسحب المقبض حتى النهاية أو اضغط Enter أو المسافة`}
        aria-valuetext={`${progress}%`} onChange={event => setProgress(Number(event.target.value))}
        onPointerDown={event => { origin.current = event.clientX; }}
        onPointerCancel={() => { origin.current = null; setProgress(0); }}
        onPointerUp={event => {
          const travel = origin.current === null ? 0 : origin.current - event.clientX;
          const required = Math.max(1, event.currentTarget.clientWidth - 56) * .8;
          origin.current = null;
          if (travel >= required) confirm();
          else { setProgress(0); setHint(true); }
        }}
        onKeyDown={event => {
          if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); confirm(); }
        }} />
    </div>
    {hint && <p className={styles.hint} role="status">اسحب المقبض من اليمين إلى النهاية. النقر وحده لا يسجّل الحركة.</p>}
    <Disclosure summary="طريقة أخرى للتأكيد" className={styles.alternative}>
      <p>اضغط زر التأكيد لتسجيل {label}.</p>
      <Button disabled={disabled} onClick={confirm} icon="check">تأكيد {label}</Button>
    </Disclosure>
  </div>;
}
