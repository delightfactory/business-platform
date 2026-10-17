import Image from 'next/image';
import brand from '@/lib/product-brand.json';

export function ProductBrand() {
  return <span className="product-brand">
    <Image className="product-brand-mark" src={brand.icon} alt="" width={40} height={40} />
    <span className="product-brand-name"><strong>{brand.nameAr}</strong><bdi>{brand.nameEn}</bdi></span>
  </span>;
}
