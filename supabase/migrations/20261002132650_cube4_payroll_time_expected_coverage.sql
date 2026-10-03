-- Observational expected-Time coverage only. No money, approval, source write or consumption.
CREATE FUNCTION payroll.time_expected_bounds(p_date date,p_policy jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE starts timestamptz;ends timestamptz;before_n integer;after_n integer;expected boolean;
BEGIN
 IF p_date IS NULL OR NOT isfinite(p_date) OR p_date NOT BETWEEN DATE '0001-01-01' AND DATE '9999-12-31'
  OR p_policy IS NULL OR COALESCE(p_policy->>'schedule_kind','') NOT IN('fixed','flexible') OR p_policy->>'timezone_name' IS NULL OR jsonb_typeof(p_policy->'work_days') IS DISTINCT FROM 'array' THEN
  RETURN jsonb_build_object('state','schedule_context_missing','expected',NULL);END IF;
 expected:=EXISTS(SELECT 1 FROM jsonb_array_elements_text(p_policy->'work_days')d WHERE d::integer=extract(dow FROM p_date)::integer+1);
 IF NOT expected THEN RETURN jsonb_build_object('state','scheduled_nonworkday','expected',false);END IF;
 IF p_policy->>'schedule_kind'='fixed' THEN
  IF p_policy->>'shift_start' IS NULL OR p_policy->>'shift_end' IS NULL THEN RETURN jsonb_build_object('state','schedule_context_missing','expected',true);END IF;
  starts:=time.resolve_local(p_date+(p_policy->>'shift_start')::time,p_policy->>'timezone_name');
  ends:=time.resolve_local((p_date+CASE WHEN(p_policy->>'ends_next_day')::boolean THEN 1 ELSE 0 END)+(p_policy->>'shift_end')::time,p_policy->>'timezone_name');
  before_n:=(p_policy->>'attribution_before_minutes')::integer;after_n:=(p_policy->>'attribution_after_minutes')::integer;
 ELSE
  IF(p_policy->>'required_minutes')::integer IS NULL THEN RETURN jsonb_build_object('state','schedule_context_missing','expected',true);END IF;
  starts:=time.resolve_local(p_date+COALESCE((p_policy->>'earliest_punch')::time,'00:00:00'::time),p_policy->>'timezone_name');
  ends:=time.resolve_local(p_date+COALESCE((p_policy->>'latest_punch')::time,'23:59:59'::time),p_policy->>'timezone_name');before_n:=0;after_n:=0;
 END IF;
 IF starts IS NULL OR ends IS NULL OR before_n IS NULL OR after_n IS NULL OR ends<=starts THEN RETURN jsonb_build_object('state','schedule_window_ambiguous','expected',true);END IF;
 RETURN jsonb_build_object('state','expected_workday','expected',true,'expected_start_epoch',CASE WHEN p_policy->>'schedule_kind'='fixed' THEN extract(epoch FROM starts) END,
  'expected_end_epoch',CASE WHEN p_policy->>'schedule_kind'='fixed' THEN extract(epoch FROM ends) END,'attribution_start_epoch',extract(epoch FROM starts-make_interval(mins=>before_n)),
  'attribution_end_epoch',extract(epoch FROM ends+make_interval(mins=>after_n)));
END $f$;
CREATE FUNCTION payroll.capture_time_coverage_window(p_tenant uuid,p_employer uuid,p_from date,p_to date) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE employment_row record;d date;assignments jsonb;overrides jsonb;instances jsonb;a jsonb;o jsonb;i jsonb;policy jsonb;bounds jsonb;fact jsonb;latest jsonb;state text;expected boolean;elapsed boolean;reconciliation boolean;items jsonb:='[]';size bigint;now_epoch numeric:=extract(epoch FROM statement_timestamp());provenance jsonb;bounds_cache jsonb:='{}';cache_key text;
BEGIN
 PERFORM payroll.optional_capture_authorized(p_tenant,p_employer);
 IF p_from IS NULL OR p_to IS NULL OR NOT isfinite(p_from) OR NOT isfinite(p_to) OR p_from NOT BETWEEN DATE '0001-01-01' AND DATE '9999-12-31' OR p_to NOT BETWEEN DATE '0001-01-01' AND DATE '9999-12-31' OR p_to<p_from OR p_to-p_from>30 THEN RAISE EXCEPTION 'payroll_optional_window_invalid' USING ERRCODE='22023';END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()) THEN RETURN jsonb_build_object('enabled',false,'items','[]'::jsonb);END IF;
 -- Count the clipped grid before materializing dates. Even the head scan is bounded to the overflow sentinel.
 SELECT COALESCE(sum(least(COALESCE(end_date,p_to),p_to)-greatest(start_date,p_from)+1),0) INTO size FROM(
  SELECT h.start_date,h.end_date FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id
  WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND h.start_date<=p_to AND(h.end_date IS NULL OR h.end_date>=p_from) ORDER BY h.id LIMIT 20001)x;
 IF size>20000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
 FOR employment_row IN SELECT h.id,h.employee_id,h.start_date,h.end_date FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id
  WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND h.start_date<=p_to AND(h.end_date IS NULL OR h.end_date>=p_from) ORDER BY h.id LOOP
  FOR d IN SELECT greatest(employment_row.start_date,p_from)+n FROM generate_series(0,least(COALESCE(employment_row.end_date,p_to),p_to)-greatest(employment_row.start_date,p_from))n LOOP
   policy:=NULL;bounds:=NULL;fact:=NULL;latest:=NULL;expected:=NULL;elapsed:=NULL;reconciliation:=NULL;
   SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]') INTO assignments FROM(
    SELECT a.id,a.site_id,a.valid_from,a.valid_until,a.work_policy_template_id,a.work_policy_version,s.legal_entity_id
    FROM people.work_assignments a JOIN platform_core.tenant_sites s ON s.tenant_id=a.tenant_id AND s.id=a.site_id
    WHERE a.tenant_id=p_tenant AND a.employment_id=employment_row.id AND a.valid_from<=d AND(a.valid_until IS NULL OR a.valid_until>d) ORDER BY a.id LIMIT 2)x;
   SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]') INTO overrides FROM(
    SELECT id,policy_template_id,policy_version,valid_from,valid_until FROM time.work_policy_overrides
    WHERE tenant_id=p_tenant AND employment_id=employment_row.id AND cancelled_at IS NULL AND valid_from<=d AND valid_until>d ORDER BY id LIMIT 2)x;
   SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]') INTO instances FROM(
    SELECT id,assignment_id,employee_id,site_id,policy_template_id,policy_version,timezone_name,status,
     extract(epoch FROM expected_start) AS expected_start_epoch,extract(epoch FROM expected_end) AS expected_end_epoch,
     extract(epoch FROM attribution_start) AS attribution_start_epoch,extract(epoch FROM attribution_end) AS attribution_end_epoch
    FROM time.work_instances WHERE tenant_id=p_tenant AND employment_id=employment_row.id AND operational_date=d ORDER BY id LIMIT 2)x;
   a:=assignments->0;o:=overrides->0;i:=instances->0;
   IF jsonb_array_length(assignments)<>1 OR jsonb_array_length(overrides)>1 THEN state:='schedule_context_missing_or_ambiguous';
   ELSIF a->>'legal_entity_id' IS DISTINCT FROM p_employer::text THEN state:='schedule_context_mismatch';
   ELSE
    SELECT jsonb_build_object('template_id',v.template_id,'version',v.version,'schedule_kind',v.schedule_kind,'timezone_name',v.timezone_name,'work_days',v.work_days,
     'shift_start',v.shift_start,'shift_end',v.shift_end,'ends_next_day',v.ends_next_day,'required_minutes',v.required_minutes,'earliest_punch',v.earliest_punch,'latest_punch',v.latest_punch,
     'attribution_before_minutes',v.attribution_before_minutes,'attribution_after_minutes',v.attribution_after_minutes) INTO policy
    FROM time.work_policy_versions v WHERE v.tenant_id=p_tenant AND v.template_id=COALESCE((o->>'policy_template_id')::uuid,(a->>'work_policy_template_id')::uuid)
     AND v.version=COALESCE((o->>'policy_version')::integer,(a->>'work_policy_version')::integer);
    cache_key:=d::text||':'||(policy->>'template_id')||':'||(policy->>'version');
    IF cache_key IS NOT NULL AND bounds_cache ? cache_key THEN bounds:=bounds_cache->cache_key;
    ELSE bounds:=payroll.time_expected_bounds(d,policy);IF cache_key IS NOT NULL THEN bounds_cache:=jsonb_set(bounds_cache,ARRAY[cache_key],bounds,true);END IF;END IF;
    state:=bounds->>'state';expected:=(bounds->>'expected')::boolean;
    IF expected AND state='expected_workday' THEN elapsed:=now_epoch>=(bounds->>'attribution_end_epoch')::numeric;END IF;
   END IF;
   IF jsonb_array_length(instances)>1 THEN state:='instance_ambiguous';
   ELSIF i IS NOT NULL THEN
    SELECT jsonb_build_object('id',f.id,'version',f.version,'interpretation_id',f.interpretation_id,'corrects_fact_id',f.corrects_fact_id,'outcome',f.fact->>'outcome','classification_evidence_id',ce.id,'classified_kind',ce.plan->'classification'->>'kind','classified_approval_eligible',ce.plan->'classification'->'approval_eligible') INTO fact
     FROM time.attendance_facts f LEFT JOIN time.classification_evidence ce ON ce.tenant_id=f.tenant_id AND ce.interpretation_id=f.interpretation_id AND ce.work_instance_id=f.work_instance_id WHERE f.tenant_id=p_tenant AND f.work_instance_id=(i->>'id')::uuid ORDER BY f.version DESC LIMIT 1;
    SELECT jsonb_build_object('id',q.id,'version',q.version,'state',q.state) INTO latest
     FROM time.interpretations q WHERE q.tenant_id=p_tenant AND q.work_instance_id=(i->>'id')::uuid ORDER BY q.version DESC LIMIT 1;
    IF state='scheduled_nonworkday' THEN state:='off_schedule_materialized';
    ELSIF state='expected_workday' THEN
     IF i->>'employee_id' IS DISTINCT FROM employment_row.employee_id::text OR i->>'assignment_id' IS DISTINCT FROM a->>'id' OR i->>'site_id' IS DISTINCT FROM a->>'site_id'
      OR i->>'policy_template_id' IS DISTINCT FROM policy->>'template_id' OR i->>'policy_version' IS DISTINCT FROM policy->>'version' OR i->>'timezone_name' IS DISTINCT FROM policy->>'timezone_name'
      OR i->'expected_start_epoch' IS DISTINCT FROM bounds->'expected_start_epoch' OR i->'expected_end_epoch' IS DISTINCT FROM bounds->'expected_end_epoch'
      OR i->'attribution_start_epoch' IS DISTINCT FROM bounds->'attribution_start_epoch' OR i->'attribution_end_epoch' IS DISTINCT FROM bounds->'attribution_end_epoch' THEN state:='policy_context_mismatch';
     ELSIF elapsed IS DISTINCT FROM true THEN state:='not_yet_elapsed';
     ELSIF i->>'status'<>'approved' THEN state:='instance_open_or_pending';
     ELSIF fact IS NULL OR COALESCE(fact->>'outcome','') NOT IN('worked','absence','leave_covered') OR fact->>'interpretation_id' IS DISTINCT FROM latest->>'id' OR COALESCE(latest->>'state','') NOT IN('ready','needs_review') OR(latest->>'state'='needs_review' AND(COALESCE(fact->>'outcome','') NOT IN('absence','leave_covered') OR fact->>'classified_kind' IS DISTINCT FROM fact->>'outcome' OR(fact->>'classified_approval_eligible')::boolean IS DISTINCT FROM true)) THEN state:='approved_fact_not_current';
     ELSE
      reconciliation:=COALESCE((time.attendance_fact_context_status(p_tenant,(i->>'id')::uuid)->>'classification_reconciliation_required')::boolean,true);
      state:=CASE WHEN reconciliation THEN 'classification_reconciliation_required' ELSE 'approved_fact_current' END;
     END IF;
    END IF;
   ELSIF state='expected_workday' THEN state:=CASE WHEN elapsed THEN 'expected_instance_missing' ELSE 'not_yet_elapsed' END;
   END IF;
   provenance:=jsonb_build_object('assignments',assignments,'overrides',overrides,'policy',policy,'bounds',bounds,'instances',instances,'latest_fact',fact,'latest_interpretation',latest,'classification_reconciliation_required',reconciliation);
   items:=items||jsonb_build_array(jsonb_build_object('date',d,'employment_id',employment_row.id,'employee_id',employment_row.employee_id,'expected',expected,'elapsed',elapsed,'state',state,'provenance',provenance));
  END LOOP;
 END LOOP;
 SELECT COALESCE(jsonb_agg(x ORDER BY x->>'date',x->>'employment_id'),'[]') INTO items FROM jsonb_array_elements(items)x;
 RETURN jsonb_build_object('enabled',true,'items',items);
