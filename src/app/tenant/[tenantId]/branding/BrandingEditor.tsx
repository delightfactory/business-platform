'use client';

import Image from 'next/image';
import { useEffect, useState, type CSSProperties } from 'react';
import { SubmitButton } from '@/components/submit-button';
import { saveTenantBrandingAction } from './actions';

const colors = {
  teal: '#126b68',
  blue: '#2563eb',
  violet: '#7c3aed',
  emerald: '#047857',
} as const;

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
  colorKey: keyof typeof colors;
  logoUrl: string | null;
  hasStoredLogo: boolean;
  canManage: boolean;
}) {
  const [name, setName] = useState(initialName);
  const [color, setColor] = useState<keyof typeof colors>(colorKey);
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [removeLogo, setRemoveLogo] = useState(false);
  const previewStyle = { '--color-brand': colors[color] } as CSSProperties;

  useEffect(() => () => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
  }, [previewUrl]);

  return (
    <div className="branding-editor-layout">
      <section className="branding-preview" style={previewStyle} aria-labelledby="branding-preview-title">
        <p className="eyebrow" id="branding-preview-title">معاينة الهوية</p>
        <div className="branding-preview-card">
          {file && previewUrl ? <Image src={previewUrl} alt={`معاينة شعار ${name || baseName}`} width={80} height={80} unoptimized />
            : !removeLogo && logoUrl ? <Image src={logoUrl} alt={`شعار ${name || baseName}`} width={80} height={80} unoptimized />
              : <span className="branding-preview-mark" aria-hidden="true">م</span>}
          <strong><bdi>{name || baseName}</bdi></strong>
        </div>
        <p className="field-hint">سيظهر الاسم واللون في مساحة الشركة. يظل الاسم القانوني للكيان منفصلًا.</p>
      </section>

      {!canManage ? <p className="form-message" role="status">تغيير الهوية متاح لمسؤول الشركة فقط.</p> : (
        <form action={saveTenantBrandingAction} className="auth-form">
          <input type="hidden" name="tenantId" value={tenantId} />
          <label htmlFor="tenant-brand-name">اسم العرض</label>
          <input id="tenant-brand-name" name="displayName" value={name} maxLength={160}
            onChange={(event) => setName(event.currentTarget.value)} />
          <p className="field-hint">اتركه فارغًا لاستخدام اسم الشركة الحالي. لا يغيّر الاسم القانوني للكيان.</p>

          <label htmlFor="tenant-brand-color">اللون الرئيسي</label>
          <select id="tenant-brand-color" name="color" value={color}
            onChange={(event) => setColor(event.currentTarget.value as keyof typeof colors)}>
            <option value="teal">فيروزي</option>
            <option value="blue">أزرق</option>
            <option value="violet">بنفسجي</option>
            <option value="emerald">أخضر</option>
          </select>

          <label htmlFor="tenant-brand-logo">الشعار (PNG أو JPG أو WebP، حتى 2MB)</label>
          <input id="tenant-brand-logo" name="logo" type="file" accept="image/png,image/jpeg,image/webp,.png,.jpg,.jpeg,.webp"
            onChange={(event) => {
              const nextFile = event.currentTarget.files?.[0] ?? null;
              setFile(nextFile);
              setRemoveLogo(false);
              setPreviewUrl(nextFile ? URL.createObjectURL(nextFile) : null);
            }} />
          {hasStoredLogo && <label className="check-option"><input name="removeLogo" type="checkbox" checked={removeLogo}
            disabled={Boolean(file)} onChange={(event) => setRemoveLogo(event.currentTarget.checked)} />إزالة الشعار من العرض</label>}
          {hasStoredLogo && !logoUrl && <p className="form-message" role="status">تعذرت معاينة الشعار الحالي؛ يمكنك استبداله أو إزالة عرضه.</p>}
          {hasStoredLogo && <p className="field-hint">سيبقى الشعار السابق محفوظًا عند تغييره أو إزالته من العرض.</p>}

          <label htmlFor="tenant-brand-reason">سبب التغيير</label>
          <textarea id="tenant-brand-reason" name="reason" required minLength={3} maxLength={500} rows={3} />
          <SubmitButton label="حفظ الهوية" pendingLabel="جارٍ الحفظ…" />
        </form>
      )}
    </div>
  );
}
