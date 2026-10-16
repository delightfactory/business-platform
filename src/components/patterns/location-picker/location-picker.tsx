'use client';

import { useEffect, useRef, useState } from 'react';
import type { Circle, CircleMarker, Map as LeafletMap } from 'leaflet';
import { Button, Disclosure, Field, Input } from '@/components/ui';
import 'leaflet/dist/leaflet.css';
import styles from './location-picker.module.css';

export function LocationPicker({ prefix, latitude, longitude, radius }: { prefix: string; latitude?: number; longitude?: number; radius?: number }) {
  const [lat, setLat] = useState(latitude === undefined ? '' : String(latitude));
  const [lng, setLng] = useState(longitude === undefined ? '' : String(longitude));
  const [range, setRange] = useState(radius === undefined ? '' : String(radius));
  const [message, setMessage] = useState('اختر مقر العمل على الخريطة أو استخدم موقع جهازك وأنت في المقر.');
  const [locating, setLocating] = useState(false);
  const host = useRef<HTMLDivElement>(null);
  const map = useRef<LeafletMap | null>(null);
  const circle = useRef<Circle | null>(null);
  const marker = useRef<CircleMarker | null>(null);
  const mounted = useRef(false);
  const coordinates = useRef<HTMLDetailsElement>(null);

  useEffect(() => {
    mounted.current = true;
    let cancelled = false;
    void import('leaflet').then(L => {
      if (cancelled || !host.current) return;
      const instance = L.map(host.current, { scrollWheelZoom: false }).setView([latitude ?? 30.0444, longitude ?? 31.2357], latitude !== undefined && longitude !== undefined ? 16 : 5);
      map.current = instance;
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>', maxZoom: 19 }).addTo(instance);
      instance.on('click', event => {
        if (host.current?.closest('fieldset:disabled')) return;
        setLat(event.latlng.lat.toFixed(6));
        setLng(event.latlng.lng.toFixed(6));
        setMessage('تم اختيار موقع المقر. حدّد المسافة المسموح بها للحضور، ثم احفظ الإعدادات.');
      });
      circle.current = L.circle([latitude ?? 0, longitude ?? 0], { radius: radius ?? 0, color: '#0E6B5C', fillOpacity: .16, weight: 2 }).addTo(instance);
      marker.current = L.circleMarker([latitude ?? 0, longitude ?? 0], { radius: 6, color: '#fff', fillColor: '#0E6B5C', fillOpacity: 1, weight: 2 }).addTo(instance);
    }).catch(() => { if (!cancelled) { setMessage('تعذر تحميل الخريطة. استخدم موقع جهازك أو أدخل الموقع يدويًا.'); if(coordinates.current)coordinates.current.open=true; } });
    return () => { cancelled = true; mounted.current = false; map.current?.remove(); map.current = null; circle.current = null; marker.current = null; };
  }, [latitude, longitude, radius]);

  useEffect(() => {
    if (lat !== '' && lng !== '' && Number.isFinite(Number(lat)) && Number.isFinite(Number(lng))) {
      circle.current?.setLatLng([Number(lat), Number(lng)]).setRadius(Number(range) || 0);
      marker.current?.setLatLng([Number(lat), Number(lng)]);
    }
  }, [lat, lng, range]);

  function locate() {
    if (!navigator.geolocation) { setMessage('هذا المتصفح لا يتيح الموقع. اختر نقطة بالخريطة أو أدخل الإحداثيات.'); return; }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(position => {
      if (!mounted.current) return;
      if (host.current?.closest('fieldset:disabled')) { setLocating(false); return; }
      const point: [number, number] = [position.coords.latitude, position.coords.longitude];
      setLat(point[0].toFixed(6)); setLng(point[1].toFixed(6));
      map.current?.setView(point, 17);
      setMessage(`دقة موقع الجهاز نحو ${Math.round(position.coords.accuracy)} متر. عدّل النقطة إذا لزم، ثم احفظ وسيلة تسجيل الحضور.`);
      setLocating(false);
    }, () => { if (mounted.current) { setLocating(false); setMessage('تعذر تحديد موقع الجهاز. اسمح بالموقع على اتصال آمن، أو اختر النقطة بالخريطة أو الإحداثيات.'); } }, { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 });
  }

  return <div className={styles.picker} onInvalidCapture={event=>{
    const control=event.target;
    if(control instanceof HTMLInputElement&&['latitude','longitude'].includes(control.name)){
      if(coordinates.current)coordinates.current.open=true;
      setMessage('اختر مقر العمل على الخريطة أو أدخل موقعه يدويًا قبل الحفظ.');
    }
  }}>
    <div className={styles.heading}><div><h3>أين يقع مقر العمل؟</h3><p>اختر نقطة على الخريطة، أو استخدم موقع جهازك وأنت في المقر. احفظ النموذج لتأكيد الموقع.</p></div><Button onClick={locate} pending={locating} pendingLabel="جارٍ تحديد الموقع…">استخدم موقعي الحالي</Button></div>
    <div ref={host} className={styles.map} role="region" aria-label="خريطة اختيار مقر العمل؛ يمكن إدخال الإحداثيات مباشرة أدناه" />
    <p role="status" className={styles.message}>{message}</p>
    <Field id={`${prefix}-radius_m`} label="المسافة المسموح بها للحضور (متر)" help="مثال: 200 يسمح بالتسجيل من المقر وما حوله حتى مسافة 200 متر." required><Input name="radius_m" type="number" min={10} max={10000} step="any" required value={range} onChange={event => setRange(event.target.value)} placeholder="مثال: 200"/></Field>
    <Disclosure ref={coordinates} summary="إدخال الموقع يدويًا">
      <div className={styles.coordinates}>
        <Field id={`${prefix}-latitude`} label="خط العرض" required help="يُملأ من نقطة الخريطة؛ يمكنك إدخاله يدويًا إذا عرفت إحداثيات مقر العمل."><Input name="latitude" type="number" step="any" min={-90} max={90} required value={lat} onChange={event => setLat(event.target.value)}  placeholder="مثال: 30.0444"/></Field>
        <Field id={`${prefix}-longitude`} label="خط الطول" required help="يُملأ من نقطة الخريطة؛ يمكنك إدخاله يدويًا إذا عرفت إحداثيات مقر العمل."><Input name="longitude" type="number" step="any" min={-180} max={180} required value={lng} onChange={event => setLng(event.target.value)}  placeholder="مثال: 31.2357"/></Field>
      </div>
    </Disclosure>
  </div>;
}
