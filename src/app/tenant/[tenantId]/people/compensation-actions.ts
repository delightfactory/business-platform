'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type CompensationFormState = {
  tenantId: string; employmentId: string; employeeId: string; amount: string; effectiveDate: string;
  error: string; attempt: number;
};

export async function changeCompensationAction(
  previous: CompensationFormState,
  formData: FormData,
): Promise<CompensationFormState> {
  const next: CompensationFormState = {
    tenantId: field(formData, 'tenantId'), employmentId: field(formData, 'employmentId'),
    employeeId: field(formData, 'employeeId'), amount: field(formData, 'amount'),
    effectiveDate: field(formData, 'effectiveDate'), error: '', attempt: previous.attempt + 1,
  };
  const fail = (message: string) => ({ ...next, error: message });
  if (![next.tenantId, next.employmentId, next.employeeId].every(isUuid)
      || !/^\d{4}-\d{2}-\d{2}$/.test(next.effectiveDate)
      || !/^\d{1,12}(\.\d{1,2})?$/.test(next.amount)
      || Number(next.amount) > 999999999999.99) {
    return fail('راجع قيمة الأجر وتاريخ السريان ثم أعد المحاولة.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الخدمة غير متاحة الآن. أعد المحاولة؛ بقيت البيانات التي أدخلتها محفوظة.');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.');
  const { data, error } = await supabase.rpc('change_people_compensation', {
    p_tenant_id: next.tenantId,
    p_employment_id: next.employmentId,
    p_effective_date: next.effectiveDate,
    p_amount: next.amount,
  });
  if (error) return fail(compensationError(error.message));
  const reply = data && typeof data === 'object' && !Array.isArray(data)
    ? data as Record<string, unknown> : null;
  if (reply?.state !== 'changed' && reply?.state !== 'scheduled'
      && reply?.state !== 'corrected' && reply?.state !== 'initial_corrected') {
    return fail('تعذر تأكيد حفظ الأجر. حدّث سجل الأجر قبل إعادة المحاولة.');
  }
  redirect(`/tenant/${next.tenantId}/people/${next.employeeId}?compensation=${reply.state}`);
}

export async function cancelCompensationChangeAction(formData: FormData): Promise<void> {
  const tenantId = field(formData, 'tenantId');
  const employmentId = field(formData, 'employmentId');
  const employeeId = field(formData, 'employeeId');
  const versionId = field(formData, 'versionId');
  if (![tenantId, employmentId, employeeId, versionId].every(isUuid)) redirect('/tenant');
  const profilePath = `/tenant/${tenantId}/people/${employeeId}`;
  const supabase = await createSupabaseServerClient();
  if (!supabase) redirect(`${profilePath}?compensation=cancel-error`);
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(profilePath)}`);
  const { error } = await supabase.rpc('cancel_people_compensation_change', {
    p_tenant_id: tenantId, p_employment_id: employmentId, p_version_id: versionId,
  });
  if (error) redirect(`${profilePath}?compensation=cancel-error`);
  redirect(`${profilePath}?compensation=cancelled`);
}

function field(formData: FormData, name: string) { return String(formData.get(name) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }

function compensationError(message: string) {
  if (message.includes('lock timeout') || message.includes('deadlock detected')) return 'هناك إجراء جارٍ على مصادر الرواتب. البيانات محفوظة؛ أعد المحاولة بعد اكتماله.';
  if (message.includes('payroll_people_correction_required')) return 'يمس هذا التغيير فترة راتب مقفلة. لم تتغير البيانات؛ راجع مسؤول تصحيح الرواتب لإعداد مقترح التصحيح بتاريخ سريان محدد ومراجعة المسيرات المحفوظة المتأثرة للفترة نفسها.';
  if (message.includes('compensation_manage_forbidden')) return 'تحتاج إلى صلاحية إدارة الأجر الأساسي في هذه الشركة.';
  if (message.includes('people_compensation_backdate_outside_current_version')) return 'التاريخ السابق لا يقع ضمن الأجر الساري حاليًا. يمكن تعديل الأجر من بداية النسخة الحالية فقط.';
  if (message.includes('people_compensation_future_exists')) return 'يوجد تغيير أجر مقرر بالفعل. ألغِه قبل حفظ تغيير آخر.';
  if (message.includes('people_compensation_current_missing')) return 'لا يوجد أجر سارٍ اليوم يمكن تغييره لهذه العلاقة.';
  if (message.includes('people_compensation_before_current_start')) return 'اختر تاريخًا بعد بداية الأجر الحالي.';
  if (message.includes('people_compensation_employment_inactive')) return 'لا يمكن تغيير الأجر بعد انتهاء علاقة التوظيف.';
  if (message.includes('people_compensation_before_employment')) return 'يجب أن يبدأ سريان الأجر في تاريخ بداية علاقة التوظيف أو بعده.';
  if (message.includes('people_compensation_after_employment_end')) return 'تاريخ سريان الأجر يأتي بعد نهاية علاقة التوظيف.';
  if (message.includes('people_compensation_input_invalid')) return 'أدخل قيمة موجبة أو صفرًا بمنزلتين عشريتين كحد أقصى.';
  if (message.includes('people_compensation_audit')) return 'تعذر تسجيل التغيير؛ لم يُحفظ أي تعديل. أعد المحاولة.';
  return 'تعذر حفظ التغيير. تحقق من صلاحية إدارة الأجر وحالة علاقة التوظيف.';
}
