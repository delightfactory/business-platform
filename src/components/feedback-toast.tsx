'use client';

import { useEffect, useState } from 'react';
import { Icon } from './ui/icon';

export function FeedbackToast({ message }: { message: string | null }) {
  const [visible, setVisible] = useState(true);
  useEffect(() => {
    if (!message) return;
    const timeout = window.setTimeout(() => setVisible(false), 5000);
    return () => window.clearTimeout(timeout);
  }, [message]);
  if (!message || !visible) return null;
  return <div className="ui-toast" role="status" aria-live="polite" aria-atomic="true">
    <span>{message}</span>
    <button type="button" onClick={() => setVisible(false)} aria-label="إغلاق الإشعار"><Icon name="close" size={16} /></button>
  </div>;
}
