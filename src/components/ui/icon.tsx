import { ArrowLeft, ArrowRight, Check, CheckCheck, ChevronDown, ChevronLeft, ChevronRight, X, Plus, Minus, Search, CalendarDays, Clock3, Users, UserRound, House, Wallet, Settings2, MapPin, Navigation, ShieldCheck, CircleAlert, CircleCheck, Info, LoaderCircle, LogOut, Menu, MoreHorizontal, Moon, Sun, Building2, FileText, Download, Upload, RefreshCw, WifiOff, Eye, Mail, CircleHelp, SlidersHorizontal } from 'lucide-react';
import type { SVGProps } from 'react';

const icons = { arrowLeft: ArrowLeft, arrowRight: ArrowRight, check: Check, checkCheck: CheckCheck, chevronDown: ChevronDown, chevronLeft: ChevronLeft, chevronRight: ChevronRight, close: X, plus: Plus, minus: Minus, search: Search, calendar: CalendarDays, clock: Clock3, users: Users, user: UserRound, home: House, wallet: Wallet, settings: Settings2, mapPin: MapPin, navigation: Navigation, shield: ShieldCheck, alert: CircleAlert, success: CircleCheck, info: Info, loader: LoaderCircle, logout: LogOut, menu: Menu, more: MoreHorizontal, moon: Moon, sun: Sun, building: Building2, file: FileText, download: Download, upload: Upload, refresh: RefreshCw, offline: WifiOff, eye: Eye, mail: Mail, help: CircleHelp, filter: SlidersHorizontal };
export type IconName = keyof typeof icons;
export type IconProps = SVGProps<SVGSVGElement> & { name: IconName; size?: number; label?: string };
export function Icon({ name, size = 20, label, className = '', ...props }: IconProps) {
  const Glyph = icons[name];
  const directional = ['arrowLeft', 'arrowRight', 'chevronLeft', 'chevronRight'].includes(name);
  return <Glyph size={size} strokeWidth={1.75} className={`ui-icon ${directional ? 'ui-icon-directional' : ''} ${className}`} aria-hidden={label ? undefined : true} aria-label={label} role={label ? 'img' : undefined} {...props} />;
}
