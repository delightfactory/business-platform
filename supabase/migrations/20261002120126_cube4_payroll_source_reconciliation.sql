-- G4 reconciliation + owner-approved DAILY source definition. No source consumption, legal qualification or public finalization.
CREATE FUNCTION payroll.reconcile_employee_sources(p_manifest jsonb,p_employment jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE capture jsonb:=p_manifest->'optional_sources';hid uuid:=(p_employment->>'id')::uuid;time_on boolean:=COALESCE((p_manifest->'optional'->>'time')::boolean,false);leave_on boolean:=COALESCE((p_manifest->'optional'->>'leave')::boolean,false);
 first_day date:=(p_manifest->'period'->>'starts_on')::date;last_day date:=(p_manifest->'period'->>'ends_on')::date;day date;time_rows jsonb;leave_rows jsonb;day_time jsonb;day_leave jsonb;fact jsonb;item jsonb;binding jsonb;bindings jsonb;days jsonb:='[]';issues jsonb:='[]';day_issues jsonb;
 absence numeric;time_leave numeric;worked numeric;work_units numeric;paid numeric;unpaid numeric;leave_total numeric;binding_total numeric;quantity numeric;matches integer;valid_scope boolean;source_count integer:=0;
BEGIN
 IF NOT time_on AND NOT leave_on THEN RETURN jsonb_build_object('summary',jsonb_build_object('status','disabled','time_enabled',false,'leave_enabled',false,'day_count',0,'payroll_ready',false),'days','[]'::jsonb,'issues','[]'::jsonb);END IF;
 IF capture IS NULL OR capture->>'contract'<>'cube4-optional-capture-v1' OR capture->'time'->>'enabled' IS DISTINCT FROM time_on::text OR capture->'leave'->>'enabled' IS DISTINCT FROM leave_on::text THEN
  RETURN jsonb_build_object('summary',jsonb_build_object('status','needs_source_review','payroll_ready',false),'days','[]'::jsonb,'issues',jsonb_build_array(payroll.issue('source_capture_missing',hid,'payroll_sources')));END IF;
 valid_scope:=p_employment->>'tenant_id'=p_manifest->'period'->>'tenant_id' AND p_employment->>'employer_entity_id'=p_manifest->'period'->>'employer_id' AND(p_employment->>'payroll_eligible')::boolean;
 IF valid_scope IS DISTINCT FROM true THEN RETURN jsonb_build_object('summary',jsonb_build_object('status','needs_source_review','payroll_ready',false),'days','[]'::jsonb,'issues',jsonb_build_array(payroll.issue('source_scope_invalid',hid,'payroll_sources')));END IF;
 first_day:=greatest(first_day,(p_employment->>'start_date')::date);last_day:=least(last_day,COALESCE((p_employment->>'end_date')::date,last_day));
 SELECT COALESCE(jsonb_agg(x ORDER BY x->>'date',x->>'work_instance_id'),'[]') INTO time_rows FROM jsonb_array_elements(CASE WHEN time_on THEN capture->'time'->'items' ELSE '[]' END)x WHERE x->>'employment_id'=hid::text;
 SELECT COALESCE(jsonb_agg(x ORDER BY x->>'date',x->>'request_id'),'[]') INTO leave_rows FROM jsonb_array_elements(CASE WHEN leave_on THEN capture->'leave'->'items' ELSE '[]' END)x WHERE x->>'employment_id'=hid::text;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(time_rows||leave_rows)x WHERE x->>'employee_id' IS DISTINCT FROM p_employment->>'employee_id' OR(x->>'date')::date NOT BETWEEN first_day AND last_day) THEN
  RETURN jsonb_build_object('summary',jsonb_build_object('status','needs_source_review','payroll_ready',false),'days','[]'::jsonb,'issues',jsonb_build_array(payroll.issue('source_scope_invalid',hid,'payroll_sources')));END IF;
 FOR day IN SELECT DISTINCT(x->>'date')::date FROM jsonb_array_elements(time_rows||leave_rows)x ORDER BY 1 LOOP
  day_issues:='[]';absence:=NULL;time_leave:=NULL;worked:=NULL;work_units:=NULL;paid:=0;unpaid:=0;leave_total:=0;binding_total:=0;
  SELECT COALESCE(jsonb_agg(x),'[]') INTO day_time FROM jsonb_array_elements(time_rows)x WHERE(x->>'date')::date=day;
  SELECT COALESCE(jsonb_agg(x),'[]') INTO day_leave FROM jsonb_array_elements(leave_rows)x WHERE(x->>'date')::date=day;
  IF jsonb_array_length(day_time)>1 THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_duplicate_time',hid,'payroll_time'));END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(day_leave)x GROUP BY x->>'request_id',x->>'approved_preview_version' HAVING count(*)>1) THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_duplicate_leave',hid,'payroll_leave'));END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(day_leave) LOOP
   quantity:=payroll.capture_quantity(item->'effective_units');
   IF quantity IS NULL OR quantity NOT IN(0,0.5,1) OR COALESCE(item->>'state','') NOT IN('approved','cancelled','superseded') OR COALESCE(item->>'pay_effect','') NOT IN('paid','unpaid') OR((item->>'state' IN('cancelled','superseded') OR(item->>'eligible')::boolean IS DISTINCT FROM true) AND quantity<>0) THEN
    day_issues:=day_issues||jsonb_build_array(payroll.issue('source_quantity_unknown',hid,'payroll_leave'));CONTINUE;END IF;
   IF item->>'state'='approved' AND(item->>'eligible')::boolean THEN
    leave_total:=leave_total+quantity;IF item->>'pay_effect'='paid' THEN paid:=paid+quantity;ELSE unpaid:=unpaid+quantity;END IF;
   END IF;
  END LOOP;
  IF leave_total>1 THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_leave_overlap',hid,'payroll_leave'));END IF;
  fact:=CASE WHEN jsonb_array_length(day_time)=1 THEN day_time->0 END;
  IF fact IS NOT NULL THEN
   absence:=payroll.capture_quantity(fact->'absence_units');time_leave:=payroll.capture_quantity(fact->'leave_units');worked:=payroll.capture_quantity(fact->'worked_minutes');
   IF COALESCE((fact->>'classification_reconciliation_required')::boolean,true) THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_classification_stale',hid,'payroll_time'));END IF;
   IF time_leave IS NULL OR time_leave NOT IN(0,0.5,1) OR COALESCE(fact->>'outcome','') NOT IN('worked','absence','leave_covered') THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_quantity_unknown',hid,'payroll_time'));
   ELSIF fact->>'outcome'='worked' THEN
    IF worked IS NULL OR time_leave NOT IN(0,0.5) OR absence IS DISTINCT FROM 0 THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_quantity_unknown',hid,'payroll_time'));ELSE work_units:=1-time_leave;END IF;
   ELSE
    -- Classified absence_units are already EXCLUSIVE of Leave: never subtract Leave twice.
    IF absence IS NULL OR absence NOT IN(0,0.5,1) OR absence+time_leave<>1 OR(fact->>'outcome'='leave_covered' AND(absence<>0 OR time_leave<>1)) THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_quantity_unknown',hid,'payroll_time'));ELSE work_units:=0;END IF;
   END IF;
   IF NOT leave_on AND time_leave>0 THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_leave_treatment_unknown',hid,'payroll_units'));END IF;
   bindings:=COALESCE(fact->'leave_bindings','[]');
   FOR binding IN SELECT value FROM jsonb_array_elements(bindings) LOOP
    quantity:=payroll.capture_quantity(binding->'units');
    IF quantity IS NULL OR quantity NOT IN(0,0.5,1) OR binding->>'date' IS DISTINCT FROM day::text OR binding->>'request_id' IS NULL OR binding->>'approved_preview_version' IS NULL THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_leave_binding_mismatch',hid,'payroll_time'));CONTINUE;END IF;
    binding_total:=binding_total+quantity;
    IF leave_on AND quantity>0 THEN
     SELECT count(*) INTO matches FROM jsonb_array_elements(day_leave)x WHERE x->>'request_id'=binding->>'request_id' AND x->>'approved_preview_version'=binding->>'approved_preview_version' AND x->>'state'='approved' AND(x->>'eligible')::boolean AND(x->>'effective_units')::numeric=quantity;
     IF matches<>1 THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_leave_binding_mismatch',hid,'payroll_time'));
     ELSIF EXISTS(SELECT 1 FROM jsonb_array_elements(day_leave)x WHERE x->>'request_id'=binding->>'request_id' AND(x->>'is_half_day')::boolean AND(x->>'mapping_state' IS DISTINCT FROM 'mapped' OR binding->>'mapping_state' IS DISTINCT FROM x->>'mapping_state' OR binding->>'policy_template_id' IS DISTINCT FROM x->>'mapping_policy_template_id' OR binding->>'policy_version' IS DISTINCT FROM x->>'mapping_policy_version' OR binding->>'algorithm_version' IS DISTINCT FROM x->>'mapping_algorithm_version')) THEN
      day_issues:=day_issues||jsonb_build_array(payroll.issue('source_mapping_uncertain',hid,'payroll_leave'));END IF;
    END IF;
   END LOOP;
   IF binding_total IS DISTINCT FROM time_leave OR(leave_on AND binding_total IS DISTINCT FROM leave_total) OR EXISTS(SELECT 1 FROM jsonb_array_elements(bindings)x GROUP BY x->>'request_id',x->>'approved_preview_version',x->>'date' HAVING count(*)>1) THEN day_issues:=day_issues||jsonb_build_array(payroll.issue('source_leave_binding_mismatch',hid,'payroll_time'));END IF;
  END IF;
  SELECT COALESCE(jsonb_agg(DISTINCT x ORDER BY x),'[]') INTO day_issues FROM jsonb_array_elements(day_issues)x;
  issues:=issues||day_issues;source_count:=source_count+jsonb_array_length(day_time)+jsonb_array_length(day_leave);
  days:=days||jsonb_build_array(jsonb_build_object('date',day,'time_fact_count',jsonb_array_length(day_time),'leave_source_count',jsonb_array_length(day_leave),'outcome',fact->>'outcome','worked_minutes',worked,'absence_units',absence,'time_leave_units',time_leave,'work_units',work_units,'paid_leave_units',paid,'unpaid_leave_units',unpaid,'status',CASE WHEN jsonb_array_length(day_issues)=0 THEN 'reconciliation_ready' ELSE 'needs_source_review' END));
 END LOOP;
 SELECT COALESCE(jsonb_agg(DISTINCT x ORDER BY x),'[]') INTO issues FROM jsonb_array_elements(issues)x;
 RETURN jsonb_build_object('summary',jsonb_build_object('status',CASE WHEN issues='[]'::jsonb THEN 'reconciliation_ready' ELSE 'needs_source_review' END,'time_enabled',time_on,'leave_enabled',leave_on,'day_count',jsonb_array_length(days),'source_count',source_count,'worked_minutes',(SELECT sum((x->>'worked_minutes')::numeric) FROM jsonb_array_elements(days)x),'absence_units',(SELECT sum((x->>'absence_units')::numeric) FROM jsonb_array_elements(days)x),'time_leave_units',(SELECT sum((x->>'time_leave_units')::numeric) FROM jsonb_array_elements(days)x),'paid_leave_units',(SELECT sum((x->>'paid_leave_units')::numeric) FROM jsonb_array_elements(days)x),'unpaid_leave_units',(SELECT sum((x->>'unpaid_leave_units')::numeric) FROM jsonb_array_elements(days)x),'issue_count',jsonb_array_length(issues),'payroll_ready',false),'days',days,'issues',issues);
