-- Owner-authorized S4: immutable future versions of the tenant-wide period policy.
-- Existing function identities/ACLs, receipt replay, tenant locks and frozen guards retained.

CREATE OR REPLACE FUNCTION public.payroll_save_input_before_recurring_debts(p_tenant uuid, p_employer uuid, p_kind text, p_employment uuid, p_period uuid, p_head uuid, p_expected integer, p_from date, p_until date, p_data jsonb, p_operation text, p_attempt uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE a uuid; permission text; current payroll.input_versions%ROWTYPE; head payroll.input_heads%ROWTYPE; receipt payroll.command_receipts%ROWTYPE; intent jsonb; result jsonb; next_status text; component payroll.input_versions%ROWTYPE; bounds payroll.periods%ROWTYPE; BEGIN
 IF p_kind IS NULL OR p_operation IS NULL OR p_kind NOT IN('component','policy','recurring','manual_units','adjustment','opening_ytd','statutory_context') OR p_operation NOT IN('save','approve','cancel') OR p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 permission:=payroll.input_permission(p_kind,p_operation);
 PERFORM payroll.authorized(p_tenant,permission,true);
 PERFORM payroll.lock_input_scope(p_tenant,p_employer,p_employment);
 a:=payroll.authorized(p_tenant,permission,true);
 intent:=jsonb_build_object('operation','input_'||p_operation,'employer',p_employer,'kind',p_kind,'employment',p_employment,'period',p_period,'head',p_head,'expected',p_expected,'from',p_from,'until',p_until,'data',p_data);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 IF (p_kind IN('recurring','manual_units','adjustment','opening_ytd','statutory_context'))<>(p_employment IS NOT NULL) OR (p_kind IN('manual_units','adjustment'))<>(p_period IS NOT NULL) OR p_from IS NULL OR (p_until IS NOT NULL AND p_until<=p_from) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_employment IS NOT NULL AND NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment AND employer_entity_id=p_employer AND payroll_eligible AND start_date<=COALESCE((SELECT ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND id=p_period),p_from) AND (end_date IS NULL OR end_date>=p_from)) THEN RAISE EXCEPTION 'payroll_employment_unavailable' USING ERRCODE='22023'; END IF;
 IF p_period IS NOT NULL THEN
  SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
  IF NOT FOUND OR p_from<>bounds.starts_on OR p_until IS DISTINCT FROM bounds.ends_on+1 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 END IF;

 IF p_kind='statutory_context' AND(NOT isfinite(p_from) OR(p_until IS NOT NULL AND NOT isfinite(p_until))) THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 PERFORM payroll.validate_input(p_kind,p_data);
 IF p_kind='opening_ytd' THEN PERFORM payroll.validate_opening_coverage(p_data,p_from); END IF; IF p_kind='manual_units' AND p_operation IN('save','approve') AND p_data->>'source'='time' AND NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()) THEN RAISE EXCEPTION 'payroll_time_source_disabled' USING ERRCODE='55000';END IF;
 IF p_head IS NOT NULL THEN
  SELECT * INTO head FROM payroll.input_heads WHERE tenant_id=p_tenant AND (employer_id=p_employer OR p_kind='policy') AND id=p_head FOR UPDATE;
  IF NOT FOUND OR head.kind<>p_kind OR head.employment_id IS DISTINCT FROM p_employment OR head.period_id IS DISTINCT FROM p_period THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
  IF p_kind IN('manual_units','adjustment','opening_ytd') AND EXISTS(SELECT 1 FROM payroll.input_frozen_versions f JOIN payroll.input_versions v ON v.tenant_id=f.tenant_id AND v.id=f.version_id WHERE v.tenant_id=p_tenant AND v.head_id=head.id) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514'; END IF;
  SELECT * INTO current FROM payroll.input_versions WHERE tenant_id=p_tenant AND head_id=p_head AND revision=head.revision;
  IF head.revision<>p_expected OR current.status IN('applied','cancelled') OR (p_operation='save' AND p_kind IN('manual_units','adjustment') AND current.status<>'draft') THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
  IF p_operation<>'save' AND (p_data<>current.data OR p_from<>current.effective_from OR p_until IS DISTINCT FROM current.effective_until) THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
 ELSE
  IF p_expected<>0 OR p_operation<>'save' THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
  INSERT INTO payroll.input_heads(tenant_id,employer_id,kind,employment_id,period_id) VALUES(p_tenant,p_employer,p_kind,p_employment,p_period) RETURNING * INTO head;
 END IF;
 IF p_operation='approve' AND (p_kind NOT IN('manual_units','adjustment') OR current.status<>'draft') OR p_operation='cancel' AND (p_kind NOT IN('manual_units','adjustment') OR current.status NOT IN('draft','approved')) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 -- Policy versions apply to periods STARTING on/after this threshold, never midway.
 IF p_kind='policy' AND (NOT isfinite(p_from) OR (p_until IS NOT NULL AND NOT isfinite(p_until))
  OR head.revision>0 AND (p_from<=(clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date
   OR p_from<=current.effective_from OR p_until IS NOT NULL)) THEN
  RAISE EXCEPTION 'payroll_policy_future_date_required' USING ERRCODE='22023';
 END IF;
 IF p_kind IN('component','recurring','opening_ytd','statutory_context') AND head.revision>0 AND (p_from<=current.effective_from OR p_kind NOT IN('component','statutory_context') AND current.effective_until IS NOT NULL AND p_from>=current.effective_until) THEN RAISE EXCEPTION 'payroll_effective_conflict' USING ERRCODE='PT409'; END IF;
 IF p_kind='opening_ytd' AND ((p_data->>'year')::int<>extract(year FROM p_from)::int OR head.revision>0 AND p_data->>'year'<>current.data->>'year') THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_kind='component' AND EXISTS(SELECT 1 FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.kind='component' AND h.id<>head.id AND v.data->>'key'=p_data->>'key') THEN RAISE EXCEPTION 'payroll_duplicate_component' USING ERRCODE='23505'; END IF;
 IF p_kind='manual_units' AND NOT EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=p_tenant AND h.id=p_employment AND h.pay_basis='daily' AND (p_data->>'units')::numeric<=least(COALESCE(h.end_date,bounds.ends_on),bounds.ends_on)-greatest(h.start_date,bounds.starts_on)+1) THEN RAISE EXCEPTION 'payroll_units_capacity' USING ERRCODE='22023'; END IF;
 IF p_kind IN('recurring','adjustment') THEN
  SELECT v.* INTO component FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.id=(p_data->>'component_id')::uuid AND h.kind='component' AND v.effective_from<=p_from ORDER BY v.effective_from DESC,v.revision DESC LIMIT 1;
  IF NOT FOUND OR component.data->>'active'<>'true' OR (component.effective_until IS NOT NULL AND component.effective_until<=p_from) OR (p_kind='recurring' AND component.data->>'behavior'<>'recurring') OR (p_kind='adjustment' AND (component.data->>'behavior'<>'period_input' OR component.data->>'classification'='employer_cost' OR component.data->>'calculation'<>'fixed')) OR (p_kind='recurring' AND component.data->>'calculation'='percentage' AND (p_data->>'value')::numeric>100) THEN RAISE EXCEPTION 'payroll_component_unavailable' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_kind IN('recurring','opening_ytd','manual_units') AND EXISTS(
  SELECT 1 FROM payroll.input_heads h JOIN (
   SELECT iv.*,lead(iv.effective_from) OVER(PARTITION BY iv.tenant_id,iv.head_id ORDER BY iv.effective_from,iv.revision) AS successor_from
   FROM payroll.input_versions iv WHERE iv.tenant_id=p_tenant
  ) v ON v.tenant_id=h.tenant_id AND v.head_id=h.id
  WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer
   AND (h.employment_id=p_employment OR p_kind='opening_ytd' AND h.employment_id IN(SELECT id FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND employee_id=(SELECT employee_id FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment)))
   AND h.kind=p_kind AND h.id<>head.id AND v.status<>'cancelled'
   AND ((p_kind='manual_units' AND h.period_id=p_period AND v.revision=h.revision)
    OR (p_kind='opening_ytd' AND v.data->>'year'=p_data->>'year' AND v.revision=h.revision)
    OR (p_kind='recurring' AND v.data->>'component_id'=p_data->>'component_id'
     AND daterange(v.effective_from,LEAST(v.effective_until,v.successor_from),'[)')&&daterange(p_from,p_until,'[)')))
 ) THEN RAISE EXCEPTION 'payroll_duplicate_input' USING ERRCODE='23505'; END IF;
 IF EXISTS(SELECT 1 FROM payroll.people_frozen_contexts f JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id WHERE f.tenant_id=p_tenant AND(f.employer_id=p_employer OR p_kind='policy') AND (p_employment IS NULL OR f.employment_id=p_employment) AND (p_kind='opening_ytd' AND extract(year FROM p.ends_on)::text=p_data->>'year' OR p_kind<>'opening_ytd' AND daterange(p.starts_on,p.ends_on,'[]')&&daterange(p_from,p_until,'[)'))) THEN RAISE EXCEPTION 'payroll_correction_required' USING ERRCODE='23514'; END IF;
 next_status:=CASE WHEN p_operation='approve' THEN 'approved' WHEN p_operation='cancel' THEN 'cancelled' ELSE 'draft' END;
 INSERT INTO payroll.input_versions(tenant_id,employer_id,head_id,revision,data,effective_from,effective_until,status,created_by,approved_by,approved_at) VALUES(p_tenant,CASE WHEN p_kind='policy' THEN head.employer_id ELSE p_employer END,head.id,head.revision+1,CASE WHEN p_kind='recurring' THEN p_data||jsonb_build_object('component_interpretation',payroll.component_interpretation(component.data)) ELSE p_data END,p_from,p_until,next_status,a,CASE WHEN next_status='approved' THEN a END,CASE WHEN next_status='approved' THEN clock_timestamp() END);
 UPDATE payroll.input_heads SET revision=revision+1 WHERE tenant_id=p_tenant AND id=head.id;
 result:=jsonb_build_object('id',head.id,'revision',head.revision+1,'status',next_status);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'input_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,permission,true); RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION payroll.build_review_before_advances(p_manifest jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE period jsonb:=p_manifest->'period'; first_day date:=(period->>'starts_on')::date; last_day date:=(period->>'ends_on')::date;
 transition boolean:=(period->>'is_transition')::boolean; period_days integer:=last_day-first_day+1; mode text; policy jsonb;
 employee jsonb; employee_manifest jsonb; h jsonb; hid uuid; d date; starts date; ends date; eligible_days integer; denominator numeric;
 compensation jsonb; rate numeric; daily_units jsonb; units numeric; minimum_rate numeric; maximum_rate numeric; basis text;
 base_parts jsonb; unresolved_parts jsonb; base_raw numeric; base_value numeric; parts jsonb; lines jsonb; employees jsonb:='[]'; issues jsonb:='[]'; employee_issues jsonb;
 complete boolean; coverage_gap boolean; assignment_gap boolean; component_head uuid; component jsonb; assignment jsonb; component_data jsonb;
 component_kind text; component_name text; component_value numeric; component_part numeric;part_n numeric;part_d numeric; component_proration text; matches integer; daily_component_gap boolean; covered_component_days integer; percentage_parts integer; percentage_values integer; percentage_classes integer; component_classes integer; component_methods integer; component_behaviors integer; component_proration_modes integer; full_component_values integer;
 gross numeric; deductions numeric; costs numeric; known_gross numeric:=0; known_deductions numeric:=0; known_costs numeric:=0; known_earning_lines integer:=0; employee_earning_lines integer; all_complete boolean:=true;
 source_context jsonb;daily_context jsonb;coverage_check jsonb;heads record; approved_input jsonb; previous_input jsonb; item jsonb; pack_count integer;
