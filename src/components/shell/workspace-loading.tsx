import { Skeleton } from '@/components/ui';
export function WorkspaceLoading() {
  return <div className="workspace-loading" role="status" aria-label="جارٍ فتح الصفحة">
    <span className="sr-only">جارٍ فتح الصفحة…</span>
    <Skeleton className="workspace-loading-title" />
    <Skeleton className="workspace-loading-description" />
    <div className="workspace-loading-grid">{[1,2,3].map(item => <Skeleton key={item} className="workspace-loading-card" />)}</div>
  </div>;
}
