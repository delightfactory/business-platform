export function parsePeopleCsv(text: string): { line: number; cells: string[] }[] | string;
export const workforceCsvColumns: readonly (readonly [string, string])[];
export function mapWorkforceCsvHeaders(headers: string[] | undefined): string[] | string;
