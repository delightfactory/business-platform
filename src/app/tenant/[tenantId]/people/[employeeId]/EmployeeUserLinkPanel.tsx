import Link from 'next/link';
import { linkEmployeeUserAction, unlinkEmployeeUserAction } from '../employee-user-link-actions';
import { createEmployeeAccountAction, retryEmployeeAccountActivationAction, sendEmployeeAccountReadinessRecoveryAction } from '../employee-account-actions';
import { SubmitButton } from '@/components/submit-button';

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
  return <section className="workspace-records-panel" aria-labelledby="employee-user-link-heading">
    <h2 id="employee-user-link-heading">حساب المستخدم</h2>
    {state && messages[state] && <p className={state === 'error' || state === 'forbidden' || state === 'invite-failed' ? 'form-message error-message' : 'form-message'} role="status">{messages[state]}</p>}
    {snapshotError || !snapshot ? <p role="alert">تعذر تحميل حالة ربط الحساب.</p> : snapshot.linked
      ? <div><p>{snapshot.identity_visible
        ? <><strong>{snapshot.display_name ?? snapshot.email}</strong>{snapshot.email && <> <bdi>{snapshot.email}</bdi></>}</>
        : <strong>حساب مرتبط</strong>}</p>
        {canManage && <form action={unlinkEmployeeUserAction} className="workspace-form-actions">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
          <button className="secondary-button" type="submit">فك الربط</button>
        </form>}
      </div>
      : <p>لا يوجد حساب مستخدم مرتبط بهذا الموظف. الربط اختياري ولا يغيّر صلاحيات العضوية.</p>}
    <div className="workspace-page-summary"><h3>إكمال إتاحة الحضور الشخصي</h3><p>{snapshot?.linked ? 'رابط الحساب موجود. هذا لا يثبت وجود صلاحية الحضور؛ أكمل حزمة وصول العضو ثم راجع إعداد موقع العمل.' : 'اربط أولًا حساب عضو نشط بملف هذا الموظف، ثم أتح له الحضور الشخصي من حزم الوصول.'}</p><p className="field-hint">يحتاج الموظف عملًا ساريًا وموقعًا وسياسة حضور مهيأة وخدمة مفعلة. فك الربط يمنع التسجيل من الحساب السابق، ولا يمحو الحركات المسجلة.</p>{canInvite ? <Link className="secondary-button" href={`/tenant/${tenantId}/users?view=members${snapshot?.identity_visible && snapshot.email ? `&q=${encodeURIComponent(snapshot.email)}` : ''}`}>إدارة حزمة الحضور لحساب الموظف</Link> : <p>اطلب من مدير الأعضاء إضافة حزمة «الحضور الشخصي من الهاتف» للحساب المرتبط. لا تمنح صلاحية ربط الموظف صلاحية إدارة الأعضاء.</p>}</div>
    {accountState && accountMessages[accountState] && <p className={['delivery-failed','manual-review','create-failed','forbidden','subject-unavailable','setup','operation-error','readiness-link-failed'].includes(accountState)
      ? 'form-message error-message' : 'form-message'} role="status">{accountMessages[accountState]}</p>}
    {!snapshotError && !snapshot?.linked && canManage && <>
      <h3>ربط عضو موجود</h3>
      {optionsError || !options ? <p role="alert">تعذر تحميل قائمة الأعضاء المؤهلين.</p> : <>
        <form method="get" action={base} className="compact-form">
          <label htmlFor="user-link-query">البحث بالبريد أو الاسم</label>
          <input id="user-link-query" name="linkQuery" type="search" maxLength={100} defaultValue={query} />
          <input type="hidden" name="linkPage" value="1" />
          <button className="secondary-button" type="submit">بحث</button>
        </form>
        {options.items.length ? <form action={linkEmployeeUserAction} className="compact-form">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
          <label htmlFor="employee-user-id">عضو نشط وبريد مؤكد</label>
          <select id="employee-user-id" name="userId" required defaultValue="">
            <option value="" disabled>اختر عضوًا</option>
            {options.items.map((item) => <option key={item.user_id} value={item.user_id}>{item.display_name} — {item.email}</option>)}
          </select>
          <button className="primary-button" type="submit">ربط الحساب</button>
        </form> : <p>لا توجد عضوية نشطة مؤهلة لهذا البحث.</p>}
        <nav className="workspace-form-actions" aria-label="صفحات الأعضاء">
          {page > 1 && <Link className="secondary-button" href={`${base}?linkQuery=${encodeURIComponent(query)}&linkPage=${page - 1}`}>السابق</Link>}
          <span>صفحة {page}</span>
          {options.has_more && <Link className="secondary-button" href={`${base}?linkQuery=${encodeURIComponent(query)}&linkPage=${page + 1}`}>التالي</Link>}
        </nav>
      </>}
      {canInvite && <div className="workspace-page-summary"><p>لا يوجد حساب؟ أرسل دعوة العضوية، وبعد القبول ارجع هنا لتفعيل الربط.</p>
        <Link className="secondary-button" href={`/tenant/${tenantId}/users/invite?employeeId=${encodeURIComponent(employeeId)}`}>دعوة عضو جديد</Link></div>}
      {canProvisionAccount && <div className="workspace-page-summary">
        <h3>إنشاء حساب للموظف</h3>
        <p>يُنشأ الحساب دون أن يختار المسؤول كلمة مرور. سيؤكد الموظف بريده ويضع كلمة المرور، ثم تضاف له عضوية «عضو» ويرتبط حسابه بهذا الملف.</p>
        {accountProvisionError && <p className="form-message error-message" role="alert">تعذر تحميل حالة إنشاء الحساب. حدّث الصفحة قبل بدء طلب جديد.</p>}
        {provision && provision.state !== 'none' && provision.state !== 'activated' && <div className="record-meta">
          <p>حالة الطلب: {provision.state === 'pending' ? 'قيد الإنشاء' : provision.state === 'user_created'
            ? provision.delivery_state === 'sent' ? 'بانتظار تفعيل الموظف' : 'الحساب جاهز لإعادة إرسال رابط التفعيل'
            : 'مراجعة مطلوبة'}</p>
          {provision.target_email && <p>البريد: <bdi>{provision.target_email}</bdi></p>}
          {provision.state === 'manual_review' && <p role="alert">لن يتم اعتماد حساب لم تثبت ملكية هذا الطلب له.</p>}
          {['pending','user_created'].includes(provision.state) && provision.intent_id && <form action={retryEmployeeAccountActivationAction}>
            <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
            <input type="hidden" name="intentId" value={provision.intent_id} />
            <SubmitButton label={provision.state === 'pending' ? 'متابعة إنشاء الحساب' : 'إعادة إرسال رابط التفعيل'} pendingLabel="جارٍ الإرسال…" />
          </form>}
        </div>}
        {provision?.state === 'activated' && provision.currently_linked === false && <p className="form-message">الحساب السابق لم يعد مرتبطًا بهذا الموظف. يمكنك إنشاء حساب بديل.</p>}
        {canStartNewAccount && <form action={createEmployeeAccountAction} className="compact-form">
          <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
          <input type="hidden" name="requestKey" value={requestKey} />
          <label htmlFor="employee-account-email">بريد الموظف</label>
          <input id="employee-account-email" name="email" type="email" autoComplete="email" maxLength={254} required />
          <SubmitButton label="إنشاء الحساب وإرسال رابط التفعيل" pendingLabel="جارٍ إنشاء الحساب…" />
        </form>}
      </div>}
    </>}
    {!snapshotError && !accountProvisionError && currentlyLinkedProvision && canProvisionAccount && provision?.state === 'activated' && provision.password_ready !== true && provision.intent_id && <div className="workspace-page-summary">
      <h3>تأكيد جاهزية كلمة المرور</h3>
      <p>الحساب نشط بالفعل. يمكن إرسال رابط للموظف لتحديث كلمة المرور وتأكيد جاهزيتها دون تغيير العضوية أو الصلاحيات.</p>
      <form action={sendEmployeeAccountReadinessRecoveryAction}>
        <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="employeeId" value={employeeId} />
        <input type="hidden" name="intentId" value={provision.intent_id} />
        <SubmitButton label="إرسال رابط تأكيد كلمة المرور" pendingLabel="جارٍ الإرسال…" />
      </form>
    </div>}
  </section>;
}
