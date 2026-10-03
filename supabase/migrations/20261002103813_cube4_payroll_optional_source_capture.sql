-- G4 capture foundation only: no money reconciliation, source write, freeze or consumption.
CREATE FUNCTION payroll.optional_capture_authorized(p_tenant uuid,p_employer uuid) RETURNS void
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE permission text;BEGIN
 SELECT x INTO permission FROM unnest(ARRAY['payroll.prepare','payroll.review','payroll.approve','payroll.lock','payroll.view'])x
 WHERE platform_private.has_tenant_permission(p_tenant,auth.uid(),x) LIMIT 1;
 IF permission IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 PERFORM payroll.authorized(p_tenant,permission,false);
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN
  RAISE EXCEPTION 'payroll_employer_unavailable' USING ERRCODE='P0002';END IF;
END $f$;
CREATE FUNCTION payroll.capture_quantity(p_value jsonb) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE value text:=p_value#>>'{}';BEGIN
 IF value IS NULL THEN RETURN NULL;END IF;
 IF value !~ '^[0-9]+([.][0-9]+)?$' OR length(value)>32 THEN RAISE EXCEPTION 'payroll_optional_source_invalid' USING ERRCODE='22023';END IF;
 RETURN value::numeric;
END $f$;
CREATE FUNCTION payroll.capture_time_window(p_tenant uuid,p_employer uuid,p_from date,p_to date) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE items jsonb;BEGIN
 PERFORM payroll.optional_capture_authorized(p_tenant,p_employer);
 IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>30 THEN RAISE EXCEPTION 'payroll_optional_window_invalid' USING ERRCODE='22023';END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()) THEN RETURN '[]'::jsonb;END IF;
 WITH scoped AS MATERIALIZED(
  SELECT i.*,f.id fact_id,f.version fact_version,f.interpretation_id,f.corrects_fact_id,f.fact,q.version interpretation_version,ce.id classification_evidence_id
  FROM time.work_instances i
  JOIN people.employments h ON h.tenant_id=i.tenant_id AND h.id=i.employment_id AND h.employee_id=i.employee_id
  JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id
  JOIN LATERAL(SELECT af.* FROM time.attendance_facts af WHERE af.tenant_id=i.tenant_id AND af.work_instance_id=i.id ORDER BY af.version DESC LIMIT 1)f ON true
  JOIN time.interpretations q ON q.tenant_id=f.tenant_id AND q.id=f.interpretation_id AND q.work_instance_id=i.id
  LEFT JOIN time.classification_evidence ce ON ce.tenant_id=q.tenant_id AND ce.interpretation_id=q.id
  WHERE i.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible
   AND i.operational_date BETWEEN p_from AND p_to AND i.operational_date>=h.start_date AND(h.end_date IS NULL OR i.operational_date<=h.end_date)
   AND i.status='approved' AND f.fact->>'outcome' IN('worked','absence','leave_covered')
  ORDER BY i.operational_date,i.employment_id,i.id LIMIT 20001
 ) SELECT COALESCE(jsonb_agg(jsonb_build_object(
  'work_instance_id',s.id,'date',s.operational_date,'employee_id',s.employee_id,'employment_id',s.employment_id,
  'assignment_id',s.assignment_id,'policy_template_id',s.policy_template_id,'policy_version',s.policy_version,'timezone',s.timezone_name,
  'fact_id',s.fact_id,'fact_version',s.fact_version,'corrects_fact_id',s.corrects_fact_id,'interpretation_id',s.interpretation_id,
  'interpretation_version',s.interpretation_version,'classification_evidence_id',s.classification_evidence_id,'outcome',s.fact->>'outcome',
  'leave_bindings',COALESCE((SELECT jsonb_agg(jsonb_build_object('request_id',v->>'request_id','approved_preview_version',v->'approved_preview_version','date',v->>'leave_date','units',payroll.capture_quantity(v->'units'),'mapping_state',v->>'mapping_state','policy_template_id',v->>'policy_template_id','policy_version',v->'policy_version','algorithm_version',v->'algorithm_version') ORDER BY v->>'request_id',v->>'leave_date') FROM jsonb_array_elements(CASE WHEN jsonb_typeof(s.fact->'leave_sources')='array' THEN s.fact->'leave_sources' ELSE '[]' END)v),'[]'),
  'absence_units',payroll.capture_quantity(s.fact->'absence_units'),'leave_units',payroll.capture_quantity(s.fact->'leave_units'),
  'worked_minutes',payroll.capture_quantity(s.fact->'worked_minutes'),'gross_worked_minutes',payroll.capture_quantity(s.fact->'gross_worked_minutes'),
  'scheduled_break_minutes',payroll.capture_quantity(s.fact->'scheduled_break_minutes'),'late_minutes',payroll.capture_quantity(s.fact->'late_minutes'),
  'early_leave_minutes',payroll.capture_quantity(s.fact->'early_leave_minutes'),
  'classification_reconciliation_required',COALESCE((time.attendance_fact_context_status(p_tenant,s.id)->>'classification_reconciliation_required')::boolean,false),
  'overtime',COALESCE((SELECT jsonb_agg(jsonb_build_object('candidate_id',oc.id,'minutes',oc.candidate_minutes,
    'review_event_id',re.id,'decision',COALESCE(re.decision,'pending'),'classification_id',cl.id,'classification_version',cl.version,
    'ordinary_day_minutes',cl.ordinary_day_minutes,'ordinary_night_minutes',cl.ordinary_night_minutes,
    'weekly_rest_minutes',cl.weekly_rest_minutes,'official_holiday_minutes',cl.official_holiday_minutes) ORDER BY oc.id)
   FROM time.attendance_overtime_candidates oc
   LEFT JOIN time.attendance_overtime_review_events re ON re.tenant_id=oc.tenant_id AND re.candidate_id=oc.id
   LEFT JOIN LATERAL(SELECT c.* FROM time.attendance_overtime_classification_events c WHERE c.tenant_id=oc.tenant_id AND c.candidate_id=oc.id ORDER BY c.version DESC LIMIT 1)cl ON true
   WHERE oc.tenant_id=s.tenant_id AND oc.work_instance_id=s.id AND oc.attendance_fact_id=s.fact_id),'[]'))
  ORDER BY s.operational_date,s.employment_id,s.id),'[]') INTO items FROM scoped s;
 IF jsonb_array_length(items)>20000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
 RETURN items;