END $f$;
CREATE FUNCTION payroll.daily_source_parts(p_manifest jsonb,p_employment jsonb,p_reconciled jsonb,p_rates jsonb,p_min_rate numeric,p_max_rate numeric) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE hid uuid:=(p_employment->>'id')::uuid;choice jsonb;choices integer;selected text;issues jsonb:='[]';parts jsonb:='[]';units numeric;day jsonb;rate_part jsonb;quantity numeric;first_day date:=greatest((p_manifest->'period'->>'starts_on')::date,(p_employment->>'start_date')::date);last_day date:=least((p_manifest->'period'->>'ends_on')::date,COALESCE((p_employment->>'end_date')::date,(p_manifest->'period'->>'ends_on')::date));eligible_days integer:=last_day-first_day+1;time_on boolean:=COALESCE((p_manifest->'optional'->>'time')::boolean,false);has_time boolean:=EXISTS(SELECT 1 FROM jsonb_array_elements(COALESCE(p_reconciled->'days','[]'))x WHERE(x->>'time_fact_count')::int>0);
BEGIN
 SELECT count(*),jsonb_agg(i)->0 INTO choices,choice FROM(SELECT DISTINCT ON(i->'head'->>'id')i FROM jsonb_array_elements(p_manifest->'inputs')i WHERE i->'head'->>'kind'='manual_units' AND i->'head'->>'employment_id'=hid::text AND i->'head'->>'period_id'=p_manifest->'period'->>'id' ORDER BY i->'head'->>'id',(i->'version'->>'revision')::int DESC)current_heads WHERE i->'version'->>'status'<>'cancelled' AND(i->'version'->>'effective_from')::date<=last_day AND(i->'version'->>'effective_until' IS NULL OR(i->'version'->>'effective_until')::date>first_day);
 IF choices>1 THEN issues:=jsonb_build_array(payroll.issue('manual_units_ambiguous',hid,'payroll_units'));
 ELSIF choice IS NOT NULL AND choice->'version'->>'status'<>'approved' THEN issues:=jsonb_build_array(payroll.issue('source_choice_pending',hid,'payroll_units'));
 ELSIF choice IS NOT NULL THEN
  selected:=choice->'version'->'data'->>'source';
  IF selected IS NULL AND has_time THEN issues:=jsonb_build_array(payroll.issue('source_choice_required',hid,'payroll_units'));
  ELSIF selected IS NULL THEN selected:='legacy_manual';
  ELSIF selected NOT IN('manual','time') THEN issues:=jsonb_build_array(payroll.issue('source_choice_required',hid,'payroll_units'));
  ELSIF selected='manual' AND choice->'version'->'data'->>'basis' IS DISTINCT FROM 'approved_payable_total' THEN issues:=jsonb_build_array(payroll.issue('source_choice_required',hid,'payroll_units'));
  END IF;
 ELSIF time_on AND has_time THEN selected:='time';
 ELSE issues:=jsonb_build_array(payroll.issue('approved_units_missing',hid,'payroll_units'));END IF;
 IF selected='time' THEN
  IF NOT time_on THEN issues:=issues||jsonb_build_array(payroll.issue('source_time_disabled',hid,'payroll_units'));
  ELSIF p_reconciled->'issues'<>'[]'::jsonb THEN issues:=issues||p_reconciled->'issues';
  ELSE
   units:=0;
   FOR rate_part IN SELECT rp FROM jsonb_array_elements(p_rates)rp WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(p_reconciled->'days')d WHERE d->>'date'=rp->>'date' AND(d->>'time_fact_count')::int=1 AND d->>'work_units' IS NOT NULL) LOOP
    SELECT x INTO day FROM jsonb_array_elements(p_reconciled->'days')x WHERE x->>'date'=rate_part->>'date';
    quantity:=(day->>'work_units')::numeric+(day->>'paid_leave_units')::numeric;
    IF quantity IS NULL OR quantity NOT IN(0,0.5,1) THEN issues:=issues||jsonb_build_array(payroll.issue('source_quantity_unknown',hid,'payroll_time'));EXIT;END IF;
    units:=units+quantity;
    parts:=parts||jsonb_build_array(rate_part||jsonb_build_object('units',quantity::text,'unit_source','time','denominator',1,'raw',((rate_part->>'rate')::numeric*quantity)::text,'_numerator',((rate_part->>'rate')::numeric*100*quantity*100)::text,'_denominator','10000'));
   END LOOP;
  END IF;
 ELSIF selected IN('manual','legacy_manual') THEN
  units:=(choice->'version'->'data'->>'units')::numeric;
  IF units IS NULL OR units<=0 OR units>eligible_days THEN issues:=issues||jsonb_build_array(payroll.issue('units_exceed_eligibility',hid,'payroll_units'));
  ELSIF p_min_rate IS DISTINCT FROM p_max_rate THEN issues:=issues||jsonb_build_array(payroll.issue('daily_units_allocation_needed',hid,'payroll_units'));
  ELSE SELECT COALESCE(jsonb_agg(b||jsonb_build_object('raw',(p_min_rate*units/eligible_days)::text,'_numerator',(p_min_rate*100*units*100)::text,'_denominator',(eligible_days*10000)::text) ORDER BY b->>'date'),'[]') INTO parts FROM jsonb_array_elements(p_rates)b;END IF;
 END IF;
 IF issues<>'[]'::jsonb THEN parts:='[]';units:=NULL;END IF;
 RETURN jsonb_build_object('source',selected,'units',units,'parts',parts,'issues',issues,'choice_version',choice->'version'->>'id');
