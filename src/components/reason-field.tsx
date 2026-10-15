import type { ComponentProps } from 'react';
import { Field, Input } from '@/components/ui';

// Suggested reasons are visible and editable; callers only use them for initial setup.
export function ReasonField({ id, label, suggested = false, ...props }: Omit<ComponentProps<typeof Input>, 'id' | 'name' | 'required' | 'minLength' | 'maxLength'> & { id: string; label: string; suggested?: boolean }) {
  return <Field id={id} label={label} required hint={suggested ? 'سبب مقترح يمكنك تعديله قبل الحفظ.' : undefined}>
    <Input name="reason" required minLength={3} maxLength={500} {...props} />
  </Field>;
}
