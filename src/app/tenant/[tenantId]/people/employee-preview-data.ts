export type EmployeePreviewData = {
  id: string; code: string; name: string; status: string;
  employment: { employer: string; start_date: string; end_date: string | null; status: string } | null;
  assignment: { site: string; department: string | null; job: string | null; manager: string | null;
    valid_from: string; valid_until: string | null; is_scheduled: boolean } | null;
};
export type EmployeePreviewResult = { status: 'ready'; employee: EmployeePreviewData }
  | { status: 'unavailable' | 'signed-out' };

function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function nullableText(value: unknown): value is string | null {
  return value === null || typeof value === 'string';
}

export function projectEmployeePreview(value: unknown, employeeId: string): EmployeePreviewData | null {
  if (!record(value) || value.id !== employeeId || typeof value.code !== 'string'
    || typeof value.name !== 'string' || typeof value.status !== 'string') return null;
  const employment = value.employment;
  if (employment !== null && (!record(employment) || typeof employment.employer !== 'string'
    || typeof employment.start_date !== 'string' || !nullableText(employment.end_date)
    || typeof employment.status !== 'string')) return null;
  const assignment = value.assignment;
  if (assignment !== null && (!record(assignment) || typeof assignment.site !== 'string'
    || !nullableText(assignment.department) || !nullableText(assignment.job)
    || !nullableText(assignment.manager) || typeof assignment.valid_from !== 'string'
    || !nullableText(assignment.valid_until) || typeof assignment.is_scheduled !== 'boolean')) return null;
  return { id: employeeId, name: value.name, code: value.code, status: value.status,
    employment: employment === null ? null : { employer: employment.employer as string,
      start_date: employment.start_date as string, end_date: employment.end_date as string | null,
      status: employment.status as string },
    assignment: assignment === null ? null : { site: assignment.site as string,
      department: assignment.department as string | null, job: assignment.job as string | null,
      manager: assignment.manager as string | null, valid_from: assignment.valid_from as string,
      valid_until: assignment.valid_until as string | null, is_scheduled: assignment.is_scheduled as boolean } };
}