END $f$;
REVOKE ALL ON FUNCTION payroll.reconcile_employee_sources(jsonb,jsonb),payroll.daily_source_parts(jsonb,jsonb,jsonb,jsonb,numeric,numeric) FROM PUBLIC,anon,authenticated,service_role;
-- Only two reviewed candidate insertion forms are supported; dynamic identity belongs to the known Slice7 wrapper.
CREATE FUNCTION payroll.daily_source_command_definition(p_definition text,p_before_advances boolean) RETURNS text
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $identity$
DECLARE legacy text:='''cube4-review-v3-source-safe'',manifest,output,a';dynamic text:='manifest->>''engine'',manifest,output,a';legacy_count integer;dynamic_count integer;
BEGIN
 IF p_definition IS NULL OR p_before_advances IS NULL THEN RAISE EXCEPTION 'unexpected_daily_source_candidate_identity';END IF;
 legacy_count:=(length(p_definition)-length(replace(p_definition,legacy,'')))/length(legacy);
 dynamic_count:=(length(p_definition)-length(replace(p_definition,dynamic,'')))/length(dynamic);
 IF legacy_count=1 AND dynamic_count=0 THEN
  RETURN replace(p_definition,legacy,'''cube4-review-v4-daily-sources'',manifest,output,a');
 ELSIF legacy_count=0 AND dynamic_count=1 AND p_before_advances THEN RETURN p_definition;
 END IF;
 RAISE EXCEPTION 'unexpected_daily_source_candidate_identity';