END $f$;
CREATE FUNCTION payroll.capture_leave_window(p_tenant uuid,p_employer uuid,p_from date,p_to date) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE items jsonb;BEGIN
 PERFORM payroll.optional_capture_authorized(p_tenant,p_employer);
 IF p_from IS NULL OR p_to IS NULL OR p_to<p_from OR p_to-p_from>30 THEN RAISE EXCEPTION 'payroll_optional_window_invalid' USING ERRCODE='22023';END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',clock_timestamp()) THEN RETURN '[]'::jsonb;END IF;
 WITH scoped AS MATERIALIZED(
  SELECT r.tenant_id,r.id,r.employee_id,r.employment_id,r.state,r.version,r.approved_preview_version,d.leave_date,d.year_period_id,d.calendar_version_id,d.type_version_id,d.day_count_basis,d.pay_effect,d.balance_mode,d.eligible,d.is_weekly_rest,d.is_half_day,d.units,d.half_day_part,d.halfday_mapping_state,d.halfday_policy_template_id,d.halfday_policy_version,d.halfday_algorithm_version,d.halfday_mapping_snapshot
  FROM leave.requests r JOIN leave.request_days d ON d.tenant_id=r.tenant_id AND d.request_id=r.id AND d.preview_version=r.approved_preview_version
  JOIN people.employments h ON h.tenant_id=r.tenant_id AND h.id=r.employment_id AND h.employee_id=r.employee_id AND h.employer_entity_id=r.employer_entity_id
  JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id
  WHERE r.tenant_id=p_tenant AND r.employer_entity_id=p_employer AND d.employer_entity_id=p_employer AND h.payroll_eligible
   AND d.leave_date BETWEEN p_from AND p_to AND d.leave_date>=h.start_date AND(h.end_date IS NULL OR d.leave_date<=h.end_date)
   AND r.state IN('approved','cancelled','superseded') AND r.approved_preview_version IS NOT NULL
  ORDER BY d.leave_date,r.employment_id,r.id LIMIT 20001
 ) SELECT COALESCE(jsonb_agg(jsonb_build_object('request_id',s.id,'date',s.leave_date,'employee_id',s.employee_id,'employment_id',s.employment_id,
  'state',s.state,'request_version',s.version,'approved_preview_version',s.approved_preview_version,'year_period_id',s.year_period_id,
  'calendar_version_id',s.calendar_version_id,'type_version_id',s.type_version_id,'day_count_basis',s.day_count_basis,
  'pay_effect',s.pay_effect,'balance_mode',s.balance_mode,'eligible',s.eligible,'is_weekly_rest',s.is_weekly_rest,'is_half_day',s.is_half_day,
  'half_day_part',s.half_day_part,'mapping_state',s.halfday_mapping_state,'mapping_policy_template_id',s.halfday_policy_template_id,'mapping_policy_version',s.halfday_policy_version,'mapping_algorithm_version',s.halfday_algorithm_version,
  'mapping_quantities',jsonb_build_object('required_minutes',payroll.capture_quantity(s.halfday_mapping_snapshot->'required_minutes'),'remaining_net_threshold_minutes',payroll.capture_quantity(s.halfday_mapping_snapshot->'remaining_net_threshold_minutes'),'halfday_break_minutes',payroll.capture_quantity(s.halfday_mapping_snapshot->'halfday_break_minutes'),'scheduled_net_minutes',payroll.capture_quantity(s.halfday_mapping_snapshot->'scheduled_net_minutes')),
  'original_units',s.units,'effective_units',CASE WHEN s.state IN('cancelled','superseded') THEN 0 ELSE s.units END,
  'cancellation',COALESCE((SELECT jsonb_build_object('event_id',c.id,'cancellation_id',c.cancellation_id,'event_key',c.event_key,
     'time_reconciliation_required',c.time_reconciliation_required) FROM leave.cancellation_events c
    WHERE c.tenant_id=s.tenant_id AND c.request_id=s.id AND((c.event_key='hr.accepted' AND c.to_state='accepted') OR(c.event_key='hr.direct_cancelled' AND c.to_state='cancelled')) ORDER BY c.id DESC LIMIT 1),'null'),
  'correction_links',COALESCE((SELECT jsonb_agg(jsonb_build_object('correction_id',c.id,'original_request_id',c.original_request_id,
    'replacement_request_id',c.replacement_request_id,'original_from_version',c.original_from_version,'original_to_version',c.original_to_version,
    'original_approved_preview_version',c.original_approved_preview_version,'replacement_from_version',c.replacement_from_version,
    'replacement_to_version',c.replacement_to_version,'replacement_preview_version',c.replacement_preview_version,
    'event_id',(SELECT ev.id FROM leave.correction_events ev WHERE ev.tenant_id=c.tenant_id AND ev.correction_id=c.id ORDER BY ev.id DESC LIMIT 1)) ORDER BY c.id)
    FROM leave.request_corrections c WHERE c.tenant_id=s.tenant_id AND(s.id=c.original_request_id OR s.id=c.replacement_request_id)),'[]'),
  'ledger_links',COALESCE((SELECT jsonb_agg(jsonb_build_object('consumption_id',c.ledger_entry_id,'units',c.units,
    'reversals',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',l.id,'kind',l.entry_kind,'units',l.delta_days) ORDER BY l.id)
      FROM leave.ledger_entries l WHERE l.tenant_id=c.tenant_id AND l.account_id=c.account_id AND l.reversal_of_entry_id=c.ledger_entry_id
       AND l.entry_kind IN('cancellation_reversal','correction_reversal')),'[]')) ORDER BY c.ledger_entry_id)
    FROM leave.request_consumptions c WHERE c.tenant_id=s.tenant_id AND c.request_id=s.id AND c.preview_version=s.approved_preview_version AND c.leave_date=s.leave_date),'[]'))
  ORDER BY s.leave_date,s.employment_id,s.id),'[]') INTO items FROM scoped s;
 IF jsonb_array_length(items)>20000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
 RETURN items;
