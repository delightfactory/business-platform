export const brandPresets: readonly { key: string; label: string; hex: string }[];
export function normalizeHexColor(value: unknown): string | null;
export function normalizeBrandColor(value: unknown): string | null;
export function resolveBrandColor(value: unknown): string;
export function contrastRatio(first: string, second: string): number;
export function customBrandStyle(value: unknown): Record<string, string> | undefined;
