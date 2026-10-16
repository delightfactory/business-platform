import { ButtonLink, Message, Panel, StatusBadge } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import { ProfileReturnField } from '@/components/profile-return-field';
import { enableEmployeeSelfServiceAction } from '../employee-self-service-actions';

export type SelfServiceAccess = { state: 'ready' | 'inactive' | 'unlinked' | 'other-role' | 'unknown'; keys: string[]; userId?: string; email?: string };
export function EmployeeSelfServices({ tenantId, employeeId, access, result, returnTo }: { tenantId: string; employeeId: string; access: SelfServiceAccess; result?: string; returnTo?: string | null }) {
  const feedback: Record<string, string> = {
    saved: 'تم حفظ الصلاحية. الحالة أدناه من الصلاحيات الحالية للحساب المرتبط.',
    stale: 'تغيّرت صلاحيات الحساب. راجع الحالة الحالية ثم أعد اختيار الخدمة المطلوبة.',
    'link-changed': 'تعذر التحقق من الحساب المرتبط. راجع الربط قبل منح الخدمة.',
    forbidden: 'لم تعد صلاحية إدارة مستخدمي الشركة متاحة لهذا الحساب.',
    invalid: 'تعذر قراءة اختيار الخدمة. حدّث الصفحة ثم أعد الاختيار.',
    unknown: 'تعذر تأكيد النتيجة. راجع الحالة الحالية قبل أي محاولة جديدة.',
  };
  return <Panel aria-labelledby="employee-self-services"><h2 id="employee-self-services">ما يمكن للموظف استخدامه</h2>
    {access.state === 'ready' && access.email && <p>الحساب المرتبط: <bdi>{access.email}</bdi></p>}
    {result && feedback[result] && <Message tone={result === 'saved' ? 'info' : 'warn'}>{feedback[result]}</Message>}
    {access.state === 'other-role' ? <p>إتاحة هذه الخدمات تحتاج مسؤول المستخدمين.</p>
      : access.state === 'inactive' ? <p>عضوية الحساب المرتبط غير نشطة. راجعها من إدارة المستخدمين قبل إتاحة الخدمات.</p>
      : access.state === 'unlinked' ? <p>اربط حساب الموظف أولًا، ثم اختر الخدمات التي تريد إتاحتها.</p>
        : access.state === 'unknown' ? <Message tone="warn">تعذر قراءة صلاحيات الحساب الحالي. حدّث الصفحة قبل منح أي خدمة.</Message>
          : <div className="workspace-form-actions">{[
            { key: 'employee.attendance.self.v1', label: 'تسجيل الحضور', action: 'إتاحة تسجيل الحضور' },
            { key: 'employee.leave.self.v1', label: 'الإجازات', action: 'إتاحة الإجازات' },
          ].map(service => access.keys.includes(service.key) ? <StatusBadge key={service.key} tone="ok" label={`${service.label}: الصلاحية مضافة`} />
            : <OfflineForm key={service.key} action={enableEmployeeSelfServiceAction}>
              <ProfileReturnField value={returnTo} />
              <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
              <input type="hidden" name="bundle" value={service.key} />
              <input type="hidden" name="linkedUserId" value={access.userId} />
              {access.keys.map(key => <input key={key} type="hidden" name="expectedBundleKey" value={key} />)}
              <OfflineSubmitButton label={service.action} pendingLabel="جارٍ الحفظ…" />
            </OfflineForm>)}</div>}
    {(access.state === 'ready' || access.state === 'inactive') && access.email && <ButtonLink variant="ghost" href={`/tenant/${tenantId}/users?${new URLSearchParams({ view: 'members', q: access.email.slice(0, 120) })}`}>راجع عضوية الحساب وصلاحياته</ButtonLink>}
    <p className="field-hint">تظهر هذه الخدمات في حساب الموظف فقط، دون صلاحيات الإدارة. يحتاج الحضور إلى دوام ووسيلة تسجيل مفعّلة لفرعه.</p>
  </Panel>;
}
