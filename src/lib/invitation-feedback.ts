export function invitationReviewMessage(state?: string) {
  if (typeof state !== 'string') return null;
  const messages: Record<string, string> = {
    'created-sent': 'راجع حالة الدعوة والإرسال أدناه. وصول البريد وقبول الدعوة يحتاجان تحققًا منفصلًا.',
    'reissued-sent': 'راجع حالة الدعوة والإرسال أدناه قبل استخدام رابط أو إعادة الإرسال.',
    revoked: 'راجع الحالة الحالية للدعوة أدناه للتأكد من الإلغاء.',
  };
  return Object.hasOwn(messages, state) ? messages[state] : null;
}
