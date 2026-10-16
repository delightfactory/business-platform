import styles from './profile-summary.module.css';
import { readinessFocus } from './readiness-focus';
import { ButtonLink, Disclosure, HelpNote, Panel } from '@/components/ui';
import { ReadinessList, type ReadinessItem } from '@/components/patterns/readiness-list/ReadinessList';
import type { SelfServiceAccess } from './EmployeeSelfServices';
import { profileReturnUrl, workPolicyCatalogUrl } from '@/lib/profile-return';

type Facts = {
  work: { active: boolean; hasAssignment: boolean; canManage: boolean };
  compensation: { canView: boolean; current: boolean | null };
  policy: { current: boolean | null; canAssign: boolean; hasOptions: boolean; canManageCatalog: boolean; forbidden: boolean };
  account: { linked: boolean | null; canManage: boolean; provisionState?: string };
  selfService: SelfServiceAccess;
  channel: { canView: boolean; canManage: boolean; state?: string; captureEnabled?: boolean } | null;
  canReviewBalances: boolean | null;
  canPreparePayroll: boolean | null;
};

export function EmployeeReadiness({ tenantId, employeeId, employerId, facts, returnTo }: { tenantId: string; employeeId: string; employerId: string | null; facts: Facts; returnTo?: string | null }) {
  const base = `/tenant/${tenantId}`, profile = `${base}/people/${employeeId}`;
  const tab = (area: string, label: string) => ({ href: profileReturnUrl(tenantId, employeeId, `${profile}?tab=${area}`, returnTo), label });
  const core: ReadinessItem[] = [], reviews: ReadinessItem[] = [];
  core.push({ title: 'العمل والفرع الحاليان', state: facts.work.active && facts.work.hasAssignment ? 'done' : facts.work.canManage ? 'todo' : 'other-role',
    detail: facts.work.active && facts.work.hasAssignment ? 'بيانات العمل والفرع الحالي محفوظة.' : 'راجع علاقة العمل والفرع وتاريخ بدايتها؛ العمل المقرر أو المنتهي لا يعني عملًا جاريًا.',
    owner: !facts.work.canManage ? 'مسؤول الموارد البشرية' : undefined, action: facts.work.canManage ? tab('work', 'راجع العمل والفرع') : undefined });
  reviews.push({ title: 'الأجر الأساسي', state: !facts.compensation.canView ? 'other-role' : facts.compensation.current === null ? 'unknown' : facts.compensation.current ? 'done' : 'todo',
    detail: !facts.compensation.canView ? 'مراجعة الأجر تحتاج صلاحية عرض الأجور.' : facts.compensation.current === null ? 'تعذر التحقق من سجل الأجر.' : facts.compensation.current ? 'يوجد أجر أساسي سارٍ.' : 'راجع الأجر وتاريخ سريانه.',
    owner: !facts.compensation.canView ? 'مسؤول الأجور' : undefined, action: facts.compensation.canView ? tab('compensation', 'راجع الأجر') : undefined });
  const policy = facts.policy;
  core.push({ title: 'سياسة الدوام', state: policy.forbidden ? 'other-role' : policy.current === null ? 'unknown' : policy.current ? 'done' : policy.canAssign || policy.canManageCatalog ? 'todo' : 'other-role',
    detail: policy.current ? 'سياسة دوام أساسية سارية محفوظة.' : policy.current === null && !policy.forbidden ? 'تعذر قراءة سياسة الدوام الحالية.' : 'يلزم تعيين سياسة دوام لتجهيز الحضور.',
    owner: !policy.canAssign && !policy.canManageCatalog ? 'مسؤول الدوام' : undefined,
    action: !policy.current && policy.canManageCatalog && !policy.hasOptions ? { href: workPolicyCatalogUrl(tenantId, employeeId, returnTo), label: 'أنشئ قالب دوام' }
      : policy.canAssign ? tab('work', policy.current ? 'راجع سياسة الدوام' : 'عيّن سياسة الدوام') : undefined });
  const account = facts.account;
  const pending = ['pending', 'user_created'].includes(account.provisionState ?? '');
  core.push({ title: 'حساب الدخول', state: account.linked === null ? 'unknown' : account.linked ? 'done' : pending ? 'other-role' : account.canManage ? 'todo' : 'other-role',
    detail: account.linked ? 'حساب دخول مرتبط بملف الموظف.' : account.linked === null ? 'تعذر التحقق من ربط الحساب.' : account.provisionState === 'manual_review' ? 'طلب إنشاء الحساب يحتاج مراجعة؛ لا يُربط حساب موجود تلقائيًا.'
      : pending ? 'طلب إنشاء الحساب محفوظ؛ راجع الإرسال وانتظر تفعيل الموظف عند وصول الرابط.' : 'اختر حسابًا موجودًا أو أنشئ حسابًا، أو أرسل دعوة عضوية ثم اربط الحساب بعد قبولها.',
    owner: pending ? 'الموظف ومسؤول المستخدمين' : !account.canManage ? 'مسؤول الموارد البشرية' : undefined,
    action: account.canManage ? tab('account', 'راجع حساب الدخول') : undefined });
  const self = facts.selfService;
  const both = ['employee.attendance.self.v1', 'employee.leave.self.v1'].every(key => self.keys.includes(key));
  core.push({ title: 'الخدمات الذاتية', state: self.state === 'ready' ? both ? 'done' : 'todo' : self.state === 'other-role' ? 'other-role' : self.state === 'unknown' ? 'unknown' : 'todo',
    detail: self.state === 'other-role' ? 'إتاحة الخدمات تحتاج مسؤول المستخدمين.' : self.state === 'unknown' ? 'تعذر قراءة صلاحيات الحساب.' : self.state === 'inactive' ? 'عضوية الحساب المرتبط غير نشطة؛ راجعها قبل إتاحة الخدمات.' : self.state === 'unlinked' ? 'اربط الحساب أولًا، ثم اختر الخدمات المطلوبة صراحة.' : both ? 'صلاحيتا الحضور الشخصي والإجازات مضافتان للحساب.' : 'اختر إتاحة الحضور والإجازات من قسم الحساب.',
    owner: self.state === 'other-role' ? 'مسؤول المستخدمين' : undefined,
    action: ['ready', 'inactive'].includes(self.state) || (self.state === 'unlinked' && account.canManage) ? tab('account', 'راجع الخدمات الذاتية') : undefined });
  const channel = facts.channel;
  const channelReady = channel?.state === 'ready' && channel.captureEnabled === true;
  core.push({ title: 'موقع تسجيل الحضور لفرع الموظف', state: !channel ? 'unknown' : !channel.canView ? 'other-role' : !channel.state ? 'unknown' : channelReady ? 'done' : channel.captureEnabled === false ? 'other-role' : channel.canManage ? 'todo' : 'other-role',
    detail: !channel ? 'تعذر التحقق من صلاحية قراءة إعداد الحضور.' : !channel.canView ? 'مراجعة إعداد موقع التسجيل تحتاج مسؤول الحضور.' : !channel.state ? 'تعذر التحقق من إعداد موقع التسجيل.' : channelReady ? 'وسيلة تسجيل الهاتف لفرع الموظف نشطة وإعدادها صالح.'
      : channel.captureEnabled === false ? 'خدمة الحضور غير متاحة حاليًا؛ تواصل مع إدارة المنصة.' : channel.state === 'work-unavailable' || channel.state === 'site-inactive' ? 'راجع العمل الجاري والفرع النشط قبل تجهيز التسجيل.'
        : channel.state === 'missing' ? 'لم تُجهَّز وسيلة تسجيل من الهاتف لفرع الموظف.' : channel.state === 'disabled' ? 'وسيلة تسجيل الهاتف لفرع الموظف متوقفة.' : 'إعداد وسيلة التسجيل يحتاج استكمالًا.',
    owner: !channelReady ? channel?.captureEnabled === false ? 'إدارة المنصة' : 'مسؤول الحضور' : undefined,
    action: channel?.canView ? { href: `${base}/attendance/sources`, label: channel.canManage ? 'راجع وسائل تسجيل الحضور' : 'عرض وسائل التسجيل' } : undefined });
  reviews.push({ title: 'الأرصدة الافتتاحية', state: facts.canReviewBalances === false ? 'other-role' : 'unknown', statusLabel: facts.canReviewBalances ? 'راجع الأرصدة' : undefined,
    detail: facts.canReviewBalances === null ? 'تعذر التحقق من صلاحية مراجعة الأرصدة الآن.' : 'راجع الأرصدة حسب سياسة الإجازات؛ لم تُفحص أرصدة الموظف من هذا الملخص.', owner: facts.canReviewBalances === false ? 'مسؤول الإجازات' : undefined,
    action: facts.canReviewBalances ? { href: `${base}/leave/balances?${new URLSearchParams({ employee: employeeId, ...(employerId ? { employer: employerId } : {}) })}`, label: 'راجع الأرصدة' } : undefined });
  reviews.push({ title: 'بيانات الضريبة والتأمينات', state: facts.canPreparePayroll === false ? 'other-role' : 'unknown', statusLabel: facts.canPreparePayroll ? 'تُراجع لكل فترة' : undefined,
    detail: facts.canPreparePayroll === null ? 'تعذر التحقق من صلاحية تحضير الرواتب الآن.' : 'تُراجع هذه البيانات داخل فترة الرواتب؛ لا يُفترض اكتمالها من ملف الموظف.', owner: facts.canPreparePayroll === false ? 'مسؤول تحضير الرواتب' : undefined,
    action: facts.canPreparePayroll ? { href: `${base}/payroll/inputs${employerId ? `?employer=${employerId}` : ''}`, label: 'بيانات الفترة' } : undefined });
  const summary = readinessFocus(core), focus = summary.current;
  const listLabels = (item: ReadinessItem): ReadinessItem => ({ ...item, statusLabel: item.statusLabel
    ?? (item.state === 'done' ? 'مسجّل' : item.state === 'todo' ? 'مطلوب' : undefined) });
  const title = !focus ? 'الإعدادات الأساسية مسجلة' : focus.state === 'todo' ? `الخطوة التالية: ${focus.title}`
    : focus.state === 'unknown' ? `تعذر التحقق: ${focus.title}` : `بانتظار ${focus.owner ?? 'المختص'}: ${focus.title}`;
  return <Panel className={styles.readinessPanel} aria-labelledby="employee-readiness">
    <h2 id="employee-readiness">متابعة تجهيز الموظف</h2>
    <section className={styles.focusCard} data-state={focus?.state ?? 'done'} aria-labelledby="employee-next-step">
      <div><h3 id="employee-next-step">{title}</h3>
        <p>{focus?.detail ?? 'الإعدادات الأساسية الخمسة مسجلة. تظهر إمكانية تسجيل الحضور الفعلية للموظف في يومه، وفق الحساب والخدمة والدوام.'}</p>
        {focus?.owner && <p className={styles.owner}>يتولاها: {focus.owner}</p>}
        {focus?.state === 'unknown' && <p>أعد تحميل الصفحة أو راجع القسم المختص للتحقق.</p>}
      </div>
      {focus?.action && <ButtonLink className={styles.focusAction} href={focus.action.href} variant={focus.state === 'todo' ? 'solid' : 'ghost'}>{focus.action.label}</ButtonLink>}
    </section>
    <p className={styles.progress}>{summary.saved} من {summary.total} إعدادات أساسية مسجلة{summary.unknown > 0 ? `، وتعذر التحقق من ${summary.unknown}` : ''}.</p>
    <div className={styles.detailGroups}>
      <Disclosure summary={`تفاصيل الإعدادات الأساسية (${core.length})`}><ReadinessList items={core.map(listLabels)} /></Disclosure>
      <Disclosure summary={`مراجعات الأجر والأرصدة وبيانات الرواتب (${reviews.length})`} open={reviews[0].state === 'todo' || reviews[0].state === 'unknown'}><ReadinessList items={reviews.map(listLabels)} /></Disclosure>
    </div>
    <HelpNote label="كيف أقرأ هذه المتابعة؟"><p>جاهزية تسجيل الحضور تحتاج الحساب والخدمة الذاتية والعمل والفرع وسياسة الدوام ووسيلة التسجيل. حالة الموظف «نشط» وحدها لا تثبت إتاحة التسجيل، والسبب الفعلي يظهر للموظف في يومه.</p></HelpNote>
  </Panel>;
}
