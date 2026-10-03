/** Only the authorized server RPC supplies these request/output relationships. */
export type LeaveCorrectionContext = {
  request_id: string;
  employer_id: string;
  employment_id: string;
  outputs: {
    id: string;
    period_id: string;
    starts_on: string;
    ends_on: string;
    ever_paid: boolean;
    source_ids: string[];
  }[];
};

export function leaveCorrectionHref(tenant: string, context: LeaveCorrectionContext, output: string) {
  return `/tenant/${tenant}/payroll/corrections?${new URLSearchParams({
    kind: 'source_change', request: context.request_id, employer: context.employer_id,
    employee: context.employment_id, output,
  })}`;
}
