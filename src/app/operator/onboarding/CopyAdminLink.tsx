'use client';
import { useState } from 'react';
import { Button, ButtonLink } from '@/components/ui';
export function CopyAdminLink({ href }: { href: string }) {
  const [state, setState] = useState<'idle' | 'copied' | 'failed'>('idle');
  return <div><Button variant="ghost" onClick={async () => {
    try { await navigator.clipboard.writeText(new URL(href, window.location.origin).toString()); setState('copied'); }
    catch { setState('failed'); }
  }}>نسخ رابط دخول المسؤول</Button>
    {state === 'copied' && <p role="status" className="field-hint">نُسخ الرابط. يتطلب الدخول حساب المسؤول المُعيّن.</p>}
    {state === 'failed' && <p role="status" className="field-hint">تعذر النسخ. <ButtonLink variant="ghost" href={href}>فتح رابط دخول المسؤول</ButtonLink></p>}
  </div>;
}