END $f$;
CREATE FUNCTION payroll.capture_optional_sources(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE period payroll.periods%ROWTYPE;day date;until_day date;windows jsonb:='[]';time_items jsonb:='[]';leave_items jsonb:='[]';time_enabled boolean;leave_enabled boolean;BEGIN
 PERFORM payroll.optional_capture_authorized(p_tenant,p_employer);
 SELECT * INTO period FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF period.id IS NULL THEN RAISE EXCEPTION 'payroll_period_unavailable' USING ERRCODE='P0002';END IF;
 IF period.ends_on-period.starts_on>365 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
 time_enabled:=platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp());
 leave_enabled:=platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',clock_timestamp());
 day:=period.starts_on;
 WHILE day<=period.ends_on LOOP
  until_day:=least(day+30,period.ends_on);windows:=windows||jsonb_build_array(jsonb_build_object('from',day,'to',until_day));
  -- Disabled branches never invoke a source-domain query or its public permission gate.
  IF time_enabled THEN time_items:=time_items||payroll.capture_time_window(p_tenant,p_employer,day,until_day);END IF;
  IF leave_enabled THEN leave_items:=leave_items||payroll.capture_leave_window(p_tenant,p_employer,day,until_day);END IF;
  IF jsonb_array_length(time_items)+jsonb_array_length(leave_items)>200000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
  day:=until_day+1;
 END LOOP;
 RETURN jsonb_build_object('contract','cube4-optional-capture-v1','boundary','capture_only','consumed',false,'windows',windows,
  'time',jsonb_build_object('enabled',time_enabled,'items',time_items),'leave',jsonb_build_object('enabled',leave_enabled,'items',leave_items));
