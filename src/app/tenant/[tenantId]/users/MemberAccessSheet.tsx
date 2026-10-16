'use client';

import { useState } from 'react';
import { Button, Checkbox, Disclosure, Message, Sheet } from '@/components/ui';
import { OfflineForm } from '@/components/offline-form';
import { OfflineSubmitButton } from '@/components/offline-submit-button';
import { BUNDLE_DOMAINS, BUNDLE_PRESETS, PEOPLE_ROLE_BUNDLES } from './bundles';
import { setTenantMemberPeopleBundlesAction } from './actions';
import styles from './member-access.module.css';

export function MemberAccessSheet({ tenantId, userId, email, initialKeys }: { tenantId: string; userId: string; email: string; initialKeys: string[] }) {
  const [open, setOpen] = useState(false);
  const [selected, setSelected] = useState(() => new Set(initialKeys));
  const added = PEOPLE_ROLE_BUNDLES.filter(bundle => selected.has(bundle.key) && !initialKeys.includes(bundle.key));
  const removed = PEOPLE_ROLE_BUNDLES.filter(bundle => !selected.has(bundle.key) && initialKeys.includes(bundle.key));
  const sensitiveAdded = added.filter(bundle => bundle.sensitive);
  function changeOpen(next: boolean) {
    if (next) setSelected(new Set(initialKeys));
    setOpen(next);
  }
  function toggle(key: string, checked: boolean) {
    setSelected(current => { const next = new Set(current); if (checked) next.add(key); else next.delete(key); return next; });
  }
  return <Sheet open={open} onOpenChange={changeOpen} bodyClassName={styles.body} title="صلاحيات العمل" description={`اختر مهام ${email}. دور مسؤول الشركة يبقى مستقلًا.`}
    trigger={<Button variant="ghost">تعديل الصلاحيات</Button>}>
    <OfflineForm action={setTenantMemberPeopleBundlesAction} className={styles.form}>
      <input type="hidden" name="tenantId" value={tenantId} /><input type="hidden" name="userId" value={userId} /><input type="hidden" name="memberEmail" value={email} />
      {initialKeys.map(key => <input key={key} type="hidden" name="expectedBundleKey" value={key} />)}
      <div className={styles.options}>
      <Disclosure className={styles.presetDisclosure} summary="إضافة مهام بقالب">
      <section className={styles.presets} aria-labelledby={`presets-${userId}`}><h3 id={`presets-${userId}`}>اختر قالبًا عند الحاجة</h3>
        <p className="field-hint">القالب يضيف إلى اختياراتك الحالية. راجع أثره ثم احفظ.</p>
        {BUNDLE_PRESETS.map(preset => <div key={preset.key}><div><strong>{preset.label}</strong><p>{preset.detail}</p></div>
          <Button variant="ghost" onClick={() => setSelected(current => new Set([...current, ...preset.keys]))}>إضافة {preset.label}</Button></div>)}
      </section></Disclosure>
      <p className={styles.selectedCount}>المهام المختارة: {selected.size}. افتح المجال لتعديل مهامه.</p>
      {BUNDLE_DOMAINS.map(domain => <Disclosure key={domain} className={styles.domain} open={PEOPLE_ROLE_BUNDLES.some(bundle => bundle.domain === domain && initialKeys.includes(bundle.key))}
        summary={<span>{domain}<span className={styles.domainCount}>{PEOPLE_ROLE_BUNDLES.filter(bundle => bundle.domain === domain && selected.has(bundle.key)).length} مختارة</span></span>}>
        <fieldset className={styles.group}><legend className="ui-sr">{domain}</legend>
        {PEOPLE_ROLE_BUNDLES.filter(bundle => bundle.domain === domain).map(bundle => <label key={bundle.key} className={bundle.sensitive ? styles.sensitive : undefined}>
          <Checkbox name="bundleKey" value={bundle.key} checked={selected.has(bundle.key)} onChange={event => toggle(bundle.key, event.target.checked)} />
          <span><strong>{bundle.label}</strong><small>{bundle.description}</small>{bundle.sensitive && <small className={styles.warning}>صلاحية حساسة — راجع أثرها قبل المنح</small>}</span>
        </label>)}
      </fieldset></Disclosure>)}
      </div>
      <section className={styles.preview} aria-label="مراجعة تعديل الصلاحيات" aria-live="polite">
        <h3>قبل الحفظ</h3><p><strong>سيُضاف:</strong> {added.length ? added.map(bundle => bundle.label).join('، ') : 'لا شيء'}</p>
        <p><strong>سيُزال:</strong> {removed.length ? removed.map(bundle => bundle.label).join('، ') : 'لا شيء'}</p>
        {sensitiveAdded.length > 0 && <Message tone="warn">صلاحيات حساسة ستُضاف: {sensitiveAdded.map(bundle => bundle.label).join('، ')}. راجع الوصف والأثر لكل اختيار.</Message>}
        <p className="field-hint">لا يغيّر هذا المحرر دور مسؤول الشركة أو أي صلاحيات مخصصة أخرى.</p>
        <OfflineSubmitButton label="حفظ الصلاحيات" pendingLabel="جارٍ الحفظ…" />
      </section>
    </OfflineForm>
  </Sheet>;
}
