export function employeeSelection<T extends {id:string}>(choices:T[],requested?:string):T[]|null {
  if(!requested)return choices;
  const selected=choices.find(choice=>choice.id===requested);
  return selected?[selected,...choices.filter(choice=>choice.id!==requested)]:null;
}

export function replacementInputHref(href:string,employment:string):string {
  const [pathname,query='']=href.split('?');
  const params=new URLSearchParams(query);
  params.set('employee',employment);
  return `${pathname}?${params}`;
}
