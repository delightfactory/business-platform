import styles from './payroll.module.css';
import {employerContext,type EmployerPage,type EmployerQuery} from './employer-context';
type Props={path:string;page:EmployerPage;employer:string;name:string;choices:{id:string;name:string}[];context:EmployerQuery;singleEmployer?:boolean};
export function EmployerSelector({path,page,employer,name,choices,context,singleEmployer=false}:Props){
 if(singleEmployer)return null;
 const fields=employerContext(page,context);
 return <div><form method="get" action={path} className={styles.filters} aria-label="اختيار جهة العمل">
 <input type="hidden" name="employer_scope" value={employer}/>
 {Object.entries(fields).map(([key,value])=><input key={key} type="hidden" name={key} value={value}/>)}
 <label htmlFor="payroll-employer">جهة العمل<select id="payroll-employer" name="employer" defaultValue={employer} aria-describedby="payroll-employer-hint" required>
 {!choices.some(item=>item.id===employer)&&<option value={employer}>{name}</option>}
 {choices.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}
 </select></label><button type="submit" className="secondary-button">عرض جهة العمل</button>
 </form><p id="payroll-employer-hint" className="field-hint">اختيار الجهة نفسها يحفظ سياق الصفحة. تغيير الجهة يبدأ من بياناتها؛ احفظ أي تعديل لم ترسله قبل الانتقال.</p></div>;
}
