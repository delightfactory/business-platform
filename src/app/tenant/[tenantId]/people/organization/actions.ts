'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type OrgCatalogKind = 'departments' | 'jobs';
export type OrgCatalogFormState = {
  tenantId: string; kind: OrgCatalogKind; recordId: string; code: string; name: string;
  relationId: string; isActive: boolean; error: string; attempt: number;
};

export async function saveOrgCatalogAction(previous: OrgCatalogFormState, formData: FormData): Promise<OrgCatalogFormState> {
  const tenantId = value(formData, 'tenantId');
  const kind = value(formData, 'kind');
  const recordId = value(formData, 'recordId');
  const code = value(formData, 'code');
  const name = value(formData, 'name');
  const relationId = value(formData, 'relationId');
  const intent = value(formData, 'intent');
  const isActive = intent === 'disable' ? false : intent === 'reactivate' ? true : value(formData, 'isActive') === 'true';
  const state: OrgCatalogFormState = {
    tenantId, kind: kind === 'jobs' ? 'jobs' : 'departments', recordId, code, name,
    relationId, isActive, error: '', attempt: previous.attempt + 1,
  };
  const fail = (message: string): OrgCatalogFormState => ({ ...state, error: message });
  if (!isUuid(tenantId) || !['departments', 'jobs'].includes(kind)
      || (recordId !== 'new' && !isUuid(recordId)) || (relationId && !isUuid(relationId))) {
    return fail('تحقق من بيانات السجل ثم أعد المحاولة. بقيت القيم التي أدخلتها محفوظة.');
  }
  if (intent === 'disable' && recordId === 'new') return fail('أضف السجل أولًا ثم يمكنك إيقافه.');
  if (!code || code.length > 40 || !name || name.length > 160) {
    return fail('أدخل رمزًا واسمًا ضمن الطول المسموح. بقيت القيم التي أدخلتها محفوظة.');
  }
  const supabase = await createSupabaseServerClient();
  if (!supabase) return fail('الخدمة غير متاحة الآن. أعد المحاولة؛ بقيت القيم محفوظة.');
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return fail('انتهت جلسة الدخول. سجّل الدخول ثم أعد المحاولة.');
  const isNew = recordId === 'new';
  const { data, error } = kind === 'departments'
    ? await supabase.rpc('save_people_department', {
      p_tenant_id: tenantId, p_department_id: isNew ? null : recordId,
      p_code: code, p_name: name, p_parent_id: relationId || null, p_is_active: isActive,
    })
    : await supabase.rpc('save_people_job', {
      p_tenant_id: tenantId, p_job_id: isNew ? null : recordId,
      p_code: code, p_name: name, p_department_id: relationId || null, p_is_active: isActive,
    });
  if (error) return fail(errorText(error.message));
  const result = data && typeof data === 'object' && !Array.isArray(data) ? data as Record<string, unknown> : null;
  if (typeof result?.state !== 'string') return fail('تعذر تأكيد حفظ التغيير. حدّث الدليل للتحقق قبل إعادة المحاولة.');
  const prefix = kind === 'departments' ? 'department' : 'job';
  const suffix = result.state === 'created' ? 'created'
    : result.state === 'deactivated' ? 'deactivated'
      : result.state === 'reactivated' ? 'reactivated'
        : result.state === 'unchanged' ? 'unchanged' : 'updated';
  redirect(`/tenant/${tenantId}/people/organization?kind=${kind}&state=${prefix}-${suffix}`);
}

function value(formData: FormData, key: string) { return String(formData.get(key) ?? '').trim(); }
function isUuid(value: string) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value); }

function errorText(message: string) {
  if (message.includes('people_org_manage_forbidden')) return 'تحتاج إلى صلاحية إدارة الأقسام والوظائف في هذه الشركة.';
  if (message.includes('people_org_department_cycle')) return 'لا يمكن اختيار قسم تابع لهذا القسم؛ اختر قسمًا أعلى لتجنّب تكوين حلقة.';
  if (message.includes('people_org_parent_unavailable')) return 'القسم الأعلى غير متاح أو يتبع شركة أخرى. اختر قسمًا نشطًا.';
  if (message.includes('people_org_department_unavailable')) return 'القسم غير نشط أو لم يعد متاحًا للتعيين.';
  if (message.includes('people_org_job_department_in_use')) return 'لا يمكن نقل الوظيفة إلى قسم آخر لوجود موظفين مرتبطين بها. احتفظ بالقسم الحالي أو حدّث تعيينات الموظفين أولًا.';
  if (message.includes('people_org_department_not_found') || message.includes('people_org_job_not_found')) return 'لم نعثر على السجل. حدّث القائمة ثم أعد المحاولة.';
  if (message.includes('departments_code_per_tenant_idx') || message.includes('jobs_code_per_tenant_idx')) return 'هذا الرمز مستخدم بالفعل في الشركة. اختر رمزًا آخر.';
  if (message.includes('people_org_input_invalid')) return 'راجع الرمز والاسم ثم أعد المحاولة.';
  if (message.includes('people_org_audit')) return 'تعذر تسجيل التغيير؛ لم يُحفظ أي تعديل. أعد المحاولة.';
  return 'تعذر حفظ التغيير. لم يُحفظ أي تعديل دون تسجيله؛ راجع البيانات وأعد المحاولة.';
}
