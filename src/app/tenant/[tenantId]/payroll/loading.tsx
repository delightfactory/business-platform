import { Card, Skeleton } from '@/components/ui';

export default function PayrollLoading() {
  return <div role="status" aria-label="جارٍ تحميل الرواتب" className="ui-gallery-stack"><Skeleton style={{ width: '30%', height: 32 }} /><Skeleton style={{ width: '45%', height: 44 }} /><Card><div className="ui-gallery-stack"><Skeleton style={{ width: '65%', height: 24 }} /><Skeleton style={{ width: '100%', height: 100 }} /><Skeleton style={{ width: '100%', height: 64 }} /></div></Card></div>;
}
