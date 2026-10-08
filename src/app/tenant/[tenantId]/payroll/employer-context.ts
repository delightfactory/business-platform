import {uuid} from './rules';
import {kindNames} from './inputs/rules';
export type EmployerPage='workspace'|'setup'|'inputs'|'runs'|'advances';
export type EmployerQuery=Record<string,string|undefined>;
const contextKeys:Record<EmployerPage,readonly string[]>={
 workspace:['period','review_q'],
 setup:['period','review_q','before'],
 inputs:['period','q','after','records_after','employee','kind','head','review_view','review_q','review_after','review_employee','before'],
 runs:['period','q','view','after','employee','before'],
 advances:['advance','q','after','installment_after','history_before','period','new','employment','corrected_advance','correction_event','correction_case','correction_q','correction_after']
};
function validContext(key:string,value:string):boolean {
 if(['q','review_q','correction_q'].includes(key))return value.length<=120;
 if(key==='view'||key==='review_view')return value==='all'||value==='attention';
 if(key==='kind')return Object.hasOwn(kindNames,value);
 if(key==='new')return value==='1';
 if(key==='installment_after')return /^\d{1,3}$/.test(value);
 if(key==='before')return /^\d{4}-\d{2}-\d{2}$/.test(value);
 return uuid(value);
}
export function employerContext(page:EmployerPage,query:EmployerQuery):Record<string,string>{
 const result:Record<string,string>={};
 for(const key of contextKeys[page]){
  const value=query[key];
  if(typeof value==='string'&&value!==''&&validContext(key,value)&&(!key.startsWith('correction_')||uuid(query.advance??''))&&(key!=='corrected_advance'||query.new==='1'))result[key]=value;
 }
 return result;
}
export function normalizeEmployerScope(path:string,page:EmployerPage,query:EmployerQuery):string|null {
 if(query.employer_scope===undefined)return null;
 const selected=query.employer??'';
 const same=uuid(query.employer_scope)&&uuid(selected)&&query.employer_scope.toLowerCase()===selected.toLowerCase();
 return path+'?'+new URLSearchParams({employer:selected,...(same?employerContext(page,query):{})});
}
