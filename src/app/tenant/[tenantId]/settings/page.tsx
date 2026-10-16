import { notFound, redirect } from 'next/navigation';
import { PageFrame, readTenantNavigationLinks } from '@/components/context-navigation';
import { Disclosure, EmptyState, Icon, PageHeader } from '@/components/ui';
import { workspaceMenu, type WorkspaceLink } from '@/components/shell/navigation-model';
import { getWorkspaceClient, getWorkspaceUser } from '@/lib/workspace-access';
import Link from 'next/link';

export const dynamic='force-dynamic';

const groups=[
  {title:'الشركة والفريق',icon:'building' as const,match:/\/(?:entities-sites|users|branding)(?:\/|$)/},
  {title:'الموظفون والدوام',icon:'users' as const,match:/\/people\/(?:organization|work-policies)(?:\/|$)/},
  {title:'الحضور والإجازات',icon:'calendar' as const,match:/\/(?:attendance\/sources|leave\/settings)(?:\/|$)/},
  {title:'الرواتب',icon:'wallet' as const,match:/\/payroll\/setup(?:\/|$)/},
];

function SettingsLinks({items}:{items:WorkspaceLink[]}) {
  return <ul className="workspace-settings-links">{items.map(item=><li key={item.href}><Link href={item.href}><span>{item.label}</span><Icon name="chevronLeft" size={17}/></Link></li>)}</ul>;
}

export default async function CompanySettings({params}:{params:Promise<{tenantId:string}>}) {
  const {tenantId}=await params;
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId))notFound();
  const db=await getWorkspaceClient();
  if(!db)return <PageFrame><EmptyState title="تعذر فتح الإعدادات" description="أعد المحاولة بعد قليل."/></PageFrame>;
  const {data:{user}}=await getWorkspaceUser(db);
  if(!user)redirect(`/auth/login?next=${encodeURIComponent(`/tenant/${tenantId}/settings`)}`);
  const {businessLinks,links}=await readTenantNavigationLinks(tenantId);
  const menu=workspaceMenu(`/tenant/${tenantId}`,businessLinks,links,'tenant');
  const grouped=new Set(groups.flatMap(group=>menu.settings.filter(item=>group.match.test(item.href.split('?')[0])).map(item=>item.href)));
  const otherSettings=menu.settings.filter(item=>!grouped.has(item.href));
  const extra=menu.areas.flatMap(area=>area.links.filter(item=>item.href!==area.destination.href));
  return <PageFrame><div className="workspace-settings-page">
    <PageHeader title="الإعدادات" description="إعدادات شركتك وفريقك، مجمّعة في مكان واحد."/>
    {!menu.settings.length?<EmptyState title="لا توجد إعدادات متاحة لحسابك" description="يمكنك متابعة العمل من القائمة الرئيسية."/>:<div className="workspace-settings-grid">{groups.map(group=>{
      const items=menu.settings.filter(item=>group.match.test(item.href.split('?')[0]));
      return items.length?<section className="workspace-section" key={group.title}><h2><Icon name={group.icon}/>{group.title}</h2><SettingsLinks items={items}/></section>:null;
    })}{otherSettings.length>0&&<section className="workspace-section"><h2>إعدادات أخرى</h2><SettingsLinks items={otherSettings}/></section>}</div>}
    {extra.length>0&&<Disclosure summary="أدوات إضافية"><SettingsLinks items={extra}/></Disclosure>}
  </div></PageFrame>;
}
