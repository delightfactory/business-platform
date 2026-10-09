'use client';

import * as Dialog from '@radix-ui/react-dialog';
import { Avatar, Icon, StatusBadge, buttonClassName } from '@/components/ui';
import { useEffect, useRef, useState } from 'react';
import { projectEmployeePreview, type EmployeePreviewResult, type EmployeePreviewData } from './employee-preview-data';
import styles from './employee-preview.module.css';

type State = EmployeePreviewResult | { status: 'loading' };

export function EmployeePreview({ href, name, code, employeeId }: {
  href: string; name: string; code: string; employeeId: string;
}) {
  const [open, setOpen] = useState(false);
  const [state, setState] = useState<State>({ status: 'loading' });
  const trigger = useRef<HTMLAnchorElement>(null);
  const request = useRef<AbortController | null>(null);

  useEffect(() => () => request.current?.abort(), []);

  async function load() {
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    setState({ status: 'loading' });
    try {
      const response = await fetch(`${href}/preview`, { credentials: 'same-origin',
        cache: 'no-store', signal: controller.signal });
      const result: unknown = response.ok ? await response.json() : null;
      if (controller.signal.aborted || request.current !== controller) return;
      if (result && typeof result === 'object' && !Array.isArray(result) && 'status' in result) {
        if (result.status === 'signed-out') { setState({ status: 'signed-out' }); return; }
        if (result.status === 'ready' && 'employee' in result) {
          const employee = projectEmployeePreview(result.employee, employeeId);
          if (employee) { setState({ status: 'ready', employee }); return; }
        }
      }
      setState({ status: 'unavailable' });
    } catch {
      if (!controller.signal.aborted && request.current === controller) setState({ status: 'unavailable' });
    }
  }

  function close() {
    request.current?.abort();
    request.current = null;
    setOpen(false);
    setState({ status: 'loading' });
  }

  return <>
    <a ref={trigger} className={buttonClassName('ghost')} href={href} aria-haspopup="dialog"
      aria-label={`معاينة ${name}`} onClick={(event) => {
        if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
        event.preventDefault(); setOpen(true); void load();
      }}><Icon name="eye" size={16} />معاينة</a>
    <Dialog.Root open={open} onOpenChange={(nextOpen) => { if (!nextOpen) close(); }}>
      <Dialog.Portal>
        <Dialog.Overlay className={styles.overlay} />
        <Dialog.Content className={styles.sheet} dir="rtl" aria-modal="true" onCloseAutoFocus={(event) => {
          event.preventDefault();
          if (trigger.current?.isConnected) trigger.current.focus();
          else document.getElementById('people-query')?.focus();
        }}>
          <header className={styles.header}><div>
            <Dialog.Title className={styles.title}>معاينة الموظف</Dialog.Title>
            <Dialog.Description className="field-hint">للقراءة فقط؛ التعديل من الملف الكامل.</Dialog.Description>
          </div><Dialog.Close className="ui-icon-button ui-button ui-button-ghost" aria-label="إغلاق معاينة الموظف"><Icon name="close" /></Dialog.Close></header>
          <div className={styles.body} aria-busy={state.status === 'loading'}>
            {state.status === 'ready' ? <PreviewContent employee={state.employee} /> : <>
              <h2 className={styles.name}>{name}</h2><p className="record-meta">رمز الموظف: <bdi>{code}</bdi></p>
              {state.status === 'loading' ? <p role="status">جارٍ تحميل الملخص…</p> : <div role="alert">
                <h3>{state.status === 'signed-out' ? 'تحتاج تسجيل الدخول' : 'الملخص غير متاح'}</h3>
                <p>{state.status === 'signed-out' ? 'افتح الملف الكامل لتسجيل الدخول والمتابعة.'
                  : 'تعذر التحقق من الملخص. أعد المحاولة أو افتح الملف الكامل للتحقق من الوصول.'}</p>
                {state.status === 'unavailable' && <button className="secondary-button" type="button" onClick={() => { void load(); }}>إعادة المحاولة</button>}
              </div>}
            </>}
          </div>
          <footer className={styles.footer}><a className={buttonClassName()} href={href}><Icon name="user" size={18} />فتح الملف الكامل</a></footer>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  </>;
}

function PreviewContent({ employee }: { employee: EmployeePreviewData }) {
  const employment = employee.employment;
  const assignment = employee.assignment;
  const ended = employment?.status === 'ended';
  return <>
    <div className={styles.identity}><Avatar name={employee.name} size={64} status={employee.status === 'active' ? 'ok' : 'neutral'} /><h2 className={styles.name}>{employee.name}</h2></div>
    <p className="record-meta">رمز الموظف: <bdi>{employee.code}</bdi></p>
    <StatusBadge tone={employee.status === 'active' ? 'ok' : 'neutral'} label={employee.status === 'active' ? 'نشط' : employee.status === 'scheduled' ? 'مجدول' : employee.status === 'ended' ? 'انتهت خدمته' : employee.status === 'inactive' ? 'غير نشط' : 'حالة غير معروفة'} />
    <section className={styles.section}><h3>التوظيف</h3>
      {employment ? <dl className={styles.details}>
        <dt>جهة العمل</dt><dd>{employment.employer}</dd>
        <dt>بداية العمل</dt><dd><bdi>{employment.start_date}</bdi></dd>
        {employment.end_date && <><dt>{ended ? 'انتهى العمل في' : 'نهاية العمل المسجلة'}</dt><dd><bdi>{employment.end_date}</bdi></dd></>}
      </dl> : <p>لا يوجد سجل توظيف.</p>}
    </section>
    <section className={styles.section}><h3>{ended ? 'التكليف عند انتهاء العمل' : assignment?.is_scheduled ? 'التكليف المقرر' : 'تكليف العمل'}</h3>
      {assignment ? <dl className={styles.details}>
        <dt>الموقع</dt><dd>{assignment.site}</dd>
        <dt>القسم</dt><dd>{assignment.department ?? 'غير محدد'}</dd>
        <dt>الوظيفة</dt><dd>{assignment.job ?? 'غير محددة'}</dd>
        <dt>المدير المباشر</dt><dd>{assignment.manager ?? 'غير محدد'}</dd>
        <dt>بداية التكليف</dt><dd><bdi>{assignment.valid_from}</bdi></dd>
        {assignment.valid_until && <><dt>نهاية التكليف</dt><dd><bdi>{assignment.valid_until}</bdi></dd></>}
      </dl> : <p>لا يوجد تكليف عمل.</p>}
    </section>
  </>;
}