END $f$;
CREATE FUNCTION payroll.capture_time_coverage(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE bounds payroll.periods%ROWTYPE;d date;last_day date;capture jsonb;items jsonb:='[]';
BEGIN
 PERFORM payroll.optional_capture_authorized(p_tenant,p_employer);
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()) THEN RETURN jsonb_build_object('contract','cube4-time-coverage-v1','enabled',false,'items','[]'::jsonb);END IF;
 SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND OR NOT isfinite(bounds.starts_on) OR NOT isfinite(bounds.ends_on) OR bounds.ends_on-bounds.starts_on NOT BETWEEN 0 AND 365 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
 d:=bounds.starts_on;
 WHILE d<=bounds.ends_on LOOP
  last_day:=least(d+30,bounds.ends_on);capture:=payroll.capture_time_coverage_window(p_tenant,p_employer,d,last_day);
  items:=items||(capture->'items');
  IF jsonb_array_length(items)>200000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='54000';END IF;
  d:=last_day+1;
 END LOOP;
 RETURN jsonb_build_object('contract','cube4-time-coverage-v1','enabled',true,'items',items);
END $f$;
CREATE FUNCTION payroll.time_coverage_explanation(p_capture jsonb,p_employment uuid) RETURNS jsonb
LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
 WITH rows AS(SELECT x FROM jsonb_array_elements(COALESCE(p_capture->'items','[]'))x WHERE x->>'employment_id'=p_employment::text)
 SELECT jsonb_build_object('summary',jsonb_build_object('enabled',COALESCE((p_capture->>'enabled')::boolean,false),
  'status',CASE WHEN p_capture IS NULL THEN 'unavailable' WHEN p_capture->>'enabled'='false' THEN 'disabled' WHEN NOT EXISTS(SELECT 1 FROM rows) THEN 'unavailable' WHEN EXISTS(SELECT 1 FROM rows WHERE x->>'state' NOT IN('scheduled_nonworkday','approved_fact_current')) THEN 'needs_source_review' ELSE 'observationally_complete' END,
  'day_count',(SELECT count(*) FROM rows),'expected_days',(SELECT count(*) FROM rows WHERE(x->>'expected')::boolean),
  'approved_days',(SELECT count(*) FROM rows WHERE x->>'state'='approved_fact_current'),'missing_days',(SELECT count(*) FROM rows WHERE x->>'state'='expected_instance_missing'),
  'pending_days',(SELECT count(*) FROM rows WHERE x->>'state' IN('instance_open_or_pending','approved_fact_not_current','classification_reconciliation_required')),
  'future_days',(SELECT count(*) FROM rows WHERE x->>'state'='not_yet_elapsed'),'other_review_days',(SELECT count(*) FROM rows WHERE x->>'state' NOT IN('scheduled_nonworkday','approved_fact_current','expected_instance_missing','instance_open_or_pending','approved_fact_not_current','classification_reconciliation_required','not_yet_elapsed')),
  'payroll_ready',false),
  'days',COALESCE((SELECT jsonb_agg(jsonb_build_object('date',x->>'date','expected',(x->>'expected')::boolean,'elapsed',(x->>'elapsed')::boolean,'state',x->>'state') ORDER BY x->>'date') FROM rows),'[]'::jsonb))
