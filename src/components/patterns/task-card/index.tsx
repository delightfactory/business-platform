import Link from 'next/link';
import { ButtonLink } from '@/components/ui/primitives';
import { Icon, type IconName } from '@/components/ui/icon';
export type TaskPreview = { label: string; detail: string; href: string };
export function TaskCard({ title, description, href, count, more, preview = [], icon, action = 'افتح القائمة', scope }: {
  title: string; description: string; href: string; count?: number; more?: boolean; preview?: TaskPreview[];
  icon: IconName; action?: string; scope?: string;
}) {
  return <article className="task-card">
    <div className="task-card-domain"><Icon name={icon} size={16} /><span>{scope}</span></div>
    {count !== undefined && <div className="task-card-number"><bdi>{count}{more ? '+' : ''}</bdi></div>}
    <h3>{title}</h3>{count !== undefined && title.includes('الحضور') && <small className="field-hint">استثناءات اليوم</small>}<p>{count === undefined ? 'راجع الحالة والتفاصيل من مساحة العمل.' : more ? 'عينة من الطلبات المتاحة للمراجعة.' : count === 0 ? title.includes('الحضور') ? 'لا توجد استثناءات في قراءة اليوم؛ يمكنك مراجعة السجل.' : 'لا توجد عناصر في هذه القراءة.' : 'عناصر متاحة للمراجعة.'}</p>
    <details className="task-card-details"><summary>نطاق العرض والتفاصيل</summary><p>{description}</p></details>
    {preview.length > 0 && <ul className="task-card-preview">{preview.slice(0,3).map(item => <li key={item.href}><Link href={item.href}><span>{item.label}</span><small>{item.detail}</small></Link></li>)}</ul>}
    <div className="task-card-footer"><ButtonLink href={href}>{action}<Icon name="arrowLeft" size={16} /></ButtonLink>{more && <small>أول 3 طلبات؛ المزيد في القائمة</small>}</div>
  </article>;
}
