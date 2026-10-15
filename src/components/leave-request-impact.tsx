'use client';

import { useEffect, useRef, useState } from 'react';
import { loadLeaveImpact } from '@/app/tenant/[tenantId]/leave/impact-actions';
import { leaveImpactSignature, type LeaveImpactInput, type LeaveImpactResult } from '@/lib/leave-impact';
import { formatDecimalAmount } from '@/lib/format-decimal-amount';
import { Button, Disclosure, Message } from '@/components/ui';

const reasons: Record<string,string> = {
  type: 'نوع الإجازة لم يعد متاحًا لهذه الفترة.', year_period: 'سنة الإجازات غير معدّة لبعض التواريخ؛ راجع مسؤول الإجازات.',
  calendar: 'تقويم الإجازات غير مكتمل لهذه الفترة.', type_version: 'سياسة النوع لا تغطي كل التواريخ.',
  half_day_not_allowed: 'هذا النوع لا يسمح بنصف يوم.', half_day_ineligible: 'التاريخ المختار لا يُحتسب كنصف يوم إجازة.',
  zero_days: 'التواريخ المختارة لا تتضمن أيام إجازة محتسبة وفق السياسة.',
  forbidden: 'لا تملك صلاحية عرض أثر هذا الطلب.', session: 'انتهت الجلسة؛ سجّل الدخول ثم راجع الأثر.',
};

export function LeaveRequestImpact(input: LeaveImpactInput) {
  return <RequestImpact key={leaveImpactSignature(input)} {...input} />;
}

function RequestImpact(input: LeaveImpactInput) {
  const signature = leaveImpactSignature(input), sequence = useRef(0);
  const [result,setResult] = useState<LeaveImpactResult | null>(null), [retry,setRetry] = useState(0);
  const { tenantId,typeId,start,end,halfDay,part,employeeId,employmentId } = input;
  useEffect(() => {
    const request = ++sequence.current;
    if (!typeId || !start || !end) return;
    let cancelled = false;
    const frame = requestAnimationFrame(() => {
      void loadLeaveImpact({ tenantId,typeId,start,end,halfDay,part,employeeId,employmentId }).then(value => {
        if (!cancelled && request === sequence.current && value.signature === signature) setResult(value);
      }).catch(() => {
        if (!cancelled && request === sequence.current) setResult({signature,impact:{state:'unavailable',reason:'connection'}});
      });
    });
    return () => { cancelled=true; cancelAnimationFrame(frame); };
  },[tenantId,typeId,start,end,halfDay,part,employeeId,employmentId,signature,retry]);
  if (!typeId || !start || !end) return null;
  const impact = result?.signature === signature ? result.impact : null;
  const amount = (value: string) => <bdi>{formatDecimalAmount(value)}</bdi>;
  return <section aria-label="الرصيد وأثر طلب الإجازة" aria-busy={!impact}>
    <h3>الرصيد وأثر الطلب</h3>
    {!impact ? <p role="status">يُحسب الأثر…</p> : impact.state === 'unavailable' ? <Message tone="info">
      <p>{reasons[impact.reason ?? ''] ?? 'تعذر التحقق من الأثر الآن. يمكنك متابعة الإرسال؛ صفحة تفاصيل الطلب تعرض الحساب المحفوظ.'}</p>
      <Button type="button" variant="ghost" onClick={() => { setResult(null);setRetry(value=>value+1); }}>إعادة حساب الأثر</Button>
    </Message> : <>
      <p>يُحتسب {amount(impact.total_units!)} يوم.</p>
      {impact.balance?.state === 'shown' ? <>
        <p>المتاح من الحسابات المؤهلة للفترة: {amount(impact.balance.available_days!)} يوم.</p>
        {impact.balance.accounts?.length ? <Disclosure summary="الرصيد حسب الفترة"><ul>{impact.balance.accounts.map((account,index)=><li key={index}>{account.period_label}: {amount(account.balance_days)} يوم <span>({account.starts_on} إلى {account.ends_on})</span></li>)}</ul></Disclosure> : <p>لا يوجد رصيد مسجل لهذا النوع.</p>}
        {impact.balance.shortfall_days !== '0.00' ? <Message tone="info">الرصيد الحالي لا يغطي {amount(impact.balance.shortfall_days!)} يوم في تواريخ الطلب؛ قد يتعذر اعتماده ما لم يُعدّل الرصيد.</Message>
          : <p>بعد الاعتماد يبقى {amount(impact.balance.after_approval_days!)} يوم.</p>}
      </> : <p>{impact.balance?.state === 'not_tracked' ? 'هذا النوع لا يُخصم من الرصيد.' : impact.balance?.state === 'hidden' ? 'لا تسمح صلاحيتك الحالية بعرض الرصيد. راجع مسؤول الإجازات.' : 'تعذر التحقق من الرصيد.'}</p>}
      <Disclosure summary="كيف احتُسبت الأيام؟"><ul>{impact.days?.map(day=><li key={day.date}><bdi>{day.date}</bdi>: {amount(day.units)} يوم · {day.eligible ? day.pay_effect === 'paid' ? 'مدفوع' : 'غير مدفوع' : day.holiday_name ?? (day.is_weekly_rest ? 'راحة أسبوعية' : 'غير محتسب')}{day.halfday_state === 'review_required' ? ' · إعداد نصف اليوم يحتاج مراجعة' : ''}</li>)}</ul></Disclosure>
    </>}
    <p className="field-hint">الطلبات المعلّقة الأخرى لا تحجز رصيدًا. يتأكد احتساب الأيام عند الإرسال؛ ويُخصم الرصيد عند الاعتماد بعد مراجعة البيانات الحالية.</p>
  </section>;
}