END $f$;
REVOKE ALL ON FUNCTION payroll.optional_capture_authorized(uuid,uuid),payroll.capture_quantity(jsonb),payroll.capture_time_window(uuid,uuid,date,date),payroll.capture_leave_window(uuid,uuid,date,date),payroll.capture_optional_sources(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;old text;manifest_signature text;stale_signature text;BEGIN
 -- Known Slice7 wrappers delegate to these renamed base functions. Patch the base,
 -- preserving their Finance fields, engine suffix and current authority/financial behavior.
 IF to_regprocedure('payroll.run_manifest_before_advances(uuid,uuid,uuid)') IS NOT NULL THEN
  IF to_regprocedure('payroll.stale_reasons_before_advances(jsonb,jsonb)') IS NULL THEN RAISE EXCEPTION 'unexpected_optional_capture_composition';END IF;
  manifest_signature:='payroll.run_manifest_before_advances(uuid,uuid,uuid)';stale_signature:='payroll.stale_reasons_before_advances(jsonb,jsonb)';
 ELSE
  IF to_regprocedure('payroll.stale_reasons_before_advances(jsonb,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'unexpected_optional_capture_composition';END IF;
  manifest_signature:='payroll.run_manifest(uuid,uuid,uuid)';stale_signature:='payroll.stale_reasons(jsonb,jsonb)';
 END IF;
 -- Slice6 filters correction links in a wrapper; capture belongs in its unchanged base.
 IF to_regprocedure('payroll.run_manifest_before_corrections(uuid,uuid,uuid)') IS NOT NULL THEN
  definition:=pg_get_functiondef(manifest_signature::regprocedure);
  IF position('payroll.run_manifest_before_corrections(p_tenant,p_employer,p_period)' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_optional_capture_correction_composition';END IF;
  manifest_signature:='payroll.run_manifest_before_corrections(uuid,uuid,uuid)';
 END IF;
 definition:=pg_get_functiondef(manifest_signature::regprocedure);
 IF position('cube4-review-v3-source-safe' IN definition)=0 OR position('''optional_sources''' IN definition)>0 THEN RAISE EXCEPTION 'unexpected_optional_capture_manifest';END IF;
 old:='''corrections'',COALESCE';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_optional_capture_manifest_anchor';END IF;
 EXECUTE replace(definition,old,'''optional_sources'',payroll.capture_optional_sources(p_tenant,p_employer,p_period),'||old);
 definition:=pg_get_functiondef(stale_signature::regprocedure);
 old:='''optional'',''corrections''';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_optional_capture_stale_anchor';END IF;
 EXECUTE replace(definition,old,'''optional'',''optional_sources'',''corrections''');
END $f$;
