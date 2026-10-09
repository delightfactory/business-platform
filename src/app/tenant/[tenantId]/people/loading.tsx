import { Card, Skeleton } from '@/components/ui';

export default function PeopleLoading() {
  return <div role="status" aria-label="جارٍ تحميل الموظفين" className="ui-gallery-stack"><Skeleton style={{ width: '34%', height: 32 }} /><Card><div className="ui-gallery-stack"><Skeleton style={{ width: '65%', height: 44 }} />{[0, 1, 2, 3].map(row => <Skeleton key={row} style={{ width: '100%', height: 64 }} />)}</div></Card></div>;
}