$f$;
REVOKE ALL ON FUNCTION payroll.time_expected_bounds(date,jsonb),payroll.capture_time_coverage_window(uuid,uuid,date,date),payroll.capture_time_coverage(uuid,uuid,uuid),payroll.time_coverage_explanation(jsonb,uuid) FROM PUBLIC,anon,authenticated,service_role;
-- Patch actual capture and known base builder only. Existing optional_sources freshness compares the whole canonical object.
DO $f$ DECLARE definition text;old text;signature text;BEGIN
 definition:=pg_get_functiondef('payroll.capture_optional_sources(uuid,uuid,uuid)'::regprocedure);
 old:='''time'',jsonb_build_object(''enabled'',time_enabled,''items'',time_items)';
 IF position(old IN definition)=0 OR position('''coverage''' IN definition)>0 THEN RAISE EXCEPTION 'unexpected_time_coverage_capture_anchor';END IF;
 EXECUTE replace(definition,old,'''time'',jsonb_build_object(''enabled'',time_enabled,''items'',time_items,''coverage'',payroll.capture_time_coverage(p_tenant,p_employer,p_period))');
 signature:=CASE WHEN to_regprocedure('payroll.build_review_before_advances(jsonb)') IS NOT NULL THEN 'payroll.build_review_before_advances(jsonb)' ELSE 'payroll.build_review(jsonb)' END;
 definition:=pg_get_functiondef(signature::regprocedure);old:='''source_summary'',source_context->''summary'',''source_days'',source_context->''days''';
 IF position(old IN definition)=0 OR position('cube4-review-v4-daily-sources' IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_coverage_review_anchor';END IF;
 EXECUTE replace(definition,old,'''source_summary'',(source_context->''summary'')||jsonb_build_object(''time_coverage'',payroll.time_coverage_explanation(p_manifest->''optional_sources''->''time''->''coverage'',hid)->''summary''),''source_days'',source_context->''days'',''source_coverage_days'',payroll.time_coverage_explanation(p_manifest->''optional_sources''->''time''->''coverage'',hid)->''days''');
 definition:=pg_get_functiondef('public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)'::regprocedure);old:='e-''lines''-''unresolved_parts''-''dated_rates''-''source_days''';
 IF position(old IN definition)=0 THEN RAISE EXCEPTION 'unexpected_time_coverage_workspace_anchor';END IF;EXECUTE replace(definition,old,old||'-''source_coverage_days''');
END $f$;