END $identity$;
REVOKE ALL ON FUNCTION payroll.daily_source_command_definition(text,boolean) FROM PUBLIC,anon,authenticated,service_role;
DO $patch$
DECLARE definition text;old text;new text;signature text;builder text;manifest text;start_at integer;end_at integer;
BEGIN
 signature:='payroll.validate_input(text,jsonb)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='WHEN ''manual_units'' THEN ARRAY[''units'',''reference'',''reason'']';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_validator';END IF;
 definition:=replace(definition,old,'WHEN ''manual_units'' THEN ARRAY[''units'',''reference'',''reason'',''source'',''basis'']');
 old:='(p_kind IN(''manual_units'',''adjustment'') AND val=0)';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_zero_validator';END IF;
 definition:=replace(definition,old,'(val=0 AND(p_kind=''adjustment'' OR p_kind=''manual_units'' AND p_data->>''source'' IS DISTINCT FROM ''time''))');
 old:='IF p_kind=''opening_ytd'' THEN';
 new:=$body$IF p_kind='manual_units' AND(
  p_data ? 'source' AND COALESCE(p_data->>'source','') NOT IN('manual','time')
  OR p_data->>'source'='time' AND(val<>0 OR p_data ? 'basis')
  OR p_data->>'source'='manual' AND(p_data->>'basis' IS DISTINCT FROM 'approved_payable_total' OR val<=0)
  OR NOT(p_data ? 'source') AND p_data ? 'basis') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 IF p_kind='opening_ytd' THEN$body$;
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_basis_validator';END IF;EXECUTE replace(definition,old,new);
 -- Authority and serialized receipt recovery precede the new-write capability gate. Cancellation remains available.
 signature:='public.payroll_save_input(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='PERFORM payroll.validate_input(p_kind,p_data);';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_save';END IF;
 new:=old||$body$ IF p_kind='manual_units' AND p_operation IN('save','approve') AND p_data->>'source'='time' AND NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()) THEN RAISE EXCEPTION 'payroll_time_source_disabled' USING ERRCODE='55000';END IF;$body$;
 EXECUTE replace(definition,old,new);
 signature:='public.payroll_input_access(uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='RETURN result||jsonb_build_object(''enabled'',';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_access';END IF;
 EXECUTE replace(definition,old,'RETURN result||jsonb_build_object(''time_enabled'',platform_private.tenant_capability_is_enabled(p_tenant,''hr.attendance'',clock_timestamp()),''enabled'',');
 IF to_regprocedure('payroll.build_review_before_advances(jsonb)') IS NOT NULL THEN
  builder:='payroll.build_review_before_advances(jsonb)';manifest:='payroll.run_manifest_before_advances(uuid,uuid,uuid)';
 ELSE builder:='payroll.build_review(jsonb)';manifest:='payroll.run_manifest(uuid,uuid,uuid)';END IF;
 -- Preserve Slice6's correction-filter wrapper and Slice7's advance wrapper.
 IF to_regprocedure('payroll.run_manifest_before_corrections(uuid,uuid,uuid)') IS NOT NULL THEN
  definition:=pg_get_functiondef(manifest::regprocedure);
  IF position('payroll.run_manifest_before_corrections(p_tenant,p_employer,p_period)' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_correction_composition';END IF;
  manifest:='payroll.run_manifest_before_corrections(uuid,uuid,uuid)';
 END IF;
 definition:=pg_get_functiondef(builder::regprocedure);
 IF position('cube4-review-v3-source-safe' IN definition)=0 OR position('payroll.parts_fraction' IN definition)=0 OR position('source_summary' IN definition)>0 THEN RAISE EXCEPTION 'unexpected_daily_source_engine';END IF;
 old:='heads record; approved_input jsonb;';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_declaration';END IF;definition:=replace(definition,old,'source_context jsonb;daily_context jsonb;heads record; approved_input jsonb;');
 old:='employee_issues:=''[]'';';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_initialization';END IF;
 definition:=replace(definition,old,'source_context:=payroll.reconcile_employee_sources(p_manifest,h);daily_context:=NULL;'||old);
 -- Replace only the daily base branch; exact dated parts then feed the existing percentage/rational engine.
 start_at:=position('IF basis=''daily'' THEN' IN definition);
 end_at:=position('SELECT COALESCE(sum((b->>''raw'')::numeric),0) INTO base_raw' IN definition);
 IF start_at=0 OR end_at<=start_at THEN RAISE EXCEPTION 'unexpected_daily_source_branch';END IF;
 new:=$body$IF basis='daily' THEN
   daily_context:=payroll.daily_source_parts(employee_manifest,h,source_context,base_parts,minimum_rate,maximum_rate);
   units:=(daily_context->>'units')::numeric;base_parts:=daily_context->'parts';
   employee_issues:=employee_issues||(daily_context->'issues');
   IF daily_context->'issues'<>'[]'::jsonb THEN complete:=false;END IF;
   source_context:=jsonb_set(source_context,'{summary}',source_context->'summary'||jsonb_build_object('selected_source',daily_context->>'source','approved_units',units,'status',CASE WHEN daily_context->'issues'<>'[]'::jsonb OR source_context->'issues'<>'[]'::jsonb OR daily_context->>'source'='time' THEN 'needs_source_review' ELSE source_context->'summary'->>'status' END,'coverage',CASE WHEN daily_context->>'source'='time' THEN 'captured_parts_only' ELSE 'approved_manual_total' END));
   IF daily_context->>'source'='time' THEN
    -- No authoritative expected-workday calendar exists in this stage. Missing civil dates are not assumed unpaid or worked.
    complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('source_time_coverage_unqualified',hid,'payroll_time'));
   END IF;
  END IF;
  IF source_context->'issues'<>'[]'::jsonb THEN complete:=false;employee_issues:=employee_issues||(source_context->'issues');END IF;
  IF mode IS NULL OR basis='daily' AND(coverage_gap OR units IS NULL) THEN base_parts:='[]';END IF;
  $body$;
 definition:=substr(definition,1,start_at-1)||new||substr(definition,end_at);
 old:='IF basis=''daily'' AND(units IS NULL OR minimum_rate IS DISTINCT FROM maximum_rate) THEN CONTINUE; END IF;';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_percentage';END IF;
 definition:=replace(definition,old,'IF basis=''daily'' AND(units IS NULL OR daily_context->>''source'' IS DISTINCT FROM ''time'' AND minimum_rate IS DISTINCT FROM maximum_rate) THEN CONTINUE; END IF;');
 old:='IF basis=''daily'' THEN';start_at:=position(old IN substr(definition,position('-- Recurring heads' IN definition)));
 IF start_at=0 THEN RAISE EXCEPTION 'unexpected_daily_source_component_coverage';END IF;
 -- The remaining daily IF is the aggregate manual percentage allocation guard. Time parts already carry dated units/rates.
 start_at:=start_at+position('-- Recurring heads' IN definition)-1;
 definition:=substr(definition,1,start_at-1)||replace(substr(definition,start_at),old,'IF basis=''daily'' AND daily_context->>''source'' IS DISTINCT FROM ''time'' THEN');
 old:='''issues'',employee_issues));';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_explanation';END IF;
 definition:=replace(definition,old,'''source_summary'',source_context->''summary'',''source_days'',source_context->''days'',''issues'',employee_issues));');
 EXECUTE replace(definition,'cube4-review-v3-source-safe','cube4-review-v4-daily-sources');
 definition:=pg_get_functiondef(manifest::regprocedure);
 IF position('cube4-review-v3-source-safe' IN definition)=0 OR position('''optional_sources''' IN definition)=0 THEN RAISE EXCEPTION 'daily_source_requires_capture';END IF;
 EXECUTE replace(definition,'cube4-review-v3-source-safe','cube4-review-v4-daily-sources');
 signature:='public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)';definition:=pg_get_functiondef(signature::regprocedure);
 EXECUTE payroll.daily_source_command_definition(definition,to_regprocedure('payroll.run_manifest_before_advances(uuid,uuid,uuid)') IS NOT NULL);
 -- Candidate list stays bounded; detail carries only human-safe dates/quantities. Final access guards are untouched.
 signature:='public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)';definition:=pg_get_functiondef(signature::regprocedure);old:='e-''lines''-''unresolved_parts''-''dated_rates''';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_workspace';END IF;EXECUTE replace(definition,old,old||'-''source_days''');
 signature:='payroll.review_employee_detail(jsonb)';definition:=pg_get_functiondef(signature::regprocedure);
 old:='WHEN l->>''component''=''base'' AND p_employee->>''pay_basis''=''daily'' THEN';
 IF position(old IN definition)=0 OR position('p_employee-''unresolved_parts''-''lines''' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_daily_source_detail';END IF;
 EXECUTE replace(definition,old,'WHEN l->>''component''=''base'' AND p_employee->>''pay_basis''=''daily'' AND p_employee->''source_summary''->>''selected_source'' IS DISTINCT FROM ''time'' THEN');
END $patch$;
