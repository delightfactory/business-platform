-- Bounded, nonfinancial Leave facts for a future payroll integration.
-- This endpoint does not calculate payroll, lock payroll periods, or mark a source consumed.
-- Future C4 must freshly revalidate source versions, reconcile Time precedence (including
-- half-day mapping), and lock source versions and its payroll period before emitting money.

CREATE FUNCTION public.leave_payroll_facts(
  p_tenant uuid,p_employer uuid,p_from date,p_to date,
  p_after_date date DEFAULT NULL,p_after_request_id uuid DEFAULT NULL,p_limit integer DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $f$
DECLARE actor uuid:=auth.uid(); read_permission text; lim integer:=p_limit;
  items jsonb; more boolean; next_date date; next_request uuid;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_employer IS NULL OR p_from IS NULL OR p_to IS NULL
    OR p_to<p_from OR p_to-p_from>30 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
    OR ((p_after_date IS NULL)<>(p_after_request_id IS NULL))
    OR (p_after_date IS NOT NULL AND (p_after_date<p_from OR p_after_date>p_to)) THEN
    RAISE EXCEPTION 'leave_payroll_facts_input_invalid' USING ERRCODE='22023';
  END IF;
  read_permission:=CASE
    WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view') THEN 'leave.view'
    WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage') THEN 'leave.manage'
    WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.approve') THEN 'leave.approve'
    ELSE 'leave.view' END;
  actor:=leave.authorized(p_tenant,read_permission,false);
  IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e
      WHERE e.tenant_id=p_tenant AND e.id=p_employer) THEN
    RAISE EXCEPTION 'leave_payroll_facts_unavailable' USING ERRCODE='P0002';
  END IF;

  WITH page AS MATERIALIZED (
    SELECT r.tenant_id,r.id request_id,r.employee_id,r.employment_id,r.employer_entity_id,
      r.leave_type_id,r.state request_state,r.version request_version,r.approved_preview_version,r.approved_by,r.approved_at,
      r.cancelled_at,d.leave_date,d.year_period_id,d.calendar_version_id,d.type_version_id,
      d.day_count_basis,d.pay_effect,d.balance_mode,d.is_weekly_rest,d.holiday_name,
      d.eligible,d.units original_units,d.is_half_day,
      ce.id cancellation_event_id,ce.cancellation_id,ce.event_key cancellation_event_key,
      ce.reason cancellation_reason,coalesce(ce.time_reconciliation_required,false) time_reconciliation_required
    FROM leave.request_days d
    JOIN leave.requests r ON r.tenant_id=d.tenant_id AND r.id=d.request_id
      AND d.preview_version=r.approved_preview_version
    LEFT JOIN LATERAL (
      SELECT x.id,x.cancellation_id,x.event_key,x.reason,x.time_reconciliation_required
      FROM leave.cancellation_events x
      WHERE x.tenant_id=r.tenant_id AND x.request_id=r.id
        AND ((x.event_key='hr.accepted' AND x.to_state='accepted') OR (x.event_key='hr.direct_cancelled' AND x.to_state='cancelled'))
      ORDER BY x.id DESC LIMIT 1
    ) ce ON true
    WHERE d.tenant_id=p_tenant AND r.employer_entity_id=p_employer
      AND d.employer_entity_id=p_employer AND d.leave_date BETWEEN p_from AND p_to
      AND r.state IN ('approved','cancelled') AND r.approved_preview_version IS NOT NULL
      AND (p_after_date IS NULL OR (d.leave_date,r.id)>(p_after_date,p_after_request_id))
    ORDER BY d.leave_date,r.id
    LIMIT lim+1
  ), enriched AS MATERIALIZED (
    SELECT p.*,
      CASE WHEN p.request_state='cancelled' THEN 0::numeric ELSE p.original_units END effective_units,
      coalesce(a.reversal_links,'[]'::jsonb) reversal_links,
      jsonb_build_object(
        'source_key',p.request_id::text||':'||p.approved_preview_version::text||':'||pg_catalog.to_char(p.leave_date,'YYYYMMDD'),
        'source_kind','leave.approved_day',
        'tenant_id',p.tenant_id,'request_id',p.request_id,'leave_date',p.leave_date,
        'employee_id',p.employee_id,'employment_id',p.employment_id,'employer_entity_id',p.employer_entity_id,
        'leave_type_id',p.leave_type_id,'type_version_id',p.type_version_id,
        'calendar_version_id',p.calendar_version_id,'year_period_id',p.year_period_id,
        'request_version',p.request_version,'approved_preview_version',p.approved_preview_version,
        'approved_by',p.approved_by,'approved_at',p.approved_at,
        'request_state',p.request_state,'cancelled_at',p.cancelled_at,
        'day_count_basis',p.day_count_basis,'pay_effect',p.pay_effect,'balance_mode',p.balance_mode,
        'eligible',p.eligible,'is_weekly_rest',p.is_weekly_rest,'holiday_name',p.holiday_name,
        'is_half_day',p.is_half_day,'original_units',p.original_units,
        'effective_units',CASE WHEN p.request_state='cancelled' THEN 0::numeric ELSE p.original_units END,
        'cancellation_event_id',p.cancellation_event_id,'cancellation_id',p.cancellation_id,
        'cancellation_event_key',p.cancellation_event_key,'cancellation_reason',p.cancellation_reason,
        'time_reconciliation_required',p.time_reconciliation_required,
        'reversal_links',coalesce(a.reversal_links,'[]'::jsonb),
        'projection_only',true,'consumed_by_payroll',false
      ) source_payload
    FROM page p
    LEFT JOIN LATERAL (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
          'account_id',c.account_id,'leave_type_id',c.leave_type_id,
          'consumed_ledger_entry_id',c.ledger_entry_id,'consumed_units',c.units,
          'reversal_entry_ids',coalesce(rev.entry_ids,'[]'::jsonb),
          'reversed_units',coalesce(rev.reversed_units,0::numeric)
        ) ORDER BY c.account_id,c.ledger_entry_id),'[]'::jsonb) reversal_links
      FROM leave.request_consumptions c
      LEFT JOIN LATERAL (
        SELECT coalesce(jsonb_agg(le.id ORDER BY le.id),'[]'::jsonb) entry_ids,
          coalesce(sum(le.delta_days),0::numeric) reversed_units
        FROM leave.ledger_entries le
        WHERE le.tenant_id=c.tenant_id AND le.account_id=c.account_id
          AND le.entry_kind='cancellation_reversal' AND le.reversal_of_entry_id=c.ledger_entry_id
      ) rev ON true
      WHERE c.tenant_id=p.tenant_id AND c.request_id=p.request_id
        AND c.preview_version=p.approved_preview_version AND c.leave_date=p.leave_date
    ) a ON true
  ), versioned AS MATERIALIZED (
    SELECT e.*,pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(e.source_payload::text,'UTF8')),'hex') source_version_hash,
      pg_catalog.row_number() OVER(ORDER BY e.leave_date,e.request_id) rn
    FROM enriched e
  )
  SELECT coalesce(pg_catalog.jsonb_agg(
      source_payload||pg_catalog.jsonb_build_object('source_version',request_version,'source_version_hash',source_version_hash)
      ORDER BY rn) FILTER(WHERE rn<=lim),'[]'::jsonb),
    EXISTS(SELECT 1 FROM versioned WHERE rn>lim),
    (SELECT leave_date FROM versioned WHERE rn=lim),
    (SELECT request_id FROM versioned WHERE rn=lim)
  INTO items,more,next_date,next_request
  FROM versioned;

  RETURN pg_catalog.jsonb_build_object('items',items,'limit',lim,'has_more',more,
    'next_after_date',CASE WHEN more THEN next_date END,
    'next_after_request_id',CASE WHEN more THEN next_request END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer)
  FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_payroll_facts(uuid,uuid,date,date,date,uuid,integer)
  TO authenticated;






