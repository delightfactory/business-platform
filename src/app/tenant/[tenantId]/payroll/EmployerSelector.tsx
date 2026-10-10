import styles from './payroll.module.css';
import { Button, Icon, Select } from '@/components/ui';
import {employerContext,type EmployerPage,type EmployerQuery} from './employer-context';
type Props={path:string;page:EmployerPage;employer:string;name:string;choices:{id:string;name:string}[];context:EmployerQuery;singleEmployer?:boolean;hint?:string};
export function EmployerSelector({path,page,employer,name,choices,context,singleEmployer=false,hint='احفظ تعديلاتك قبل تغيير جهة العمل. اختيار الجهة نفسها يحافظ على اختيارات الصفحة.'}:Props){
 if(singleEmployer)return null;
 const fields=employerContext(page,context);
 return <div className={styles.employerSelector}><form method="get" action={path} className={styles.filters} aria-label="اختيار جهة العمل">
 <input type="hidden" name="employer_scope" value={employer}/>
 {Object.entries(fields).map(([key,value])=><input key={key} type="hidden" name={key} value={value}/>)}
 <label htmlFor="payroll-employer"><span><Icon name="building" size={16} /> جهة العمل</span><Select id="payroll-employer" name="employer" defaultValue={employer} aria-describedby="payroll-employer-hint" required>
 {!choices.some(item=>item.id===employer)&&<option value={employer}>{name}</option>}
 {choices.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}
 </Select></label><Button type="submit" variant="ghost">عرض الجهة</Button>
 </form><p id="payroll-employer-hint" className="field-hint">{hint}</p></div>;
}
