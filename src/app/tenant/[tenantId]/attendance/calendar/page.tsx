import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { Button, ButtonLink, EmptyState, Field, HelpNote, Icon, Input, Message, PageHeader, Panel } from '@/components/ui';
import { PageFrame } from '@/components/context-navigation';
import { getWorkspaceClient, getWorkspaceUser } from '@/lib/workspace-access';
import { adjacentMonth, attendanceStates, calendarDateLabel, calendarMonthLabel, calendarWeeks, cairoToday, dayCountLabel, dayTotal, isAttendanceMonth, isCivilDate, MAX_ATTENDANCE_MONTH, MIN_ATTENDANCE_MONTH, readMonthCalendar } from '@/lib/attendance-calendar';
import styles from './calendar.module.css';
import { AttendanceWorkspaceTabs } from '../AttendanceWorkspaceTabs';

export const dynamic='force-dynamic';
type Props={params:Promise<{tenantId:string}>;searchParams:Promise<{month?:string|string[];date?:string;payroll_employer?:string;payroll_period?:string}>};
const weekdays=['السبت','الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة'];
const shortWeekdays=['سبت','أحد','اثن','ثلا','أرب','خمي','جمع'];

export default async function AttendanceCalendar({params,searchParams}:Props) {
  const {tenantId}=await params;
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(tenantId)) notFound();
  const query=await searchParams, today=cairoToday();
  const validMonth=isAttendanceMonth(query.month), invalidMonth=query.month!==undefined&&!validMonth;
  const month=validMonth?query.month as string:today.slice(0,7);
  const path=`/tenant/${tenantId}/attendance/calendar`;
  const scopePattern=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const payrollContext=scopePattern.test(query.payroll_employer??'')&&scopePattern.test(query.payroll_period??'')?{payroll_employer:query.payroll_employer!,payroll_period:query.payroll_period!}:null;
  const scopeQuery=payrollContext?`&${new URLSearchParams(payrollContext)}`:'';
  const currentHref=`${path}?month=${month}${scopeQuery}`;
  const dayHref=(date:string)=>`/tenant/${tenantId}/attendance?date=${date}${scopeQuery}`;
  const db=await getWorkspaceClient();
  if (!db) return <PageFrame><Panel><PageHeader title="تعذر الاتصال" description="لم نتمكن من تحميل تقويم الحضور."/><ButtonLink href={currentHref} variant="ghost">إعادة المحاولة</ButtonLink></Panel></PageFrame>;
  const {data:{user}}=await getWorkspaceUser(db);
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(currentHref)}`);
  const accessResult=await db.rpc('time_attendance_access_snapshot',{p_tenant_id:tenantId});
  const access=accessResult.data;
  if (accessResult.error||!access||typeof access!=='object'||Array.isArray(access)||access.can_view!==true) {
    return <PageFrame><Panel><PageHeader title="تقويم الحضور غير متاح" description="تحقق من عضويتك وصلاحيات الحضور لهذه الشركة."/></Panel></PageFrame>;
  }
  const response=await db.rpc('attendance_month_calendar',{p_tenant_id:tenantId,p_month:`${month}-01`});
  const calendar=response.error?null:readMonthCalendar(response.data,month);
  const totals=Object.fromEntries(attendanceStates.map(({key})=>[key,calendar?.days.reduce((n,day)=>n+day[key],0)??0]));
  const byDate=new Map(calendar?.days.map(day=>[day.date,day]));
  const previous=adjacentMonth(month,-1), next=adjacentMonth(month,1);
  const canOpen=access.can_manage===true||access.can_correct===true||access.can_approve===true;
  const reviewDays=calendar?.days.filter(day=>day.needs_review>0)??[];

  return <PageFrame footer="الحضور وسجل العمل">
    <PageHeader title="الحضور والانصراف" description="افتح أي يوم لعرض الموظفين وتسجيلاتهم."/>
    <AttendanceWorkspaceTabs tenantId={tenantId} current="calendar" date={isCivilDate(query.date)&&query.date.startsWith(month)?query.date:today.startsWith(month)?today:`${month}-01`} payrollEmployer={query.payroll_employer} payrollPeriod={query.payroll_period} />
    {invalidMonth&&<Message tone="info" role="status">الشهر المطلوب غير صالح؛ نعرض الشهر الحالي. اختر شهرًا بين 2000 و2100.</Message>}
    {access.entitlement_enabled!==true&&<Message tone="info">خدمة الحضور موقوفة حاليًا. يمكنك الاطلاع على السجلات السابقة دون إضافة أو تعديل.</Message>}
    <Panel className={styles.calendarPanel}>
      <div className={styles.monthToolbar}>
        <nav className={styles.monthNavigation} aria-label="تغيير شهر التقويم">
          {previous?<ButtonLink variant="ghost" href={`${path}?month=${previous}${scopeQuery}`} aria-label="الشهر السابق" icon="chevronLeft"/>:<span/>}
          <h2>{calendarMonthLabel(month)}</h2>
          {next?<ButtonLink variant="ghost" href={`${path}?month=${next}${scopeQuery}`} aria-label="الشهر التالي" icon="chevronRight"/>:<span/>}
        </nav>
        <form key={month} method="get" action={path} className={styles.monthForm}>
          {payrollContext&&<><input type="hidden" name="payroll_employer" value={payrollContext.payroll_employer}/><input type="hidden" name="payroll_period" value={payrollContext.payroll_period}/></>}
          <Field id="calendar-month" label="انتقل إلى شهر"><Input id="calendar-month" name="month" type="month" required min={MIN_ATTENDANCE_MONTH} max={MAX_ATTENDANCE_MONTH} pattern="[0-9]{4}-[0-9]{2}" placeholder="مثال: 2026-10" defaultValue={month}/></Field>
          <Button variant="ghost" type="submit">عرض الشهر</Button>
        </form>
      </div>
      {!calendar?<div className={styles.readError}><Message tone="bad" role="alert">تعذر تحميل ملخص الشهر. لم يتغير أي سجل بسبب قراءة التقويم.</Message><ButtonLink variant="ghost" href={currentHref}>إعادة المحاولة</ButtonLink></div>:<>
        <dl className={styles.monthTotals} aria-label="حالات سجلات الشهر المحفوظة">{attendanceStates.map(state=><div key={state.key} data-tone={state.tone}><dt><span aria-hidden="true">{state.symbol}</span>{state.label}</dt><dd>{totals[state.key]}<small>سجل</small></dd></div>)}</dl>
        {calendar.days.length===0&&<p className={styles.emptyMonth}>لا توجد سجلات محفوظة لهذا الشهر. يمكنك فتح يوم لعرض حالته.</p>}
        <table className={styles.calendar}>
          <caption>سجلات الحضور المحفوظة — {calendarMonthLabel(month)}</caption>
          <thead><tr>{weekdays.map((label,n)=><th key={label} scope="col" aria-label={label}><span className={styles.weekdayFull}>{label}</span><abbr className={styles.weekdayShort} title={label}>{shortWeekdays[n]}</abbr></th>)}</tr></thead>
          <tbody>{calendarWeeks(month).map((week,index)=><tr key={index}>{week.map((date,column)=>{
            if (!date) return <td key={`empty-${column}`} className={styles.emptyCell}/>;
            const day=byDate.get(date), total=day?dayTotal(day):0;
            const symbol=!day?'—':day.needs_review>0?'!':day.approved===total?'✓':'•';
            const compactCount=day?.needs_review||total;
            return <td key={date}><Link prefetch={false} id={`day-${date}`} href={dayHref(date)} className={styles.day} data-review={Boolean(day?.needs_review)} aria-current={date===today?'date':undefined}
              aria-label={`${calendarDateLabel(date)}${date===today?'، اليوم':''}: ${total?`${total} سجلًا — `:''}${dayCountLabel(day)}`}>
              <span className={styles.dayHeading}><span>{Number(date.slice(8))}</span>{date===today&&<small>اليوم</small>}</span>
              <span className={styles.dayStates}>{day?attendanceStates.filter(state=>day[state.key]>0).map(state=><span className={styles.stateLine} data-tone={state.tone} key={state.key}><span aria-hidden="true">{state.symbol}</span><span>{day[state.key]} {state.label}</span></span>):<span className={styles.noRecords}>لا سجلات</span>}</span>
              <span className={styles.compactState} aria-hidden="true">{symbol}<small>{compactCount||''}</small></span>
            </Link></td>;
          })}</tr>)}</tbody>
        </table>
        <p className={styles.symbolLegend}><span>! يحتاج مراجعة</span><span>✓ معتمد</span><span>• حالات أخرى</span><span>— لا سجلات</span></p>
        <div className={styles.calendarNotes}><span>الأعداد سجلات عمل، وليست عدد الموظفين أو إثبات حضورهم.</span><HelpNote label="كيف أقرأ التقويم؟"><p>! وعدده للسجلات التي تحتاج مراجعة، ✓ وعدده لكل سجلات اليوم المعتمدة، • وعدده لسجلات أخرى، — لا سجلات محفوظة. افتح اليوم لمراجعة التسجيلات والوقت الإضافي؛ اعتماد الحضور لا يعني اعتماد راتب.</p>{canOpen&&<p>فتح يوم قد يجهّز سجلاته حسب توقيت الدوام؛ قد تتغير أعداد التقويم بعد العودة.</p>}</HelpNote></div>
        {calendar.days.length>0&&<section className={styles.reviewAgenda} aria-labelledby="calendar-review-days"><h3 id="calendar-review-days">أيام تحتاج مراجعة</h3>
          {reviewDays.length?<ul>{reviewDays.map(day=><li key={day.date}><Link prefetch={false} href={dayHref(day.date)}><span><Icon name="alert" size={16}/>{calendarDateLabel(day.date)}</span><strong>{day.needs_review} سجل يحتاج مراجعة</strong><Icon name="chevronRight" size={16}/></Link></li>)}</ul>:<EmptyState title="لا توجد سجلات بحالة «يحتاج مراجعة»" description="راجع تفاصيل اليوم قبل اتخاذ قرار؛ قد توجد سجلات جاهزة للاعتماد أو وقت إضافي ينتظر المراجعة."/>}
        </section>}
      </>}
    </Panel>
    <div className={styles.continuation}><ButtonLink variant="ghost" prefetch={false} href={`/tenant/${tenantId}/attendance/review?date=${today}${scopeQuery}`}>قائمة مراجعة اليوم</ButtonLink></div>
  </PageFrame>;
}
