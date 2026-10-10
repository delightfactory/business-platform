'use client';
import { Message, FileInput, Checkbox } from '@/components/ui';
import { Button, Input, Select, Textarea } from '@/components/ui';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import Image from 'next/image';
import { useEffect, useRef, useState, useTransition, type FormEvent } from 'react';
import { saveTenantBrandingFormAction } from './actions';

type BrandColor = 'teal' | 'blue' | 'violet' | 'emerald';

export function BrandingEditor({
  tenantId,
  initialName,
  baseName,
  colorKey,
  logoUrl,
  hasStoredLogo,
  canManage,
}: {
  tenantId: string;
  initialName: string;
  baseName: string;
  colorKey: BrandColor;
  logoUrl: string | null;
  hasStoredLogo: boolean;
  canManage: boolean;
}) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHint0 = useId();
  const [name, setName] = useState(initialName);
  const [color, setColor] = useState<BrandColor>(colorKey);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [removeLogo, setRemoveLogo] = useState(false);
  const [reason, setReason] = useState('');
  const [error, setError] = useState('');
  const [pending, startTransition] = useTransition();
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => () => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
  }, [previewUrl]);

  function clearSelectedFile() {
    if (fileInput.current) fileInput.current.value = '';
    setFile(null);
    setPreviewUrl(null);
  }

  function submit(event: FormEvent<HTMLFormElement>) {
  if (blockOfflineSubmission(event)) return;
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setError('');
    startTransition(async () => {
      const result = await saveTenantBrandingFormAction({ error: '' }, formData);
      setError(result.error);
    });
  }

  const showOffline0 = offline && canManage && !pending;
 return (
    <div className="branding-editor-layout">
      <section className="branding-preview" data-brand={color} aria-labelledby="branding-preview-title">
        <p className="eyebrow" id="branding-preview-title">معاينة الهوية</p>
        <div className="branding-preview-card">
          {file && previewUrl ? <Image src={previewUrl} alt={`معاينة شعار ${name || baseName}`} width={80} height={80} unoptimized />
            : !removeLogo && logoUrl ? <Image src={logoUrl} alt={`شعار ${name || baseName}`} width={80} height={80} unoptimized />
              : <span className="branding-preview-mark" aria-hidden="true">م</span>}
          <strong><bdi>{name || baseName}</bdi></strong>
        </div>
        <p className="field-hint">هكذا سيظهر اسم الشركة وشعارها لفريقك. الاسم القانوني المسجل لا يتغير.</p>
      </section>

      {!canManage ? <Message tone="info"  role="status">تغيير الهوية متاح لمسؤول الشركة فقط.</Message> : (
        <form onSubmit={submit} className="auth-form" aria-busy={pending}>
          <input type="hidden" name="tenantId" value={tenantId} />
          <label htmlFor="tenant-brand-name">اسم الشركة الظاهر للفريق</label>
          <Input id="tenant-brand-name" name="displayName" value={name} maxLength={160}
            onChange={(event) => setName(event.currentTarget.value)} />
          <p className="field-hint">اتركه فارغًا لإبقاء اسم الشركة الحالي. لا يغيّر الاسم القانوني المسجل.</p>

          <label htmlFor="tenant-brand-color">اللون الرئيسي</label>
          <Select id="tenant-brand-color" name="color" value={color}
            onChange={(event) => setColor(event.currentTarget.value as BrandColor)}>
            <option value="teal">فيروزي</option>
            <option value="blue">أزرق</option>
            <option value="violet">بنفسجي</option>
            <option value="emerald">أخضر</option>
          </Select>

          <div className="branding-color-preview" aria-label="معاينة ألوان الهوية">{(['teal','blue','violet','emerald'] as const).map(key => <div key={key} data-brand={key} aria-label={key === 'teal' ? 'فيروزي' : key === 'blue' ? 'أزرق' : key === 'violet' ? 'بنفسجي' : 'أخضر'}><span className="branding-color-dot" /><strong>منصة الأعمال</strong><span className="branding-color-sample">إجراء أساسي</span></div>)}</div>
          <label htmlFor="tenant-brand-logo">الشعار</label>
          <p className="field-hint" id="tenant-brand-logo-help">اختر صورة PNG أو JPG أو WebP بحجم لا يتجاوز 2 ميجابايت.</p>
          <div className="branding-file-picker">
            <FileInput ref={fileInput} className="branding-file-input" id="tenant-brand-logo" name="logo"
              accept="image/png,image/jpeg,image/webp,.png,.jpg,.jpeg,.webp"
              aria-describedby="tenant-brand-logo-help tenant-brand-logo-selection"
            onChange={(event) => {
              const nextFile = event.currentTarget.files?.[0] ?? null;
              setFile(nextFile);
              setRemoveLogo(false);
              setPreviewUrl(nextFile ? URL.createObjectURL(nextFile) : null);
            }} />
            <label className="secondary-button branding-file-trigger" htmlFor="tenant-brand-logo">اختيار ملف الشعار</label>
            {file && <Button variant="ghost" className="branding-file-clear" type="button" onClick={clearSelectedFile}
              aria-label={`إلغاء اختيار ملف ${file.name}`}>إلغاء الاختيار</Button>}
            <span className="branding-file-name" id="tenant-brand-logo-selection" role="status" aria-live="polite" aria-atomic="true">
              {file?.name ?? (hasStoredLogo ? 'سيبقى الشعار الحالي كما هو.' : 'لم يتم اختيار ملف.')}
            </span>
          </div>
          {hasStoredLogo && <label className="check-option"><Checkbox name="removeLogo"  checked={removeLogo}
            disabled={Boolean(file)} onChange={(event) => setRemoveLogo(event.currentTarget.checked)} />إزالة الشعار من العرض</label>}
          {hasStoredLogo && !logoUrl && <Message tone="info"  role="status">تعذرت معاينة الشعار الحالي؛ يمكنك استبداله أو إزالة عرضه.</Message>}
          {hasStoredLogo && <p className="field-hint">سيبقى الشعار السابق محفوظًا عند تغييره أو إزالته من العرض.</p>}

          <label htmlFor="tenant-brand-reason">سبب التغيير</label>
          <Textarea id="tenant-brand-reason" name="reason" required minLength={3} maxLength={500} rows={3}
            value={reason} onChange={(event) => setReason(event.currentTarget.value)} />
          {error && <Message tone="bad"  role="alert">{error}</Message>}
          <Button variant="solid"  type="submit" disabled={offline || (pending)} aria-busy={pending} aria-describedby={showOffline0 ? offlineHint0 : undefined}>
            {pending && <span className="button-spinner" aria-hidden="true" />}
            {pending ? 'جارٍ الحفظ…' : 'حفظ الهوية'}
          </Button>
        {showOffline0 && <OfflineSubmissionNotice id={offlineHint0} purpose="continuation" />}</form>
      )}
    </div>
  );
}