BEGIN
 IF first_day IS NULL OR last_day IS NULL OR period_days NOT BETWEEN 1 AND 366 THEN RAISE EXCEPTION 'payroll_period_invalid' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_manifest->'employees')>5000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='55000'; END IF;
 SELECT i INTO policy FROM jsonb_array_elements(p_manifest->'inputs')i WHERE i->'head'->>'kind'='policy' AND(i->'version'->>'effective_from')::date<=first_day ORDER BY(i->'version'->>'effective_from')::date DESC,(i->'version'->>'revision')::int DESC LIMIT 1;
 -- A period retains its start-date policy even if a later version starts mid-period.
 -- An explicit expiry still has to cover the entire period; never revive an older version.
 mode:=policy->'version'->'data'->>'mode';
 IF policy IS NULL OR policy->'version'->>'status'='cancelled'
  OR mode IS NULL OR mode NOT IN('calendar_days','fixed_30_day')
  OR (policy->'version'->>'effective_until' IS NOT NULL
   AND (policy->'version'->>'effective_until')::date<=last_day) THEN
  mode:=NULL;issues:=issues||jsonb_build_array(payroll.issue('policy_coverage_gap',NULL,'payroll_config'));
 END IF;
 IF p_manifest->'calendar_semantics'->>'state' IN('unverified','frozen_correction_required') THEN mode:=NULL;issues:=issues||jsonb_build_array(payroll.issue(CASE WHEN p_manifest->'calendar_semantics'->>'state'='frozen_correction_required' THEN 'calendar_historical_correction_required' ELSE 'calendar_history_unverified' END,NULL,'payroll_config'));END IF; IF mode IS NULL THEN issues:=issues||jsonb_build_array(payroll.issue('policy_missing',NULL,'payroll_config')); END IF;
 SELECT count(*) INTO pack_count FROM jsonb_array_elements(p_manifest->'packs')s WHERE s->>'state'='verified' AND(s->>'effective_from')::date<=first_day AND(s->>'effective_until' IS NULL OR(s->>'effective_until')::date>last_day);
 issues:=issues||jsonb_build_array(payroll.issue(CASE WHEN pack_count=0 THEN 'statutory_pack_unqualified' ELSE 'statutory_adapter_unqualified' END,NULL,'compliance'));
 IF (p_manifest->'optional'->>'time')::boolean THEN issues:=issues||jsonb_build_array(payroll.issue('time_integration_pending',NULL,'payroll_time')); all_complete:=false; END IF;
 IF (p_manifest->'optional'->>'leave')::boolean THEN issues:=issues||jsonb_build_array(payroll.issue('leave_integration_pending',NULL,'payroll_leave')); all_complete:=false; END IF;
 IF jsonb_array_length(p_manifest->'corrections')>0 THEN issues:=issues||jsonb_build_array(payroll.issue('correction_open',NULL,'payroll_correction')); END IF;
 IF jsonb_array_length(p_manifest->'employees')=0 THEN all_complete:=false;issues:=issues||jsonb_build_array(payroll.issue('no_eligible_employees',NULL,'people')); END IF;
 FOR employee IN SELECT value FROM jsonb_array_elements(p_manifest->'employees') LOOP
  h:=employee->'employment';hid:=(h->>'id')::uuid;basis:=h->>'pay_basis';starts:=greatest(first_day,(h->>'start_date')::date);ends:=least(last_day,COALESCE((h->>'end_date')::date,last_day));eligible_days:=ends-starts+1;
  employee_manifest:=p_manifest||jsonb_build_object(
   'compensation',COALESCE((SELECT jsonb_agg(c ORDER BY c->>'valid_from',c->>'id') FROM jsonb_array_elements(p_manifest->'compensation')c WHERE(c->>'employment_id')::uuid=hid),'[]'),
   'assignments',COALESCE((SELECT jsonb_agg(w ORDER BY w->>'valid_from',w->>'id') FROM jsonb_array_elements(p_manifest->'assignments')w WHERE(w->>'employment_id')::uuid=hid),'[]'),
   'inputs',COALESCE((SELECT jsonb_agg(i ORDER BY i->'head'->>'id',(i->'version'->>'revision')::int) FROM jsonb_array_elements(p_manifest->'inputs')i
    WHERE i->'head'->>'kind'='policy' OR(i->'head'->>'employment_id')::uuid=hid OR i->'head'->>'kind'='opening_ytd' AND i->'head'->>'employee_id'=h->>'employee_id'
     OR i->'head'->>'kind'='component' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p_manifest->'inputs')a WHERE(a->'head'->>'employment_id')::uuid=hid AND a->'head'->>'kind' IN('recurring','adjustment') AND a->'version'->'data'->>'component_id'=i->'head'->>'id')),'[]'));
  source_context:=payroll.reconcile_employee_sources(p_manifest,h);daily_context:=NULL;employee_issues:='[]';unresolved_parts:='[]';base_parts:='[]';parts:='[]';complete:=mode IS NOT NULL;coverage_gap:=false;assignment_gap:=false;minimum_rate:=NULL;maximum_rate:=NULL;units:=NULL;
  IF mode IS NULL THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('policy_missing',hid,'payroll_config')); END IF;
  FOR d IN SELECT generate_series(starts,ends,interval '1 day')::date LOOP
   SELECT c INTO compensation FROM jsonb_array_elements(employee_manifest->'compensation')c WHERE(c->>'valid_from')::date<=d AND(c->>'valid_until' IS NULL OR(c->>'valid_until')::date>d) LIMIT 1;
   IF compensation IS NULL THEN coverage_gap:=true;ELSE
    rate:=(compensation->>'amount')::numeric;minimum_rate:=least(minimum_rate,rate);maximum_rate:=greatest(maximum_rate,rate);
    denominator:=CASE WHEN transition THEN CASE WHEN mode='fixed_30_day' THEN 30 ELSE extract(day FROM date_trunc('month',d)+interval '1 month - 1 day') END WHEN mode='fixed_30_day' AND eligible_days<period_days THEN greatest(30,eligible_days) ELSE period_days END;
    base_parts:=base_parts||jsonb_build_array(jsonb_build_object('date',d,'rate',rate::text,'denominator',denominator,'_numerator',(rate*100)::text,'_denominator',(denominator*100)::text,'compensation_id',compensation->>'id','raw',(rate::numeric(38,20)/denominator)::text));
   END IF;
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employee_manifest->'assignments')w WHERE(w->>'valid_from')::date<=d AND(w->>'valid_until' IS NULL OR(w->>'valid_until')::date>d)) THEN assignment_gap:=true; END IF;
  END LOOP;
  IF coverage_gap THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('compensation_gap',hid,'people')); END IF;
  IF assignment_gap THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('assignment_gap',hid,'people')); END IF;
  IF basis='daily' THEN
   daily_context:=payroll.daily_source_parts(employee_manifest,h,source_context,base_parts,minimum_rate,maximum_rate);
   units:=(daily_context->>'units')::numeric;base_parts:=daily_context->'parts';
   employee_issues:=employee_issues||(daily_context->'issues');
   IF daily_context->'issues'<>'[]'::jsonb THEN complete:=false;END IF;
   source_context:=jsonb_set(source_context,'{summary}',source_context->'summary'||jsonb_build_object('selected_source',daily_context->>'source','approved_units',units,'status',CASE WHEN daily_context->'issues'<>'[]'::jsonb OR source_context->'issues'<>'[]'::jsonb OR daily_context->>'source'='time' THEN 'needs_source_review' ELSE source_context->'summary'->>'status' END,'coverage',CASE WHEN daily_context->>'source'='time' THEN 'captured_parts_only' ELSE 'approved_manual_total' END));
   IF daily_context->>'source'='time' THEN
    -- Require canonical expected-day coverage; missing dates never imply absence or work.
    coverage_check:=payroll.complete_daily_time_coverage(employee_manifest,h,source_context,base_parts);
     IF coverage_check->>'complete' IS DISTINCT FROM 'true' THEN
       complete:=false;employee_issues:=employee_issues||(coverage_check->'issues');
     ELSE
       source_context:=jsonb_set(source_context,'{summary}',source_context->'summary'||jsonb_build_object('operational_complete',true,'coverage','operational_complete','status','reconciliation_ready'));
     END IF;
   END IF;
  END IF;

  IF basis='monthly' AND(p_manifest->'optional'->>'time'='true' OR p_manifest->'optional'->>'leave'='true') THEN
   daily_context:=payroll.monthly_source_parts(employee_manifest,h,source_context,base_parts,mode);
   base_parts:=daily_context->'parts';source_context:=jsonb_set(source_context,'{summary}',daily_context->'summary');
   employee_issues:=employee_issues||(daily_context->'issues');
   IF daily_context->'issues'<>'[]'::jsonb THEN complete:=false;END IF;
  END IF;
  IF source_context->'issues'<>'[]'::jsonb THEN complete:=false;employee_issues:=employee_issues||(source_context->'issues');END IF;
  IF mode IS NULL OR basis='daily' AND(coverage_gap OR units IS NULL) THEN base_parts:='[]';END IF;
  SELECT COALESCE(sum((b->>'raw')::numeric),0) INTO base_raw FROM jsonb_array_elements(base_parts)b;
  base_value:=CASE WHEN complete THEN payroll.round_fraction(payroll.parts_fraction(base_parts)) ELSE NULL END;
  IF jsonb_array_length(base_parts)>0 THEN parts:=jsonb_build_array(jsonb_build_object('component','base','name',CASE WHEN complete THEN 'الأجر الأساسي' ELSE 'الأجزاء المعروفة من الأجر الأساسي' END,'classification','earning','raw',base_raw::text,'detail',base_parts)); END IF;
  -- Recurring heads are resolved per civil date, preserving successor/expiry semantics.
  FOR heads IN SELECT DISTINCT(i->'head'->>'id')::uuid AS id FROM jsonb_array_elements(employee_manifest->'inputs')i WHERE i->'head'->>'kind'='component' LOOP
   component_head:=heads.id;daily_component_gap:=false;
   SELECT count(*) INTO covered_component_days FROM generate_series(starts,ends,interval '1 day')covered_date WHERE jsonb_array_length(payroll.manifest_recurring(employee_manifest,hid,component_head,covered_date::date))>0 AND COALESCE(payroll.manifest_input(employee_manifest,component_head,covered_date::date)->'version'->'data'->>'active','false')='true' AND(payroll.manifest_input(employee_manifest,component_head,covered_date::date)->'version'->>'effective_until' IS NULL OR(payroll.manifest_input(employee_manifest,component_head,covered_date::date)->'version'->>'effective_until')::date>covered_date::date);
   FOR d IN SELECT generate_series(starts,ends,interval '1 day')::date LOOP
    component:=payroll.manifest_input(employee_manifest,component_head,d);component_data:=component->'version'->'data';
    IF component IS NULL OR component_data->>'active'<>'true' OR(component->'version'->>'effective_until' IS NOT NULL AND(component->'version'->>'effective_until')::date<=d) THEN CONTINUE; END IF;
    SELECT count(*),COALESCE(sum((i->'version'->'data'->>'value')::numeric),0) INTO matches,component_value FROM jsonb_array_elements(payroll.manifest_recurring(employee_manifest,hid,component_head,d))i;
    IF matches=0 THEN CONTINUE; END IF;
    IF matches>1 THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('recurring_overlap',hid,'payroll_inputs'));CONTINUE; END IF; IF EXISTS(SELECT 1 FROM jsonb_array_elements(payroll.manifest_recurring(employee_manifest,hid,component_head,d))a WHERE NOT payroll.recurring_interpretation_matches(employee_manifest,a,component)) THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('recurring_interpretation_changed',hid,'payroll_inputs'));CONTINUE;END IF;
    component_kind:=component_data->>'classification';component_name:=component_data->>'name';component_proration:=COALESCE(component_data->>'proration','salary_proration');
    IF mode IS NULL AND component_data->>'calculation'='fixed' AND component_proration='salary_proration' THEN CONTINUE; END IF;
    IF component_data->>'calculation'='percentage' THEN
     IF jsonb_array_length(base_parts)=0 THEN CONTINUE; END IF;
     IF basis='daily' AND(units IS NULL OR daily_context->>'source' IS DISTINCT FROM 'time' AND minimum_rate IS DISTINCT FROM maximum_rate) THEN CONTINUE; END IF;
     SELECT(b->>'raw')::numeric,(b->>'_numerator')::numeric,(b->>'_denominator')::numeric INTO component_part,part_n,part_d FROM jsonb_array_elements(base_parts)b WHERE(b->>'date')::date=d;
     IF component_part IS NULL THEN CONTINUE; END IF;
     component_part:=component_part*component_value/100;part_n:=part_n*component_value*100;part_d:=part_d*10000;
    ELSE
     denominator:=CASE WHEN component_proration='paid_full_period' THEN covered_component_days WHEN transition THEN CASE WHEN mode='fixed_30_day' THEN 30 ELSE extract(day FROM date_trunc('month',d)+interval '1 month - 1 day') END WHEN mode='fixed_30_day' AND eligible_days<period_days THEN greatest(30,eligible_days) ELSE period_days END;
     component_part:=component_value::numeric(38,20)/denominator;part_n:=component_value*100;part_d:=denominator*100;
    END IF;
    parts:=parts||jsonb_build_array(jsonb_build_object('component',component_head,'name',component_name,'classification',component_kind,'raw',component_part::text,'_numerator',part_n::text,'_denominator',part_d::text,'date',d,'calculation',component_data->>'calculation','behavior',component_data->>'behavior','proration',component_proration,'denominator',CASE WHEN component_data->>'calculation'='fixed' THEN denominator END,'assignment_value',component_value::text,'component_version',component->'version'->>'id',
 'declared_taxable',CASE component_data->>'taxable' WHEN 'true' THEN true WHEN 'false' THEN false END,
 'declared_social',CASE component_data->>'social' WHEN 'true' THEN true WHEN 'false' THEN false END,
 'declared_visible',CASE component_data->>'visible' WHEN 'true' THEN true WHEN 'false' THEN false END));
   END LOOP;
   SELECT count(DISTINCT p->>'classification'),count(DISTINCT p->>'calculation'),count(DISTINCT p->>'behavior'),count(DISTINCT p->>'proration'),count(DISTINCT p->>'assignment_value') FILTER(WHERE p->>'proration'='paid_full_period') INTO component_classes,component_methods,component_behaviors,component_proration_modes,full_component_values FROM jsonb_array_elements(parts)p WHERE p->>'component'=component_head::text;
   IF component_proration_modes>1 OR full_component_values>1 THEN
    complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('component_full_period_change',hid,'payroll_inputs'));
    unresolved_parts:=unresolved_parts||COALESCE((SELECT jsonb_agg(p-'raw') FROM jsonb_array_elements(parts)p WHERE p->>'component'=component_head::text),'[]');
    SELECT COALESCE(jsonb_agg(p),'[]') INTO parts FROM jsonb_array_elements(parts)p WHERE p->>'component'<>component_head::text;
   END IF;
   IF component_classes>1 OR component_methods>1 OR component_behaviors>1 OR EXISTS(SELECT 1 FROM jsonb_array_elements(parts)p WHERE p->>'component'=component_head::text AND p->>'behavior'<>'recurring') THEN
    complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('component_behavior_changed',hid,'payroll_inputs'));
    unresolved_parts:=unresolved_parts||COALESCE((SELECT jsonb_agg(p-'raw') FROM jsonb_array_elements(parts)p WHERE p->>'component'=component_head::text),'[]');
    SELECT COALESCE(jsonb_agg(p),'[]') INTO parts FROM jsonb_array_elements(parts)p WHERE p->>'component'<>component_head::text;
   END IF;
   IF basis='daily' AND daily_context->>'source' IS DISTINCT FROM 'time' THEN
    SELECT count(*),count(DISTINCT p->>'assignment_value'),count(DISTINCT p->>'classification') INTO percentage_parts,percentage_values,percentage_classes FROM jsonb_array_elements(parts)p WHERE p->>'component'=component_head::text AND p->>'calculation'='percentage';
    daily_component_gap:=percentage_parts>0 AND(percentage_parts<>eligible_days OR percentage_values>1 OR percentage_classes>1);
    IF daily_component_gap THEN SELECT COALESCE(jsonb_agg(p),'[]') INTO parts FROM jsonb_array_elements(parts)p WHERE p->>'component'<>component_head::text; END IF;
   END IF;
   IF daily_component_gap THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('daily_percentage_allocation_needed',hid,'payroll_units')); END IF;
  END LOOP;
  -- Only the latest approved adjustment version contributes. Amount is unchanged by proration.
  FOR heads IN SELECT DISTINCT(i->'head'->>'id')::uuid AS id FROM jsonb_array_elements(employee_manifest->'inputs')i WHERE i->'head'->>'kind'='adjustment' AND(i->'head'->>'employment_id')::uuid=hid LOOP
   approved_input:=payroll.manifest_input(employee_manifest,heads.id,last_day);
   IF approved_input->'version'->>'status'<>'approved' THEN CONTINUE; END IF;
   component:=payroll.manifest_input(employee_manifest,(approved_input->'version'->'data'->>'component_id')::uuid,first_day);component_data:=component->'version'->'data';
   IF component IS NULL OR component_data->>'active'<>'true' OR component_data->>'calculation'<>'fixed' OR component_data->>'behavior'<>'period_input' OR component_data->>'classification' NOT IN('earning','deduction') OR(component->'version'->>'effective_until' IS NOT NULL AND(component->'version'->>'effective_until')::date<=first_day) THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('adjustment_component_changed',hid,'payroll_finance')); CONTINUE; END IF;
   parts:=parts||jsonb_build_array(jsonb_build_object('component','adjustment:'||heads.id,'name',component_data->>'name','classification',component_data->>'classification','raw',approved_input->'version'->'data'->>'amount','reason',approved_input->'version'->'data'->>'reason','input_version',approved_input->'version'->>'id',
 'component_head',component->'head'->>'id','component_version',component->'version'->>'id',
 'declared_taxable',CASE component_data->>'taxable' WHEN 'true' THEN true WHEN 'false' THEN false END,
 'declared_social',CASE component_data->>'social' WHEN 'true' THEN true WHEN 'false' THEN false END,
 'declared_visible',CASE component_data->>'visible' WHEN 'true' THEN true WHEN 'false' THEN false END));
  END LOOP;
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.component,x.classification),'[]') INTO lines FROM(SELECT part->>'component' AS component,max(part->>'name') AS name,part->>'classification' AS classification,payroll.round_fraction(payroll.parts_fraction(jsonb_agg(part)))::text AS amount,jsonb_agg(part ORDER BY part->>'date',part->>'component_version') AS details FROM jsonb_array_elements(parts)part GROUP BY part->>'component',part->>'classification')x;
  SELECT COALESCE(sum((l->>'amount')::numeric) FILTER(WHERE l->>'classification'='earning'),0),COALESCE(sum((l->>'amount')::numeric) FILTER(WHERE l->>'classification'='deduction'),0),COALESCE(sum((l->>'amount')::numeric) FILTER(WHERE l->>'classification'='employer_cost'),0) INTO gross,deductions,costs FROM jsonb_array_elements(lines)l;
  IF complete AND deductions>gross THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('negative_operational_balance',hid,'payroll_finance')); END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employee_manifest->'inputs')i WHERE i->'head'->>'kind'='opening_ytd' AND((i->'head'->>'employment_id')::uuid=hid OR i->'head'->>'employee_id'=h->>'employee_id')) THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('opening_ytd_unknown',hid,'payroll_ytd')); END IF;
  SELECT count(*) INTO employee_earning_lines FROM jsonb_array_elements(lines)l WHERE l->>'classification'='earning';known_earning_lines:=known_earning_lines+employee_earning_lines;
  known_gross:=known_gross+gross;known_deductions:=known_deductions+deductions;known_costs:=known_costs+costs;all_complete:=all_complete AND complete;
  employees:=employees||jsonb_build_array(jsonb_build_object('employment_id',hid,'employee_id',h->>'employee_id','name',employee->>'name','code',employee->>'code','pay_basis',basis,'starts_on',starts,'ends_on',ends,'eligible_days',eligible_days,'approved_units',units::text,'base',base_value::text,'gross',CASE WHEN complete THEN gross::text END,'known_gross',CASE WHEN employee_earning_lines>0 THEN gross::text END,'deductions',deductions::text,'employer_cost',costs::text,'net',NULL,'gross_complete',complete,'lines',lines,'unresolved_parts',unresolved_parts,'dated_rates',COALESCE((SELECT jsonb_agg(jsonb_build_object('from',c->>'valid_from','until',c->>'valid_until','rate',c->>'amount') ORDER BY c->>'valid_from') FROM jsonb_array_elements(employee_manifest->'compensation')c),'[]'),'source_summary',(source_context->'summary')||jsonb_build_object('time_coverage',payroll.time_coverage_explanation(p_manifest->'optional_sources'->'time'->'coverage',hid)->'summary'),'source_days',source_context->'days','source_coverage_days',payroll.time_coverage_explanation(p_manifest->'optional_sources'->'time'->'coverage',hid)->'days','issues',employee_issues));
  issues:=issues||employee_issues;
 END LOOP;
 RETURN jsonb_build_object('engine','cube4-review-v5-complete-daily-time','employees',employees,'employee_count',jsonb_array_length(employees),'issues',issues,'gross',CASE WHEN all_complete THEN known_gross::text END,'known_gross',CASE WHEN known_earning_lines>0 THEN known_gross::text END,'deductions',known_deductions::text,'employer_cost',known_costs::text,'net',NULL,'statutory_deductions',NULL,'statutory_contributions',NULL,'gross_complete',all_complete,'financially_qualified',false,'policy',mode,'is_transition',transition);
