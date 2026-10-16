-- EDARA record-first payroll: one bounded read and atomic period + calculation.
-- Existing authorizers, source locks, candidate engine and receipts remain authoritative.
CREATE FUNCTION public.payroll_run_collection(p_tenant uuid,p_employer uuid,p_before date DEFAULT NULL,p_limit integer DEFAULT 24,p_period uuid DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE access jsonb;items jsonb;BEGIN
 access:=public.payroll_run_access(p_tenant);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_period IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 WITH selected AS (
  SELECT p.* FROM payroll.periods p WHERE p.tenant_id=p_tenant AND p.employer_id=p_employer AND(p_before IS NULL OR p.starts_on<p_before) AND(p_period IS NULL OR p.id=p_period) ORDER BY p.starts_on DESC LIMIT p_limit+1
 ), rows AS (
  SELECT p.id,p.starts_on,p.ends_on,p.payment_on,p.is_transition,r.status,r.id AS run_id,f.id AS output_id,
   CASE WHEN f.id IS NOT NULL THEN CASE WHEN platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.view') THEN (f.result->>'employee_count')::integer END ELSE (c.output->>'employee_count')::integer END AS employee_count,
   CASE WHEN f.id IS NOT NULL THEN CASE WHEN platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.view') THEN f.result->>'gross' END WHEN c.output->>'gross_complete'='true' THEN c.output->>'gross' END AS gross,
   CASE WHEN f.id IS NOT NULL THEN CASE WHEN platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.view') THEN f.result->>'net' END WHEN c.output->>'financially_qualified'='true' THEN c.output->>'net' END AS net,
   CASE WHEN f.id IS NOT NULL THEN 0 ELSE coalesce(jsonb_array_length(c.output->'issues'),0) END AS issue_count,
   b.paid,b.remaining,
   CASE WHEN f.id IS NOT NULL THEN 'final' WHEN p.starts_on > (clock_timestamp() AT TIME ZONE p.timezone)::date THEN 'upcoming' WHEN p.ends_on >= (clock_timestamp() AT TIME ZONE p.timezone)::date THEN 'ongoing' ELSE 'ended' END AS period_state
  FROM selected p
  LEFT JOIN LATERAL(SELECT x.* FROM payroll.runs x
   LEFT JOIN payroll.final_contexts published ON published.tenant_id=x.tenant_id AND published.run_id=x.id
   WHERE x.tenant_id=p_tenant AND x.employer_id=p_employer AND x.period_id=p.id
    AND(x.amendment_of IS NULL OR EXISTS(SELECT 1 FROM payroll.output_successions authority WHERE authority.tenant_id=x.tenant_id AND authority.replacement_output=published.id AND authority.original_output=x.amendment_of))
   ORDER BY (published.id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.output_successions superseded WHERE superseded.tenant_id=x.tenant_id AND superseded.original_output=published.id)) DESC,(x.status NOT IN('cancelled','superseded')) DESC,x.created_at DESC,x.id DESC LIMIT 1)r ON true
  LEFT JOIN payroll.candidates c ON c.tenant_id=p_tenant AND c.id=r.candidate_id
  LEFT JOIN payroll.final_contexts f ON f.tenant_id=p_tenant AND f.run_id=r.id
  LEFT JOIN LATERAL(SELECT sum(x.paid)::text AS paid,sum(x.remaining)::text AS remaining FROM payroll.payment_balances(p_tenant,f.id)x WHERE f.id IS NOT NULL AND(platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.view') OR platform_private.has_tenant_permission(p_tenant,auth.uid(),'payroll.payment_record')))b ON true
 )
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.starts_on DESC),'[]') INTO items FROM rows x;
 PERFORM public.payroll_run_access(p_tenant);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,auth.uid(),'run_collection_access',jsonb_build_object('before',p_before,'count',least(jsonb_array_length(items),p_limit)));
 RETURN jsonb_build_object('items',items - p_limit,'has_more',jsonb_array_length(items)>p_limit);
END $$;

CREATE FUNCTION public.payroll_create_run(p_tenant uuid,p_employer uuid,p_creation jsonb,p_attempt uuid,p_calendar_attempt uuid,p_run_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid;intent jsonb;receipt payroll.command_receipts%ROWTYPE;calendar jsonb;result jsonb;period uuid;BEGIN
 actor:=payroll.authorized(p_tenant,'payroll.prepare',true);
 IF p_attempt IS NULL OR p_calendar_attempt IS NULL OR p_run_attempt IS NULL OR p_attempt=p_calendar_attempt OR p_attempt=p_run_attempt OR p_calendar_attempt=p_run_attempt OR p_creation IS NULL OR jsonb_typeof(p_creation)<>'object' OR p_creation->>'mode' IS NULL OR p_creation->>'mode' NOT IN('first','next','existing') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 IF p_creation->>'mode'<>'existing' THEN
  PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true);
  IF jsonb_typeof(p_creation->'reviewed') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 ELSIF coalesce(p_creation->>'period','')!~'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM payroll.lock_scope(p_tenant,p_employer);
 intent:=jsonb_build_object('operation','create_calculate','employer',p_employer,'creation',p_creation,'calendar_attempt',p_calendar_attempt,'run_attempt',p_run_attempt);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 IF p_creation->>'mode'='existing' THEN
  period:=(p_creation->>'period')::uuid;
  IF NOT EXISTS(SELECT 1 FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=period) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  PERFORM payroll.lock_run_scope(p_tenant,p_employer,period);
  IF EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=period) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514';END IF;
  IF EXISTS(SELECT 1 FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=period AND status<>'cancelled') THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409';END IF;
 ELSIF p_creation->>'mode'='next' THEN
  calendar:=public.payroll_generate_next_period(p_tenant,p_employer,(p_creation->>'revision')::integer,p_calendar_attempt,p_creation->'reviewed');
 ELSE
  IF EXISTS(SELECT 1 FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer) THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409';END IF;
  calendar:=public.payroll_save_calendar(p_tenant,p_employer,(p_creation->>'start')::date,(p_creation->>'cutoff')::integer,(p_creation->>'payment')::integer,p_creation->>'month',p_creation->>'timezone',(p_creation->>'revision')::integer,p_calendar_attempt,p_creation->'reviewed','إنشاء أول مسير للرواتب');
 END IF;
 IF p_creation->>'mode'<>'existing' THEN period:=(calendar->>'period_id')::uuid;END IF;
 result:=public.payroll_run_command(p_tenant,p_employer,period,NULL,0,'calculate','',p_run_attempt)||jsonb_build_object('period_id',period);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,actor,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'payroll.prepare',true);
 IF p_creation->>'mode'<>'existing' THEN PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true);END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.payroll_run_collection(uuid,uuid,date,integer,uuid),public.payroll_create_run(uuid,uuid,jsonb,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_run_collection(uuid,uuid,date,integer,uuid),public.payroll_create_run(uuid,uuid,jsonb,uuid,uuid,uuid) TO authenticated;
