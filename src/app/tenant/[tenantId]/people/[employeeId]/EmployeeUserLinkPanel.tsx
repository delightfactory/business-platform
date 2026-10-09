import { Button, ButtonLink, Field, Input, Message, Panel, Select } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import { linkEmployeeUserAction, unlinkEmployeeUserAction } from '../employee-user-link-actions';
import { createEmployeeAccountAction, retryEmployeeAccountActivationAction, sendEmployeeAccountReadinessRecoveryAction } from '../employee-account-actions';

export type LinkSnapshot = { linked: boolean; identity_visible: boolean; link_id: string | null; user_id: string | null; email: string | null; display_name: string | null; linked_at: string | null };
export type Options = { items: Array<{ user_id: string; email: string; display_name: string }>; page: number; page_size: number; has_more: boolean };
export type AccountProvision = { intent_id?: string; state: string; target_email?: string; delivery_state?: string; last_error_code?: string; password_ready?: boolean; currently_linked?: boolean };

export function EmployeeUserLinkPanel({ tenantId, employeeId, canManage, canInvite, canProvisionAccount, snapshot, snapshotError, options, optionsError,
  accountProvision, accountProvisionError, requestKey, accountState, query, page, state }: { tenantId: string; employeeId: string; canManage: boolean; canInvite: boolean;
  canProvisionAccount: boolean;
  snapshot: LinkSnapshot | null; snapshotError: boolean; options: Options | null; optionsError: boolean;
  accountProvision: AccountProvision | null; accountProvisionError: boolean; requestKey: string; accountState?: string; query: string; page: number; state?: string }) {
  const base = `/tenant/${tenantId}/people/${employeeId}`;
  const messages: Record<string, string> = {
    linked: 'تم ربط حساب المستخدم بالموظف.', unlinked: 'تم فك الربط مع الاحتفاظ بسجل العملية.',
    'employee-linked': 'لدى الموظف حساب مرتبط بالفعل.', 'user-linked': 'هذا الحساب مرتبط بموظف آخر في الشركة.',
    'member-unavailable': 'الحساب غير نشط في هذه الشركة أو لم يؤكد بريده بعد.',
    forbidden: 'ليست لديك صلاحية إدارة ربط الحسابات.', error: 'تعذر تحديث الربط. حدّث الصفحة وتحقق من الحالة.',
    'invite-sent': 'أُرسلت الدعوة. بعد قبولها وظهور العضوية النشطة، ارجع إلى الملف واربط الحساب.',
    'invite-failed': 'سُجلت الدعوة لكن تعذر تأكيد إرسال البريد. راجع حالة الدعوة من صفحة المستخدمين.',
    'invite-unknown': 'أُنشئت الدعوة، لكن تعذر تأكيد حالة البريد. راجع صفحة المستخدمين قبل إعادة الإرسال.',
  };
  const accountMessages: Record<string, string> = {
    'delivery-sent': 'أُرسل رابط التفعيل إلى البريد. سيؤكد الموظف بريده ويختار كلمة المرور بنفسه.',
    'delivery-failed': 'تعذر إرسال رابط التفعيل. سيظل الطلب محفوظًا ويمكن إعادة الإرسال بعد التحقق من إعداد البريد.',
    'manual-review': 'تعذر إثبات أن الحساب الموجود أُنشئ لهذا الطلب. لم نربط حسابًا موجودًا تلقائيًا؛ راجع الحساب يدويًا قبل المتابعة.',
    'create-failed': 'تعذر إنشاء الحساب أو تأكيد نتيجته. الطلب محفوظ؛ أعد المحاولة للتحقق قبل بدء طلب آخر.',
    'pending': 'يوجد طلب إنشاء قيد المتابعة. أعد المحاولة لإكماله بأمان.',
    'forbidden': 'يلزم صلاحية إدارة الموارد البشرية ومستخدمي الشركة لإنشاء الحساب.',
    'subject-unavailable': 'لا يمكن إنشاء حساب لهذا الموظف أو الشركة في حالتهما الحالية.',
    'already-linked': 'لدى الموظف حساب مرتبط بالفعل.',
    'setup': 'إعداد خدمة الحسابات أو عنوان التطبيق غير مكتمل. لم نربط أي حساب.',
    'operation-error': 'تعذر إكمال العملية. تحقق من حالة الطلب قبل بدء عملية أخرى.',
    'readiness-link-sent': 'أُرسل رابط آمن للموظف لتحديث كلمة المرور وتأكيد جاهزيتها. الحساب وعضويته وصلاحياته لم تتغير.',
    'readiness-link-failed': 'تعذر تأكيد إرسال رابط تحديث كلمة المرور. تحقق من إعداد البريد قبل إعادة المحاولة.',
  };
  const provision = accountProvision;
  const currentlyLinkedProvision = snapshot?.linked === true && provision?.currently_linked === true;
  const canStartNewAccount = !accountProvisionError && !snapshotError && snapshot?.linked === false && Boolean(provision)
    && (provision?.state === 'none' || (provision?.state === 'activated' && provision.currently_linked === false));
  return <Panel  aria-labelledby="employee-user-link-heading">
    <h2 id="employee-user-link-heading">حساب المستخدم</h2>
    {state && messages[state] && <Message tone={state === 'error' || state === 'forbidden' || state === 'invite-failed' ? 'bad' : 'info'} role="status">{messages[state]}</Message>}
    {snapshotError || !snapshot ? <p role="alert">تعذر تحميل حالة ربط الحساب.</p> : snapshot.linked
      ? <div><p>{snapshot.identity_visible
        ? <><strong>{snapshot.display_name ?? snapshot.email}</strong>{snapshot.email && <> <bdi>{snapshot.email}</bdi></>}</>
        : <strong>حساب مرتبط</strong>}</p>
        {canManage && <OfflineForm action={unlinkEmployeeUserAction} className="workspace-form-actions">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
          <OfflineSubmitButton className="secondary-button" label="فك الربط" pendingLabel="جارٍ فك الربط…" />
        </OfflineForm>}
      </div>
      : <p>لا يوجد حساب مستخدم مرتبط بهذا الموظف. الربط اختياري ولا يغيّر صلاحيات العضوية.</p>}
    <div className="workspace-page-summary"><h3>استكمال تفعيل تسجيل الحضور للموظف</h3><p>{snapshot?.linked ? 'الحساب مرتبط بالموظف. راجع صلاحية الحضور للحساب وإعداد موقع العمل أيضًا.' : 'اربط أولًا حساب عضو نشط بملف هذا الموظف، ثم فعّل له صلاحية الحضور الشخصي.'}</p><p className="field-hint">يحتاج الموظف عملًا ساريًا وموقعًا وسياسة حضور مهيأة وخدمة مفعلة. فك الربط يمنع التسجيل من الحساب السابق، ولا يمحو الحركات المسجلة.</p>{canInvite ? <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/users?view=members${snapshot?.identity_visible && snapshot.email ? `&q=${encodeURIComponent(snapshot.email)}` : ''}`}>إدارة صلاحية الحضور لحساب الموظف</ButtonLink> : <p>اطلب من مسؤول الأعضاء تفعيل «الحضور الشخصي من الهاتف» للحساب المرتبط. صلاحية ربط الموظفين لا تشمل إدارة الأعضاء.</p>}</div>
    {accountState && accountMessages[accountState] && <Message tone={['delivery-failed','manual-review','create-failed','forbidden','subject-unavailable','setup','operation-error','readiness-link-failed'].includes(accountState) ? 'bad' : 'info'} role="status">{accountMessages[accountState]}</Message>}
    {!snapshotError && !snapshot?.linked && canManage && <>
      <h3>ربط عضو موجود</h3>
      {optionsError || !options ? <p role="alert">تعذر تحميل قائمة الأعضاء المستوفين لشروط الربط.</p> : <>
        <form method="get" action={base} className="compact-form">
          <Field id="user-link-query" label={<>البحث بالبريد أو الاسم</>}><Input id="user-link-query" name="linkQuery" type="search" maxLength={100} defaultValue={query} /></Field>
          <input type="hidden" name="linkPage" value="1" />
          <Button variant="ghost"  type="submit">بحث</Button>
        </form>
        {options.items.length ? <OfflineForm action={linkEmployeeUserAction} className="compact-form">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
          <Field id="employee-user-id" label={<>عضو نشط وبريد مؤكد</>} required><Select id="employee-user-id" name="userId" required defaultValue="">
            <option value="" disabled>اختر عضوًا</option>
            {options.items.map((item) => <option key={item.user_id} value={item.user_id}>{item.display_name} — {item.email}</option>)}
          </Select></Field>
          <OfflineSubmitButton label="ربط الحساب" pendingLabel="جارٍ ربط الحساب…" />
        </OfflineForm> : <p>لا توجد عضوية نشطة تستوفي شروط الربط وتطابق البحث.</p>}
        <nav className="workspace-form-actions" aria-label="صفحات الأعضاء">
          {page > 1 && <ButtonLink variant="ghost"  href={`${base}?linkQuery=${encodeURIComponent(query)}&linkPage=${page - 1}`}>السابق</ButtonLink>}
          <span>صفحة {page}</span>
          {options.has_more && <ButtonLink variant="ghost"  href={`${base}?linkQuery=${encodeURIComponent(query)}&linkPage=${page + 1}`}>التالي</ButtonLink>}
        </nav>
      </>}
      {canInvite && <div className="workspace-page-summary"><p>لا يوجد حساب؟ أرسل دعوة العضوية، وبعد القبول ارجع هنا لتفعيل الربط.</p>
        <ButtonLink variant="ghost"  href={`/tenant/${tenantId}/users/invite?employeeId=${encodeURIComponent(employeeId)}`}>دعوة عضو جديد</ButtonLink></div>}
      {canProvisionAccount && <div className="workspace-page-summary">
        <h3>إنشاء حساب للموظف</h3>
        <p>يُنشأ الحساب دون أن يختار المسؤول كلمة مرور. سيؤكد الموظف بريده ويضع كلمة المرور، ثم تضاف له عضوية «عضو» ويرتبط حسابه بهذا الملف.</p>
        {accountProvisionError && <Message tone="bad"  role="alert">تعذر تحميل حالة إنشاء الحساب. حدّث الصفحة قبل بدء طلب جديد.</Message>}
        {provision && provision.state !== 'none' && provision.state !== 'activated' && <div className="record-meta">
          <p>حالة الطلب: {provision.state === 'pending' ? 'قيد الإنشاء' : provision.state === 'user_created'
            ? provision.delivery_state === 'sent' ? 'بانتظار تفعيل الموظف' : 'الحساب جاهز لإعادة إرسال رابط التفعيل'
            : 'مراجعة مطلوبة'}</p>
          {provision.target_email && <p>البريد: <bdi>{provision.target_email}</bdi></p>}
          {provision.state === 'manual_review' && <p role="alert">لن يتم اعتماد حساب لم تثبت ملكية هذا الطلب له.</p>}
          {['pending','user_created'].includes(provision.state) && provision.intent_id && <OfflineForm action={retryEmployeeAccountActivationAction}>
            <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
            <input type="hidden" name="intentId" value={provision.intent_id} />
            <OfflineSubmitButton label={provision.state === 'pending' ? 'متابعة إنشاء الحساب' : 'إعادة إرسال رابط التفعيل'} pendingLabel="جارٍ الإرسال…" />
          </OfflineForm>}
        </div>}
        {provision?.state === 'activated' && provision.currently_linked === false && <Message tone="info" >الحساب السابق لم يعد مرتبطًا بهذا الموظف. يمكنك إنشاء حساب بديل.</Message>}
        {canStartNewAccount && <OfflineForm action={createEmployeeAccountAction} className="compact-form">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
          <input type="hidden" name="requestKey" value={requestKey} />
          <Field id="employee-account-email" label={<>بريد الموظف</>} required><Input id="employee-account-email" name="email" type="email" autoComplete="email" maxLength={254} required /></Field>
          <OfflineSubmitButton label="إنشاء الحساب وإرسال رابط التفعيل" pendingLabel="جارٍ إنشاء الحساب…" />
        </OfflineForm>}
      </div>}
    </>}
    {!snapshotError && !accountProvisionError && currentlyLinkedProvision && canProvisionAccount && provision?.state === 'activated' && provision.password_ready !== true && provision.intent_id && <div className="workspace-page-summary">
      <h3>تأكيد جاهزية كلمة المرور</h3>
      <p>الحساب نشط بالفعل. يمكن إرسال رابط للموظف لتحديث كلمة المرور وتأكيد جاهزيتها دون تغيير العضوية أو الصلاحيات.</p>
      <OfflineForm action={sendEmployeeAccountReadinessRecoveryAction}>
        <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
        <input type="hidden" name="intentId" value={provision.intent_id} />
        <OfflineSubmitButton label="إرسال رابط تأكيد كلمة المرور" pendingLabel="جارٍ الإرسال…" />
      </OfflineForm>
    </div>}
  </Panel>;
}
