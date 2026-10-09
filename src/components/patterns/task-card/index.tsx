import Link from 'next/link';
import { Icon, type IconName } from '@/components/ui/icon';
export type TaskPreview = { label: string; detail: string; href: string };
export function TaskCard({ title, description, href, count, more, preview = [], icon, action = 'افتح القائمة', scope }: {
  title: string; description: string; href: string; count?: number; more?: boolean; preview?: TaskPreview[];
  icon: IconName; action?: string; scope?: string;
}) {
  return <article className="task-card">
    <div className="task-card-domain"><Icon name={icon} size={16} /><span>{scope}</span></div>
    {count !== undefined && <div className="task-card-number"><bdi>{count}{more ? '+' : ''}</bdi></div>}
    <h3>{title}</h3><p>{count === undefined ? 'راجع الحالة والتفاصيل من مساحة العمل.' : more ? 'عينة من الطلبات المتاحة للمراجعة.' : count === 0 ? 'لا توجد عناصر في هذه القراءة.' : 'عناصر متاحة للمراجعة.'}</p>
    <details className="task-card-details"><summary>نطاق العرض والتفاصيل</summary><p>{description}</p></details>
    {preview.length > 0 && <ul className="task-card-preview">{preview.slice(0,3).map(item => <li key={item.href}><Link href={item.href}><span>{item.label}</span><small>{item.detail}</small></Link></li>)}</ul>}
    <div className="task-card-footer"><Link href={href} className="primary-button">{action}<Icon name="arrowLeft" size={16} /></Link>{more && <small>أول 3 طلبات؛ المزيد في القائمة</small>}</div>
  </article>;
}
