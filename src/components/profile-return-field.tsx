export function ProfileReturnField({ value, name = 'profileReturn' }: { value?: string | null; name?: 'profileReturn' | 'return' }) {
  return value ? <input type="hidden" name={name} value={value} /> : null;
}
