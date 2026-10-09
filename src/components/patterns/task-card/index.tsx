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
    <h3>{title}</h3>{count !== undefined && title.includes('الحضور') && <small className="field-hint">حالات اليوم التي تحتاج مراجعة</small>}<p>{count === undefined ? 'افتح القسم لمراجعة الحالة والتفاصيل.' : more ? 'عناصر تحتاج مراجعة؛ يوجد المزيد في القائمة.' : count === 0 ? title.includes('الحضور') ? 'لم تظهر حالات تحتاج مراجعة اليوم. يمكنك فتح السجل.' : 'لم تظهر طلبات تحتاج مراجعة الآن.' : 'افتح القائمة لمراجعة هذه العناصر.'}</p>
    <details className="task-card-details"><summary>{count === undefined ? 'تفاصيل المهمة' : 'ما الذي يشمله هذا العدد؟'}</summary><p>{description}</p></details>
    {preview.length > 0 && <ul className="task-card-preview">{preview.slice(0,3).map(item => <li key={item.href}><Link href={item.href}><span>{item.label}</span><small>{item.detail}</small></Link></li>)}</ul>}
    <div className="task-card-footer"><ButtonLink href={href}>{action}<Icon name="arrowLeft" size={16} /></ButtonLink>{more && <small>أول 3 طلبات؛ المزيد في القائمة</small>}</div>
  </article>;
}
