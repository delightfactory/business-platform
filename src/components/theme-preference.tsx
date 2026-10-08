'use client';

import { createContext, useContext, useState, type ReactNode } from 'react';
import type { ThemePreference } from '@/lib/theme';

const ThemeContext = createContext<{
  preference: ThemePreference;
  change: (value: ThemePreference) => void;
  message: string;
} | null>(null);

export function ThemeProvider({ initialPreference, children }: {
  initialPreference: ThemePreference;
  children: ReactNode;
}) {
  const [preference, setPreference] = useState(initialPreference);
  const [message, setMessage] = useState('');

  function change(value: ThemePreference) {
    // Change appearance without navigation, remounting or submitting a work form.
    document.documentElement.dataset.theme = value;
    setPreference(value);
    try {
      document.cookie = `bp-theme=${value}; Path=/; SameSite=Lax${location.protocol === 'https:' ? '; Secure' : ''}`;
      const saved = document.cookie.split(';').some(part => part.trim() === `bp-theme=${value}`);
      setMessage(saved ? '' : 'تغيّر المظهر هنا، لكن تعذر حفظ الاختيار. قد يعود المظهر السابق عند فتح الصفحة مجددًا.');
    } catch {
      setMessage('تغيّر المظهر هنا، لكن تعذر حفظ الاختيار. قد يعود المظهر السابق عند فتح الصفحة مجددًا.');
    }
  }

  return <ThemeContext.Provider value={{ preference, change, message }}>{children}</ThemeContext.Provider>;
}

export function ThemePreferenceControl() {
  const context = useContext(ThemeContext);
  if (!context) return null;
  const choices: { value: ThemePreference; label: string }[] = [
    { value: 'light', label: 'فاتح' },
    { value: 'dark', label: 'داكن' },
    { value: 'system', label: 'حسب الجهاز' },
  ];
  return <fieldset className="theme-preference">
    <legend>مظهر المنصة</legend>
    <div className="theme-preference-options">
      {choices.map(choice => <button key={choice.value} type="button"
        aria-pressed={context.preference === choice.value} onClick={() => context.change(choice.value)}>
        {choice.label}
      </button>)}
    </div>
    {context.message && <p role="status">{context.message}</p>}
    <noscript><p>يمكنك متابعة العمل بالمظهر الحالي. تغيير المظهر يحتاج JavaScript.</p></noscript>
  </fieldset>;
}
