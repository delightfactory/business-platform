import { uuid } from '../../rules';

export function legacyConfigurationHref(tenantId:string,query:Record<string,string|undefined>) {
  const next=new URLSearchParams();
  for(const key of ['employer','head'] as const) if(uuid(query[key]??''))next.set(key,query[key]!);
  if(query.kind==='component'||query.kind==='policy')next.set('kind',query.kind);
  if(uuid(query.records_after??''))next.set('after',query.records_after!);
  if(uuid(query.period??''))next.set('return_period',query.period!);
  if(query.q&&query.q.length<=120)next.set('return_q',query.q);
  for(const key of ['review_view','review_q','review_after','review_employee'] as const) {
    const value=query[key];
    if(!value)continue;
    if(key==='review_view'?(value==='all'||value==='attention'):key==='review_q'?value.length<=120:uuid(value))next.set(key,value);
  }
  return `/tenant/${tenantId}/payroll/setup/configuration?${next}`;
}
