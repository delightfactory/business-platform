'use client';
import { Message, FileInput, Checkbox } from '@/components/ui';
import { Button, Input } from '@/components/ui';
import { brandPresets, customBrandStyle, normalizeHexColor, resolveBrandColor } from '@/lib/brand-colors.mjs';
import { ReasonField } from '@/components/reason-field';
import { useId } from 'react';
import { OfflineSubmissionNotice, useOfflineSubmission } from '@/components/offline-submission';

import Image from 'next/image';
import { useEffect, useRef, useState, useTransition, type CSSProperties, type FormEvent } from 'react';
import { saveTenantBrandingFormAction } from './actions';

export function BrandingEditor({
  tenantId,
  initialName,
  baseName,
  colorKey,
  logoUrl,
  hasStoredLogo,
  canManage,
  isFirstSetup,
}: {
  tenantId: string;
  initialName: string;
  baseName: string;
  colorKey: string;
  logoUrl: string | null;
  hasStoredLogo: boolean;
  canManage: boolean;
  isFirstSetup: boolean;
}) {
 const { offline, blockOfflineSubmission } = useOfflineSubmission();
 const offlineHint0 = useId();
  const [name, setName] = useState(initialName);
  const [color, setColor] = useState(colorKey);
  const [colorCode, setColorCode] = useState(resolveBrandColor(colorKey));
  const validColor = normalizeHexColor(colorCode);
  const previewStyle = customBrandStyle(color);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [removeLogo, setRemoveLogo] = useState(false);
  const [reason, setReason] = useState(isFirstSetup ? 'إعداد هوية الشركة' : '');
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
    if (!validColor) { setError('اكتب كود لون صحيحًا، مثل #177D80.'); return; }
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
      <section className="branding-preview" data-brand={previewStyle ? 'custom' : color} style={previewStyle as CSSProperties} aria-labelledby="branding-preview-title">
        <p className="eyebrow" id="branding-preview-title">معاينة الهوية</p>
        <div className="branding-preview-card">
          {file && previewUrl ? <Image src={previewUrl} alt={`معاينة شعار ${name || baseName}`} width={80} height={80} unoptimized />
            : !removeLogo && logoUrl ? <Image src={logoUrl} alt={`شعار ${name || baseName}`} width={80} height={80} unoptimized />
              : <span className="branding-preview-mark" aria-hidden="true">م</span>}
          <strong><bdi>{name || baseName}</bdi></strong>
        </div>
        <div className="branding-preview-elements" aria-label="معاينة اللون على عناصر الواجهة"><span className="branding-color-sample">إجراء أساسي</span><span className="branding-preview-link">نص بلون الهوية</span></div>
        <p className="field-hint">هكذا سيظهر اسم الشركة وشعارها لفريقك. الاسم القانوني المسجل لا يتغير.</p>
      </section>

      {!canManage ? <Message tone="info"  role="status">تغيير الهوية متاح لمسؤول الشركة فقط.</Message> : (
        <form onSubmit={submit} className="auth-form" aria-busy={pending}>
          <input type="hidden" name="tenantId" value={tenantId} />
          <label htmlFor="tenant-brand-name">اسم الشركة الظاهر للفريق</label>
          <Input id="tenant-brand-name" name="displayName" value={name} maxLength={160}
            onChange={(event) => setName(event.currentTarget.value)}  placeholder="مثال: شركة النور"/>
          <p className="field-hint">اتركه فارغًا لإبقاء اسم الشركة الحالي. لا يغيّر الاسم القانوني المسجل.</p>

          <fieldset className="branding-color-fieldset"><legend>اللون الرئيسي</legend>
            <input type="hidden" name="color" value={validColor ? color : colorCode} />
            <div className="branding-palette" aria-label="ألوان جاهزة">{brandPresets.map(preset => <button key={preset.key} type="button" aria-pressed={validColor === preset.hex}
              onClick={() => { setColor(preset.key); setColorCode(preset.hex); }}><span style={{ background: preset.hex }} aria-hidden="true" />{preset.label}</button>)}</div>
            <div className="branding-color-inputs"><div><label htmlFor="tenant-brand-picker">اختر من الباليت</label>
              <input id="tenant-brand-picker" type="color" value={validColor || resolveBrandColor(color)}
                onChange={event => { setColor(event.currentTarget.value); setColorCode(event.currentTarget.value); }} /></div>
              <div><label htmlFor="tenant-brand-code">كود اللون</label><Input id="tenant-brand-code" value={colorCode} dir="ltr" spellCheck={false} autoComplete="off" maxLength={16}
                placeholder="#177D80" aria-invalid={!validColor} aria-describedby={!validColor ? 'tenant-brand-color-error' : undefined}
                onChange={event => { const value = event.currentTarget.value; setColorCode(value); const hex = normalizeHexColor(value); if (hex) setColor(hex); }}
                onBlur={() => { if (validColor) setColorCode(validColor); }} /></div></div>
            {!validColor && <p className="field-hint branding-color-error" id="tenant-brand-color-error">اكتب 3 أو 6 خانات من أرقام وحروف اللون، مثل #177D80.</p>}
          </fieldset>
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

          <ReasonField id="tenant-brand-reason" label="سبب التغيير" suggested={isFirstSetup}
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
