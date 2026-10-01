import type { createSupabaseServerClient } from '@/lib/supabase/server';
import { readAccess, readEmployer, type EmployerInfo, type SettingsAccess } from './rules';

type ServerClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;

export type AccessGate =
  | { kind: 'no-client' }
  | { kind: 'forbidden' }
  | { kind: 'error' }
  | { kind: 'no-view' }
  | { kind: 'unavailable' }
  | { kind: 'ok'; access: SettingsAccess; employer: EmployerInfo; canEdit: boolean };

export type GateKind = Exclude<AccessGate, { kind: 'ok' }>['kind'];

export async function loadSettingsAccess(
  supabase: ServerClient,
  tenantId: string,
  employerId: string,
): Promise<AccessGate> {
  if (!supabase) return { kind: 'no-client' };
  const accessResult = await supabase.rpc('leave_access_snapshot', { p_tenant: tenantId });
  if (accessResult.error) {
    return { kind: accessResult.error.code === '42501' ? 'forbidden' : 'error' };
  }
  const access = readAccess(accessResult.data);
  if (!access) return { kind: 'error' };
  if (!access.canView) return { kind: 'no-view' };

  const employerResult = await supabase.rpc('leave_configuration_employer', {
    p_tenant: tenantId,
    p_employer: employerId,
  });
  if (employerResult.error) {
    if (employerResult.error.code === 'P0002') return { kind: 'unavailable' };
    if (employerResult.error.code === '42501') return { kind: 'forbidden' };
    return { kind: 'error' };
  }
  const employer = readEmployer(employerResult.data);
  if (!employer) return { kind: 'error' };
  return {
    kind: 'ok',
    access,
    employer,
    canEdit: access.canManage && access.newWorkEnabled && employer.is_active,
  };
}

export function editBlockedText(
  gate: Extract<AccessGate, { kind: 'ok' }>,
  noun: string,
): { title: string; detail: string } {
  if (!gate.employer.is_active) {
    return {
      title: 'هذه الجهة موقوفة',
      detail: 'الجهة موقوفة لذا لا تقبل إعدادات جديدة. يمكنك مراجعة إعداداتها السابقة من صفحة الجهة.',
    };
  }
  if (!gate.access.canManage) {
    return {
      title: `${noun} غير متاحة`,
      detail: `تحتاج إلى صلاحية إدارة الإجازات لـ«${noun}». يمكنك مراجعة الإعدادات الحالية دون تعديل.`,
    };
  }
  return {
    title: 'الإنشاء الجديد غير متاح حاليًا',
    detail: 'خدمة إدارة الموظفين أو الإجازات موقوفة في الشركة، لذا لا يمكن إنشاء إعدادات جديدة. يمكنك مراجعة الإعدادات الحالية.',
  };
}

export const GATE_TEXT: Record<GateKind, { title: string; detail: string; retry: boolean }> = {
  'no-client': {
    title: 'الاتصال غير متاح',
    detail: 'تعذر الاتصال بخدمة الحسابات. أعد المحاولة لاحقًا.',
    retry: true,
  },
  forbidden: {
    title: 'إعدادات الإجازات غير متاحة لهذا الحساب',
    detail: 'لا يملك حسابك أي صلاحية لعرض إعدادات الإجازات في الشركة. راجع إدارة الموارد البشرية.',
    retry: false,
  },
  error: {
    title: 'تعذر فتح إعدادات الإجازات',
    detail: 'حدث خطأ أثناء التحقق من صلاحيتك أو تحميل البيانات. أعد المحاولة.',
    retry: true,
  },
  'no-view': {
    title: 'عرض إعدادات الإجازات غير متاح لهذا الحساب',
    detail: 'تحتاج إلى صلاحية عرض أو إدارة الإجازات لدى الشركة. راجع إدارة الموارد البشرية.',
    retry: false,
  },
  unavailable: {
    title: 'هذه الجهة غير متاحة',
    detail: 'لم نعثر على هذه الجهة ضمن الشركة. عُد إلى قائمة الجهات واختر الجهة المطلوبة.',
    retry: false,
  },
};
