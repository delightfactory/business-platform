-- Additive corrections for Adam's five reviewed financial findings. No statutory qualification/public lock.
-- Historical Slice1–5 migrations remain unchanged. Exact asserted patches preserve their authority/ACL/lock logic.
CREATE FUNCTION payroll.component_interpretation(p_data jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT jsonb_build_object('calculation',p_data->>'calculation','base',COALESCE(p_data->>'base',''),'classification',p_data->>'classification','behavior',p_data->>'behavior','proration',COALESCE(p_data->>'proration','salary_proration'))
$f$;
CREATE FUNCTION payroll.recurring_interpretation_matches(p_manifest jsonb,p_assignment jsonb,p_component jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT COALESCE(p_assignment->'version'->'data'->'component_interpretation',(
  SELECT payroll.component_interpretation(i->'version'->'data') FROM jsonb_array_elements(p_manifest->'inputs')i
  WHERE i->'head'->>'kind'='component' AND i->'head'->>'id'=p_assignment->'version'->'data'->>'component_id'
   AND(i->'version'->>'effective_from')::date<=(p_assignment->'version'->>'effective_from')::date
   AND(i->'version'->>'created_at' IS NULL OR p_assignment->'version'->>'created_at' IS NULL OR(i->'version'->>'created_at')::timestamptz<=(p_assignment->'version'->>'created_at')::timestamptz)
  ORDER BY(i->'version'->>'effective_from')::date DESC,(i->'version'->>'revision')::int DESC LIMIT 1
 )) IS NOT DISTINCT FROM payroll.component_interpretation(p_component->'version'->'data')
$f$;
-- Immutable legacy assignments derive their original interpretation from versions available when saved.
-- New saves bind it explicitly; never accept caller-authored interpretation metadata.
CREATE FUNCTION payroll.contributed_adjustment_versions(p_manifest jsonb,p_output jsonb) RETURNS TABLE(id uuid) LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT DISTINCT(i->'version'->>'id')::uuid FROM jsonb_array_elements(p_manifest->'inputs')i
 JOIN jsonb_array_elements(p_output->'employees')e ON e->>'employment_id'=i->'head'->>'employment_id'
 CROSS JOIN LATERAL jsonb_array_elements(e->'lines')l CROSS JOIN LATERAL jsonb_array_elements(l->'details')d
 WHERE i->'head'->>'kind'='adjustment' AND i->'head'->>'period_id'=p_manifest->'period'->>'id' AND i->'version'->>'status'='approved'
  AND EXISTS(SELECT 1 FROM jsonb_array_elements(p_manifest->'employees')eligible WHERE eligible->'employment'->>'id'=e->>'employment_id')
  AND l->>'component'='adjustment:'||(i->'head'->>'id') AND l->>'classification' IN('earning','deduction')
  AND d->>'input_version'=i->'version'->>'id' AND(d->>'raw')::numeric=(i->'version'->'data'->>'amount')::numeric AND(l->>'amount')::numeric=(i->'version'->'data'->>'amount')::numeric
$f$;
-- Retained wrong flags are normalized only in a new candidate projection; stored periods/finals never change.
CREATE FUNCTION payroll.calendar_period_semantics(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE current_period payroll.periods%ROWTYPE;previous_period payroll.periods%ROWTYPE;current_calendar payroll.calendar_versions%ROWTYPE;previous_calendar payroll.calendar_versions%ROWTYPE;state text;projected jsonb;BEGIN
 SELECT * INTO current_period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 projected:=to_jsonb(current_period);state:='recorded_ordinary';
 IF current_period.is_transition THEN
  SELECT * INTO previous_period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND ends_on=current_period.starts_on-1;
  SELECT * INTO current_calendar FROM payroll.calendar_versions WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=current_period.calendar_version_id;
  SELECT * INTO previous_calendar FROM payroll.calendar_versions WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=previous_period.calendar_version_id;
  IF previous_period.id IS NULL OR current_calendar.cutoff_day IS NULL OR previous_calendar.cutoff_day IS NULL
   OR current_calendar.effective_from>current_period.starts_on OR(current_calendar.effective_until IS NOT NULL AND current_calendar.effective_until<=current_period.starts_on)
   OR previous_calendar.effective_from>previous_period.starts_on OR(previous_calendar.effective_until IS NOT NULL AND previous_calendar.effective_until<=previous_period.starts_on)
   OR extract(day FROM current_period.ends_on)<>least(current_calendar.cutoff_day,extract(day FROM date_trunc('month',current_period.ends_on)+interval '1 month - 1 day'))
   OR extract(day FROM previous_period.ends_on)<>least(previous_calendar.cutoff_day,extract(day FROM date_trunc('month',previous_period.ends_on)+interval '1 month - 1 day')) THEN state:='unverified';
  ELSIF current_calendar.cutoff_day IS DISTINCT FROM previous_calendar.cutoff_day THEN state:='verified_transition';
  ELSIF EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.period_id=p_period AND(f.period_snapshot->>'is_transition')::boolean) THEN state:='frozen_correction_required';
  ELSE state:='corrected_ordinary';projected:=jsonb_set(projected,'{is_transition}','false');END IF;
 END IF;
 RETURN jsonb_build_object('period',projected,'calendar_semantics',jsonb_build_object('state',state,'stored_is_transition',current_period.is_transition,'current_calendar',current_period.calendar_version_id,'previous_period',previous_period.id,'previous_calendar',previous_period.calendar_version_id,'current_cutoff',current_calendar.cutoff_day,'previous_cutoff',previous_calendar.cutoff_day));
END $f$;
DO $f$ DECLARE definition text;old text;new text;signature text;BEGIN
 -- R1: a new payment date/timezone is not a changed earning boundary. Derive prior cutoff from the actual last period.
 signature:='public.payroll_calendar_preview(uuid,uuid,date,integer,integer,text,text)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='''is_transition'',last_end IS NOT NULL';new:='''is_transition'',last_end IS NOT NULL AND p_cutoff IS DISTINCT FROM(SELECT v.cutoff_day FROM payroll.periods p JOIN payroll.calendar_versions v ON v.tenant_id=p.tenant_id AND v.id=p.calendar_version_id WHERE p.tenant_id=p_tenant AND p.employer_id=p_employer ORDER BY p.ends_on DESC LIMIT 1)';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_calendar';END IF;EXECUTE replace(definition,old,new);
 -- R2: bind semantics only after existing validation and receipt resolution. Original RPC intent remains caller data.
 signature:='public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='VALUES(p_tenant,p_employer,head.id,head.revision+1,p_data,p_from,p_until,next_status';new:='VALUES(p_tenant,p_employer,head.id,head.revision+1,CASE WHEN p_kind=''recurring'' THEN p_data||jsonb_build_object(''component_interpretation'',payroll.component_interpretation(component.data)) ELSE p_data END,p_from,p_until,next_status';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_assignment';END IF;EXECUTE replace(definition,old,new);
 signature:='payroll.build_review(jsonb)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='IF matches>1 THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue(''recurring_overlap'',hid,''payroll_inputs''));CONTINUE; END IF;';
 new:=old||' IF EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.manifest_recurring(employee_manifest,hid,component_head,d))a WHERE NOT payroll.recurring_interpretation_matches(employee_manifest,a,component)) THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue(''recurring_interpretation_changed'',hid,''payroll_inputs''));CONTINUE;END IF;';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_recurring_engine';END IF;definition:=replace(definition,old,new);
 -- R3: latest dated policy must cover every inclusive local date; expiry/cancellation suppresses older versions.
 old:='SELECT i INTO policy FROM jsonb_array_elements(p_manifest->''inputs'')i WHERE i->''head''->>''kind''=''policy'' AND(i->''version''->>''effective_from'')::date<=first_day ORDER BY(i->''version''->>''revision'')::int DESC LIMIT 1;';
 new:='SELECT i INTO policy FROM jsonb_array_elements(p_manifest->''inputs'')i WHERE i->''head''->>''kind''=''policy'' AND(i->''version''->>''effective_from'')::date<=first_day ORDER BY(i->''version''->>''effective_from'')::date DESC,(i->''version''->>''revision'')::int DESC LIMIT 1;';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_policy_selection';END IF;definition:=replace(definition,old,new);
 old:='mode:=policy->''version''->''data''->>''mode'';';
 new:=old||' IF EXISTS(SELECT 1 FROM generate_series(first_day,last_day,interval ''1 day'')dt LEFT JOIN LATERAL(SELECT i FROM jsonb_array_elements(p_manifest->''inputs'')i WHERE i->''head''->>''kind''=''policy'' AND(i->''version''->>''effective_from'')::date<=dt::date ORDER BY(i->''version''->>''effective_from'')::date DESC,(i->''version''->>''revision'')::int DESC LIMIT 1)current_policy ON true WHERE i IS NULL OR i->''version''->>''status''=''cancelled'' OR(i->''version''->>''effective_until'' IS NOT NULL AND(i->''version''->>''effective_until'')::date<=dt::date) OR i->''version''->''data''->>''mode'' IS DISTINCT FROM mode OR mode NOT IN(''calendar_days'',''fixed_30_day'')) THEN mode:=NULL;issues:=issues||jsonb_build_array(payroll.issue(''policy_coverage_gap'',NULL,''payroll_config''));END IF;';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_policy_coverage';END IF;definition:=replace(definition,old,new);
 IF position('payroll.round_fraction' IN definition)=0 OR position('_numerator' IN definition)=0 THEN RAISE EXCEPTION 'review_fix_requires_exact_rounding';END IF;
 -- Unknown history and already-frozen misclassification have an owned handoff, never guessed money.
 old:='IF mode IS NULL THEN issues:=';
 new:='IF p_manifest->''calendar_semantics''->>''state'' IN(''unverified'',''frozen_correction_required'') THEN mode:=NULL;issues:=issues||jsonb_build_array(payroll.issue(CASE WHEN p_manifest->''calendar_semantics''->>''state''=''frozen_correction_required'' THEN ''calendar_historical_correction_required'' ELSE ''calendar_history_unverified'' END,NULL,''payroll_config''));END IF; IF mode IS NULL THEN issues:=';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_calendar_history_blocker';END IF;definition:=replace(definition,old,new);
 EXECUTE replace(definition,'cube4-review-v2-exact','cube4-review-v3-source-safe');
 FOREACH signature IN ARRAY ARRAY['payroll.run_manifest(uuid,uuid,uuid)','public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'] LOOP
  definition:=pg_get_functiondef(signature::regprocedure);IF position('cube4-review-v2-exact' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_engine_identity';END IF;EXECUTE replace(definition,'cube4-review-v2-exact','cube4-review-v3-source-safe');
 END LOOP;
 -- Add actual immutable calendar provenance to calculation, freshness and displayed period classification.
 signature:='payroll.run_manifest(uuid,uuid,uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='''period'',(SELECT to_jsonb(p) FROM payroll.periods p WHERE p.tenant_id=p_tenant AND p.employer_id=p_employer AND p.id=p_period)';
 new:='''period'',payroll.calendar_period_semantics(p_tenant,p_employer,p_period)->''period'',''calendar_semantics'',payroll.calendar_period_semantics(p_tenant,p_employer,p_period)->''calendar_semantics''';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_calendar_manifest';END IF;EXECUTE replace(definition,old,new);
 signature:='payroll.stale_reasons(jsonb,jsonb)';definition:=pg_get_functiondef(signature::regprocedure);old:='ARRAY[''engine'',''legal_employer'',''period''';new:='ARRAY[''calendar_semantics'',''engine'',''legal_employer'',''period''';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_calendar_freshness';END IF;EXECUTE replace(definition,old,new);
 signature:='public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)';definition:=pg_get_functiondef(signature::regprocedure);old:='''is_transition'',bounds.is_transition';new:='''is_transition'',(payroll.calendar_period_semantics(p_tenant,p_employer,p_period)->''period''->>''is_transition'')::boolean';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_calendar_workspace';END IF;EXECUTE replace(definition,old,new);
 -- R4: only the exact approved version evidenced in the finalized employee line is consumed.
 signature:='payroll.append_final_output(uuid,uuid,uuid,uuid,integer,uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='AND ih.kind=''adjustment'' AND iv.status=''approved'' ORDER BY ih.id LOOP';new:='AND ih.kind=''adjustment'' AND iv.status=''approved'' AND iv.id IN(SELECT id FROM payroll.contributed_adjustment_versions(c.input_manifest,c.output)) ORDER BY ih.id LOOP';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_adjustment_consumption';END IF;EXECUTE replace(definition,old,new);
 -- R5: PostgreSQL accepts nonfinite/BC/six-digit dates. Payment evidence must be renderable ISO civil dates.
 signature:='public.payroll_record_payment(uuid,uuid,uuid,integer,text,date,text,text,jsonb,uuid,boolean,uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='OR p_date IS NULL OR length';new:='OR p_date IS NULL OR NOT isfinite(p_date) OR p_date<DATE ''0001-01-01'' OR p_date>DATE ''9999-12-31'' OR length';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_review_fix_payment_date';END IF;EXECUTE replace(definition,old,new);
END $f$;
REVOKE ALL ON FUNCTION payroll.calendar_period_semantics(uuid,uuid,uuid),payroll.component_interpretation(jsonb),payroll.recurring_interpretation_matches(jsonb,jsonb,jsonb),payroll.contributed_adjustment_versions(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;