END $function$;

CREATE OR REPLACE FUNCTION public.payroll_configuration_workspace(p_tenant uuid, p_employer uuid, p_after uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30, p_head uuid DEFAULT NULL::uuid, p_query text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE access jsonb; components jsonb; policy jsonb; selected jsonb; today_policy jsonb; today_on date:=(statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date;
 more boolean; employer_name text; component_min date; policy_min date; pattern text;
BEGIN
 access:=public.payroll_input_access(p_tenant);
 IF NOT ((access->>'payroll.view')::boolean OR (access->>'payroll.prepare')::boolean
  OR (access->>'payroll.approve')::boolean OR (access->>'payroll_config.manage')::boolean) THEN
  RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';
 END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_query IS NULL OR length(p_query)>120 THEN
  RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
 END IF;
 SELECT display_name INTO employer_name FROM platform_core.tenant_legal_entities
  WHERE tenant_id=p_tenant AND id=p_employer AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 pattern:='%'||replace(replace(replace(p_query,'\','\\'),'%','\%'),'_','\_')||'%';
 WITH page AS (
  SELECT h.id,h.kind,h.employment_id,h.period_id,v.revision,v.data,v.effective_from,v.effective_until,v.status
  FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision
  WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.kind='component'
   AND (p_after IS NULL OR h.id>p_after)
   AND ((v.data->>'name') ILIKE pattern ESCAPE '\' OR (v.data->>'key') ILIKE pattern ESCAPE '\')
  ORDER BY h.id LIMIT p_limit+1
 ), limited AS (SELECT * FROM page ORDER BY id LIMIT p_limit)
 SELECT coalesce(jsonb_agg(to_jsonb(limited) ORDER BY id),'[]'::jsonb),(SELECT count(*)>p_limit FROM page)
 INTO components,more FROM limited;
 SELECT jsonb_build_object('id',h.id,'kind',h.kind,'employment_id',h.employment_id,'period_id',h.period_id,
  'revision',v.revision,'data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'status',v.status)
 INTO policy FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision
 WHERE h.tenant_id=p_tenant AND h.kind='policy';
 IF p_head IS NOT NULL THEN
  SELECT jsonb_build_object('id',h.id,'kind',h.kind,'employment_id',h.employment_id,'period_id',h.period_id,
   'revision',v.revision,'data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'status',v.status)
  INTO selected FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id AND v.revision=h.revision
  WHERE h.tenant_id=p_tenant AND h.id=p_head AND (h.kind='policy' OR (h.kind='component' AND h.employer_id=p_employer));
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_configuration_missing' USING ERRCODE='P0002'; END IF;
 END IF;
 -- The existing save guard checks frozen PEOPLE contexts, including every
 -- employer for a tenant-wide policy. These are minima for open-ended ranges;
 -- finite ranges are still checked precisely by the unchanged write RPC.
 SELECT max(p.ends_on)+1,max(p.ends_on) FILTER(WHERE f.employer_id=p_employer)+1
 INTO policy_min,component_min FROM payroll.people_frozen_contexts f
 JOIN payroll.periods p ON p.tenant_id=f.tenant_id AND p.id=f.period_id WHERE f.tenant_id=p_tenant;
 SELECT jsonb_build_object('id',h.id,'kind',h.kind,'revision',v.revision,'data',v.data,'effective_from',v.effective_from,'effective_until',v.effective_until,'status',v.status)
 INTO today_policy FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id
 WHERE h.tenant_id=p_tenant AND h.kind='policy' AND v.effective_from<=today_on
 ORDER BY v.effective_from DESC,v.revision DESC LIMIT 1;
 IF today_policy->>'status'='cancelled' OR (today_policy->>'effective_until')::date<=today_on THEN today_policy:=NULL; END IF;
 IF policy IS NOT NULL THEN policy_min:=greatest(policy_min,(statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date+1); END IF;
 RETURN jsonb_build_object('access',access,'employer_name',employer_name,'components',components,
  'has_more',more,'policy',policy,'policy_today',today_policy,'policy_is_future',(policy->>'effective_from')::date>today_on,'selected',selected,'component_open_ended_min',component_min,'policy_open_ended_min',policy_min);
END $function$;
