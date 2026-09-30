import Link from 'next/link';
import { linkEmployeeUserAction, unlinkEmployeeUserAction } from '../employee-user-link-actions';

export type LinkSnapshot = { linked: boolean; identity_visible: boolean; link_id: string | null; user_id: string | null; email: string | null; display_name: string | null; linked_at: string | null };
export type Options = { items: Array<{ user_id: string; email: string; display_name: string }>; page: number; page_size: number; has_more: boolean };

export function EmployeeUserLinkPanel({ tenantId, employeeId, canManage, canInvite, snapshot, snapshotError, options, optionsError,
  query, page, state }: { tenantId: string; employeeId: string; canManage: boolean; snapshot: LinkSnapshot | null;
  canInvite: boolean; snapshotError: boolean; options: Options | null; optionsError: boolean; query: string; page: number; state?: string }) {
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
      <div className="workspace-page-summary"><p>لا يوجد حساب؟ يحتاج إرسال الدعوة إلى صلاحية إدارة مستخدمي الشركة؛ بعد القبول ارجع هنا لتفعيل الربط.</p>
        {canInvite && <Link className="secondary-button" href={`/tenant/${tenantId}/users/invite?employeeId=${encodeURIComponent(employeeId)}`}>دعوة عضو جديد</Link>}</div>
    </>}
  </section>;
}
