'use client';
import { Disclosure, Input, SegmentedControl } from '@/components/ui';
export type SetupValues = {
  tenantName: string; entityName: string; siteName: string; email: string;
  seatsMode: 'limited' | 'unlimited'; seatsLimit: string; sitesMode: 'limited' | 'unlimited'; sitesLimit: string;
};
export const initialSetupValues: SetupValues = { tenantName: '', entityName: '', siteName: 'المقر الرئيسي', email: '', seatsMode: 'limited', seatsLimit: '10', sitesMode: 'limited', sitesLimit: '1' };
export function CompanySetupFields({ values, onChange, mode }: { values: SetupValues; onChange: (key: keyof SetupValues, value: string) => void; mode: 'invite' | 'existing' }) {
  return <div className="operator-setup-fields">
    <div className="operator-setup-core"><div><label htmlFor="setup-company-name">اسم الشركة</label><Input id="setup-company-name" name="tenantName" required maxLength={160} value={values.tenantName} onChange={event => onChange('tenantName', event.target.value)}  placeholder="مثال: شركة النور"/></div>
      <div><label htmlFor="setup-admin-email">البريد الإلكتروني للمسؤول</label><Input id="setup-admin-email" name={mode === 'invite' ? 'targetEmail' : 'adminEmail'} type="email" dir="ltr" autoComplete="email" required maxLength={254} value={values.email} onChange={event => onChange('email', event.target.value)}  placeholder="مثال: name@example.com"/>
        <p className="field-hint">{mode === 'invite' ? 'سنرسل دعوة قبول إلى هذا البريد.' : 'يجب أن يكون الحساب موجودًا وبريده مؤكدًا.'}</p></div></div>
    <Disclosure onInvalidCapture={event => { event.currentTarget.open = true; }} summary={<span>تفاصيل الشركة والفرع<small>الفرع الأول: {values.siteName || 'اختر اسم الفرع'}</small></span>}><div className="operator-setup-core"><div><label htmlFor="setup-legal-name">الاسم القانوني (اختياري)</label><Input id="setup-legal-name" name="entityName" maxLength={160} placeholder="نستخدم اسم الشركة إذا تُرك فارغًا" value={values.entityName} onChange={event => onChange('entityName', event.target.value)} /></div>
      <div><label htmlFor="setup-site-name">اسم الفرع الأول</label><Input id="setup-site-name" name="siteName" required maxLength={160} value={values.siteName} onChange={event => onChange('siteName', event.target.value)}  placeholder="مثال: فرع مدينة نصر"/></div></div></Disclosure>
    <Disclosure onInvalidCapture={event => { event.currentTarget.open = true; }} summary={<span>حدود الاستخدام الأولية<small>المستخدمون: {values.seatsMode === 'unlimited' ? 'غير محدود' : values.seatsLimit} · الفروع: {values.sitesMode === 'unlimited' ? 'غير محدود' : values.sitesLimit}</small></span>}>
    <fieldset className="operator-setup-limits"><legend className="ui-sr">حدود الاستخدام الأولية</legend>
      {(['seats', 'sites'] as const).map(kind => <div key={kind}><h3>{kind === 'seats' ? 'المستخدمون' : 'الفروع'}</h3>
        <input type="hidden" name={`${kind}Mode`} value={values[`${kind}Mode`]} />
        <SegmentedControl label={kind === 'seats' ? 'نوع حد المستخدمين' : 'نوع حد الفروع'} value={values[`${kind}Mode`]}
          onChange={value => onChange(`${kind}Mode`, value)} options={[{ value: 'limited', label: 'عدد محدد' }, { value: 'unlimited', label: 'غير محدود' }]} />
        {values[`${kind}Mode`] === 'limited' && <><label htmlFor={`setup-${kind}-limit`}>{kind === 'seats' ? 'الحد الأقصى للمستخدمين' : 'الحد الأقصى للفروع'}</label><Input id={`setup-${kind}-limit`} name={`${kind}Limit`} type="number" min={1} max={2147483647} step={1} required value={values[`${kind}Limit`]} onChange={event => onChange(`${kind}Limit`, event.target.value)}  placeholder={kind === 'seats' ? 'مثال: 10' : 'مثال: 1'}/></>}
      </div>)}
    </fieldset></Disclosure>
  </div>;
}
