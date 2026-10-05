-- Cube 4 Slice 3: immutable review candidates. No public approval, financial lock or money consumption.
CREATE TABLE payroll.runs (
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,period_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),
 revision integer NOT NULL DEFAULT 0,status text NOT NULL CHECK(status IN('draft','review','cancelled')),
 candidate_id uuid,created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 cancelled_by uuid REFERENCES auth.users(id),cancelled_at timestamptz,cancel_reason text,
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,employer_id,id),
 FOREIGN KEY(tenant_id,employer_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id),
 FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
CREATE UNIQUE INDEX payroll_one_active_run ON payroll.runs(tenant_id,employer_id,period_id) WHERE status IN('draft','review');
CREATE TABLE payroll.candidates (
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,run_id uuid NOT NULL,id uuid NOT NULL DEFAULT gen_random_uuid(),revision integer NOT NULL,
 engine_version text NOT NULL,input_manifest jsonb NOT NULL,output jsonb NOT NULL,created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,run_id,revision),
 FOREIGN KEY(tenant_id,employer_id,run_id) REFERENCES payroll.runs(tenant_id,employer_id,id));
ALTER TABLE payroll.runs ADD FOREIGN KEY(tenant_id,candidate_id) REFERENCES payroll.candidates(tenant_id,id);
CREATE TRIGGER payroll_candidate_immutable BEFORE UPDATE OR DELETE ON payroll.candidates FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
ALTER TABLE payroll.runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.candidates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.runs,payroll.candidates FROM PUBLIC,anon,authenticated,service_role;
-- Versioned integration boundary. No statutory pack or formula is guessed/qualified by this migration.
CREATE TABLE payroll.statutory_packs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),jurisdiction text NOT NULL CHECK(jurisdiction='EG'),family text NOT NULL CHECK(family='egypt_payroll'),version text NOT NULL,
 effective_from date NOT NULL,effective_until date,source_references jsonb NOT NULL,review_evidence jsonb NOT NULL,
 state text NOT NULL CHECK(state IN('unqualified','verified')),verified_by uuid REFERENCES auth.users(id),engine_adapter text,
 created_at timestamptz NOT NULL DEFAULT now(),CHECK(effective_until IS NULL OR effective_until>effective_from),
 CHECK(state<>'verified' OR verified_by IS NOT NULL AND jsonb_typeof(source_references)='array' AND jsonb_array_length(source_references)>0 AND review_evidence<>'{}'::jsonb));
ALTER TABLE payroll.statutory_packs ENABLE ROW LEVEL SECURITY;
CREATE TRIGGER payroll_statutory_pack_immutable BEFORE UPDATE OR DELETE ON payroll.statutory_packs FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
REVOKE ALL ON payroll.statutory_packs FROM PUBLIC,anon,authenticated,service_role;
-- Add only the accepted bounded recurring proration setting; legacy values use accepted default.
DO $f$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('payroll.validate_input(text,jsonb)'::regprocedure);
 IF definition NOT LIKE '%''visible'',''active'',''order''%' THEN RAISE EXCEPTION 'unexpected_component_validator'; END IF;
 definition:=replace(definition,'''visible'',''active'',''order''','''visible'',''active'',''proration'',''order''');
 definition:=replace(definition,'IF p_kind=''component'' THEN','IF p_kind=''component'' THEN
  IF COALESCE(p_data->>''proration'',''salary_proration'') NOT IN(''salary_proration'',''paid_full_period'') THEN RAISE EXCEPTION ''payroll_invalid'' USING ERRCODE=''22023''; END IF;');
 EXECUTE definition;
END $f$;
CREATE FUNCTION payroll.guard_open_run_calendar() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF EXISTS(SELECT 1 FROM payroll.runs WHERE tenant_id=NEW.tenant_id AND employer_id=NEW.employer_id AND status IN('draft','review')) THEN RAISE EXCEPTION 'payroll_open_run' USING ERRCODE='55000'; END IF;
 RETURN NEW;
END $f$;
CREATE TRIGGER payroll_calendar_open_run_guard BEFORE INSERT OR UPDATE ON payroll.calendar_versions FOR EACH ROW EXECUTE FUNCTION payroll.guard_open_run_calendar();
CREATE FUNCTION payroll.lock_run_scope(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM platform_core.tenants WHERE id=p_tenant FOR SHARE;
 PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() FOR SHARE;
 -- Include currently ineligible Employments: an eligibility change must serialize too.
 PERFORM 1 FROM people.employees e WHERE e.tenant_id=p_tenant AND EXISTS(SELECT 1 FROM people.employments h WHERE h.tenant_id=e.tenant_id AND h.employee_id=e.id AND h.employer_entity_id=p_employer AND h.start_date<=(SELECT ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period) AND(h.end_date IS NULL OR h.end_date>=(SELECT starts_on FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period))) ORDER BY e.id FOR UPDATE;
 PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND start_date<=(SELECT ends_on FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period) AND(end_date IS NULL OR end_date>=(SELECT starts_on FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period)) ORDER BY id FOR UPDATE;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
END $f$;
CREATE FUNCTION payroll.run_manifest(p_tenant uuid,p_employer uuid,p_period uuid) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT jsonb_build_object(
 'engine','cube4-review-v1','period',(SELECT to_jsonb(p) FROM payroll.periods p WHERE p.tenant_id=p_tenant AND p.employer_id=p_employer AND p.id=p_period),
 'employees',COALESCE((SELECT jsonb_agg(jsonb_build_object('employment',to_jsonb(h),'name',e.full_name,'code',e.employee_code) ORDER BY h.id) FROM people.employments h JOIN people.employees e ON e.tenant_id=h.tenant_id AND e.id=h.employee_id JOIN payroll.periods p ON p.tenant_id=h.tenant_id AND p.id=p_period WHERE h.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND h.start_date<=p.ends_on AND (h.end_date IS NULL OR h.end_date>=p.starts_on)),'[]'),
 'compensation',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.employment_id,c.valid_from,c.id) FROM people.compensation_versions c JOIN people.employments h ON h.tenant_id=c.tenant_id AND h.id=c.employment_id JOIN payroll.periods p ON p.tenant_id=c.tenant_id AND p.id=p_period WHERE c.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND daterange(c.valid_from,c.valid_until,'[)')&&daterange(p.starts_on,p.ends_on,'[]')),'[]'),
 'assignments',COALESCE((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.employment_id,w.valid_from,w.id) FROM people.work_assignments w JOIN people.employments h ON h.tenant_id=w.tenant_id AND h.id=w.employment_id JOIN payroll.periods p ON p.tenant_id=w.tenant_id AND p.id=p_period WHERE w.tenant_id=p_tenant AND h.employer_entity_id=p_employer AND h.payroll_eligible AND daterange(w.valid_from,w.valid_until,'[)')&&daterange(p.starts_on,p.ends_on,'[]')),'[]'),
 'inputs',COALESCE((SELECT jsonb_agg(jsonb_build_object('head',jsonb_build_object('id',h.id,'kind',h.kind,'employment_id',h.employment_id,'employee_id',(SELECT employee_id FROM people.employments WHERE tenant_id=h.tenant_id AND id=h.employment_id),'period_id',h.period_id),'version',to_jsonb(v)) ORDER BY h.id,v.revision) FROM payroll.input_heads h JOIN payroll.input_versions v ON v.tenant_id=h.tenant_id AND v.head_id=h.id JOIN payroll.periods p ON p.tenant_id=h.tenant_id AND p.id=p_period WHERE h.tenant_id=p_tenant AND(h.employer_id=p_employer OR h.kind='policy') AND(h.period_id IS NULL OR h.period_id=p_period) AND v.effective_from<=p.ends_on),'[]'),
 'packs',COALESCE((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.effective_from,s.id) FROM payroll.statutory_packs s JOIN payroll.periods p ON p.tenant_id=p_tenant AND p.id=p_period WHERE daterange(s.effective_from,s.effective_until,'[)')&&daterange(p.starts_on,p.ends_on,'[]')),'[]'),
 'optional',jsonb_build_object('time',platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',clock_timestamp()),'leave',platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',clock_timestamp()),'finance','adjustments_only'),
 'corrections',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.id) FROM payroll.correction_requirements c WHERE c.tenant_id=p_tenant AND c.employer_id=p_employer AND c.period_id=p_period),'[]')
 )
$f$;
-- Returns the latest dated version before checking expiry; inactive/expired versions never resurrect older values.
CREATE FUNCTION payroll.manifest_input(p_manifest jsonb,p_head uuid,p_date date) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT i FROM jsonb_array_elements(p_manifest->'inputs') i WHERE (i->'head'->>'id')::uuid=p_head AND (i->'version'->>'effective_from')::date<=p_date ORDER BY (i->'version'->>'effective_from')::date DESC,(i->'version'->>'revision')::int DESC LIMIT 1
$f$;
CREATE FUNCTION payroll.issue(p_code text,p_employment uuid DEFAULT NULL,p_owner text DEFAULT 'payroll') RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT jsonb_build_object('code',p_code,'employment_id',p_employment,'owner',p_owner,'blocking',true)
$f$;
CREATE FUNCTION payroll.manifest_recurring(p_manifest jsonb,p_employment uuid,p_component uuid,p_date date) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT COALESCE(jsonb_agg(i ORDER BY i->'head'->>'id'),'[]') FROM(
  SELECT payroll.manifest_input(p_manifest,(head->>'id')::uuid,p_date) AS i
  FROM(SELECT DISTINCT x->'head' AS head FROM jsonb_array_elements(p_manifest->'inputs')x WHERE x->'head'->>'kind'='recurring' AND(x->'head'->>'employment_id')::uuid=p_employment)heads
 )resolved WHERE i->'version'->'data'->>'component_id'=p_component::text AND(i->'version'->>'effective_until' IS NULL OR(i->'version'->>'effective_until')::date>p_date)
$f$;
CREATE FUNCTION payroll.build_review(p_manifest jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE period jsonb:=p_manifest->'period'; first_day date:=(period->>'starts_on')::date; last_day date:=(period->>'ends_on')::date;
 transition boolean:=(period->>'is_transition')::boolean; period_days integer:=last_day-first_day+1; mode text; policy jsonb;
 employee jsonb; employee_manifest jsonb; h jsonb; hid uuid; d date; starts date; ends date; eligible_days integer; denominator numeric;
 compensation jsonb; rate numeric; daily_units jsonb; units numeric; minimum_rate numeric; maximum_rate numeric; basis text;
 base_parts jsonb; unresolved_parts jsonb; base_raw numeric; base_value numeric; parts jsonb; lines jsonb; employees jsonb:='[]'; issues jsonb:='[]'; employee_issues jsonb;
 complete boolean; coverage_gap boolean; assignment_gap boolean; component_head uuid; component jsonb; assignment jsonb; component_data jsonb;
 component_kind text; component_name text; component_value numeric; component_part numeric; component_proration text; matches integer; daily_component_gap boolean; covered_component_days integer; percentage_parts integer; percentage_values integer; percentage_classes integer; component_classes integer; component_methods integer; component_behaviors integer; component_proration_modes integer; full_component_values integer;
 gross numeric; deductions numeric; costs numeric; known_gross numeric:=0; known_deductions numeric:=0; known_costs numeric:=0; known_earning_lines integer:=0; employee_earning_lines integer; all_complete boolean:=true;
 heads record; approved_input jsonb; previous_input jsonb; item jsonb; pack_count integer;
BEGIN
 IF first_day IS NULL OR last_day IS NULL OR period_days NOT BETWEEN 1 AND 366 THEN RAISE EXCEPTION 'payroll_period_invalid' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_manifest->'employees')>5000 THEN RAISE EXCEPTION 'payroll_capacity_review_required' USING ERRCODE='55000'; END IF;
 SELECT i INTO policy FROM jsonb_array_elements(p_manifest->'inputs')i WHERE i->'head'->>'kind'='policy' AND(i->'version'->>'effective_from')::date<=first_day ORDER BY(i->'version'->>'revision')::int DESC LIMIT 1;
 mode:=policy->'version'->'data'->>'mode';
 IF mode IS NULL THEN issues:=issues||jsonb_build_array(payroll.issue('policy_missing',NULL,'payroll_config')); END IF;
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
  employee_issues:='[]';unresolved_parts:='[]';base_parts:='[]';parts:='[]';complete:=mode IS NOT NULL;coverage_gap:=false;assignment_gap:=false;minimum_rate:=NULL;maximum_rate:=NULL;units:=NULL;
  IF mode IS NULL THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('policy_missing',hid,'payroll_config')); END IF;
  FOR d IN SELECT generate_series(starts,ends,interval '1 day')::date LOOP
   SELECT c INTO compensation FROM jsonb_array_elements(employee_manifest->'compensation')c WHERE(c->>'valid_from')::date<=d AND(c->>'valid_until' IS NULL OR(c->>'valid_until')::date>d) LIMIT 1;
   IF compensation IS NULL THEN coverage_gap:=true;ELSE
    rate:=(compensation->>'amount')::numeric;minimum_rate:=least(minimum_rate,rate);maximum_rate:=greatest(maximum_rate,rate);
    denominator:=CASE WHEN transition THEN CASE WHEN mode='fixed_30_day' THEN 30 ELSE extract(day FROM date_trunc('month',d)+interval '1 month - 1 day') END WHEN mode='fixed_30_day' AND eligible_days<period_days THEN greatest(30,eligible_days) ELSE period_days END;
    base_parts:=base_parts||jsonb_build_array(jsonb_build_object('date',d,'rate',rate::text,'denominator',denominator,'compensation_id',compensation->>'id','raw',(rate::numeric(38,20)/denominator)::text));
   END IF;
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employee_manifest->'assignments')w WHERE(w->>'valid_from')::date<=d AND(w->>'valid_until' IS NULL OR(w->>'valid_until')::date>d)) THEN assignment_gap:=true; END IF;
  END LOOP;
  IF coverage_gap THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('compensation_gap',hid,'people')); END IF;
  IF assignment_gap THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('assignment_gap',hid,'people')); END IF;
  IF basis='daily' THEN
   -- Revisions are local to a head. Resolve each head's current version before cancellation/approval checks.
   SELECT count(*),jsonb_agg(i)->0 INTO matches,daily_units FROM(
    SELECT DISTINCT ON(i->'head'->>'id') i FROM jsonb_array_elements(employee_manifest->'inputs')i
    WHERE i->'head'->>'kind'='manual_units' AND(i->'head'->>'employment_id')::uuid=hid AND(i->'head'->>'period_id')::uuid=(period->>'id')::uuid
    ORDER BY i->'head'->>'id',(i->'version'->>'revision')::int DESC
   )current_heads WHERE i->'version'->>'status'<>'cancelled' AND(i->'version'->>'effective_from')::date<=last_day AND(i->'version'->>'effective_until' IS NULL OR(i->'version'->>'effective_until')::date>first_day);
   IF matches>1 THEN complete:=false;daily_units:=NULL;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('manual_units_ambiguous',hid,'payroll_units'));
   ELSIF daily_units IS NULL OR daily_units->'version'->>'status'<>'approved' THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('approved_units_missing',hid,'payroll_units'));
   ELSIF minimum_rate IS DISTINCT FROM maximum_rate THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('daily_units_allocation_needed',hid,'payroll_units'));
   ELSE
    units:=(daily_units->'version'->'data'->>'units')::numeric;
    IF units>eligible_days THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('units_exceed_eligibility',hid,'payroll_units')); END IF;
    SELECT COALESCE(jsonb_agg(b||jsonb_build_object('raw',(minimum_rate*units/eligible_days)::text) ORDER BY b->>'date'),'[]') INTO base_parts FROM jsonb_array_elements(base_parts)b;
   END IF;
  END IF;
  IF mode IS NULL OR basis='daily' AND(coverage_gap OR units IS NULL OR minimum_rate IS DISTINCT FROM maximum_rate) THEN base_parts:='[]'; END IF;
  SELECT COALESCE(sum((b->>'raw')::numeric),0) INTO base_raw FROM jsonb_array_elements(base_parts)b;
  base_value:=CASE WHEN complete THEN round(base_raw,2) ELSE NULL END;
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
    IF matches>1 THEN complete:=false;employee_issues:=employee_issues||jsonb_build_array(payroll.issue('recurring_overlap',hid,'payroll_inputs'));CONTINUE; END IF;
    component_kind:=component_data->>'classification';component_name:=component_data->>'name';component_proration:=COALESCE(component_data->>'proration','salary_proration');
    IF mode IS NULL AND component_data->>'calculation'='fixed' AND component_proration='salary_proration' THEN CONTINUE; END IF;
    IF component_data->>'calculation'='percentage' THEN
     IF jsonb_array_length(base_parts)=0 THEN CONTINUE; END IF;
     IF basis='daily' AND(units IS NULL OR minimum_rate IS DISTINCT FROM maximum_rate) THEN CONTINUE; END IF;
     SELECT(b->>'raw')::numeric INTO component_part FROM jsonb_array_elements(base_parts)b WHERE(b->>'date')::date=d;
     IF component_part IS NULL THEN CONTINUE; END IF;
     component_part:=component_part*component_value/100;
    ELSE
     denominator:=CASE WHEN component_proration='paid_full_period' THEN covered_component_days WHEN transition THEN CASE WHEN mode='fixed_30_day' THEN 30 ELSE extract(day FROM date_trunc('month',d)+interval '1 month - 1 day') END WHEN mode='fixed_30_day' AND eligible_days<period_days THEN greatest(30,eligible_days) ELSE period_days END;
     component_part:=component_value::numeric(38,20)/denominator;
    END IF;
    parts:=parts||jsonb_build_array(jsonb_build_object('component',component_head,'name',component_name,'classification',component_kind,'raw',component_part::text,'date',d,'calculation',component_data->>'calculation','behavior',component_data->>'behavior','proration',component_proration,'denominator',CASE WHEN component_data->>'calculation'='fixed' THEN denominator END,'assignment_value',component_value::text,'component_version',component->'version'->>'id'));
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
   IF basis='daily' THEN
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
   parts:=parts||jsonb_build_array(jsonb_build_object('component','adjustment:'||heads.id,'name',component_data->>'name','classification',component_data->>'classification','raw',approved_input->'version'->'data'->>'amount','reason',approved_input->'version'->'data'->>'reason','input_version',approved_input->'version'->>'id'));
  END LOOP;
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.component,x.classification),'[]') INTO lines FROM(SELECT part->>'component' AS component,max(part->>'name') AS name,part->>'classification' AS classification,round(sum((part->>'raw')::numeric),2)::text AS amount,jsonb_agg(part ORDER BY part->>'date',part->>'component_version') AS details FROM jsonb_array_elements(parts)part GROUP BY part->>'component',part->>'classification')x;
  SELECT COALESCE(sum((l->>'amount')::numeric) FILTER(WHERE l->>'classification'='earning'),0),COALESCE(sum((l->>'amount')::numeric) FILTER(WHERE l->>'classification'='deduction'),0),COALESCE(sum((l->>'amount')::numeric) FILTER(WHERE l->>'classification'='employer_cost'),0) INTO gross,deductions,costs FROM jsonb_array_elements(lines)l;
  IF complete AND deductions>gross THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('negative_operational_balance',hid,'payroll_finance')); END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(employee_manifest->'inputs')i WHERE i->'head'->>'kind'='opening_ytd' AND((i->'head'->>'employment_id')::uuid=hid OR i->'head'->>'employee_id'=h->>'employee_id')) THEN employee_issues:=employee_issues||jsonb_build_array(payroll.issue('opening_ytd_unknown',hid,'payroll_ytd')); END IF;
  SELECT count(*) INTO employee_earning_lines FROM jsonb_array_elements(lines)l WHERE l->>'classification'='earning';known_earning_lines:=known_earning_lines+employee_earning_lines;
  known_gross:=known_gross+gross;known_deductions:=known_deductions+deductions;known_costs:=known_costs+costs;all_complete:=all_complete AND complete;
  employees:=employees||jsonb_build_array(jsonb_build_object('employment_id',hid,'employee_id',h->>'employee_id','name',employee->>'name','code',employee->>'code','pay_basis',basis,'starts_on',starts,'ends_on',ends,'eligible_days',eligible_days,'approved_units',units::text,'base',base_value::text,'gross',CASE WHEN complete THEN gross::text END,'known_gross',CASE WHEN employee_earning_lines>0 THEN gross::text END,'deductions',deductions::text,'employer_cost',costs::text,'net',NULL,'gross_complete',complete,'lines',lines,'unresolved_parts',unresolved_parts,'dated_rates',COALESCE((SELECT jsonb_agg(jsonb_build_object('from',c->>'valid_from','until',c->>'valid_until','rate',c->>'amount') ORDER BY c->>'valid_from') FROM jsonb_array_elements(employee_manifest->'compensation')c),'[]'),'issues',employee_issues));
  issues:=issues||employee_issues;
 END LOOP;
 RETURN jsonb_build_object('engine','cube4-review-v1','employees',employees,'employee_count',jsonb_array_length(employees),'issues',issues,'gross',CASE WHEN all_complete THEN known_gross::text END,'known_gross',CASE WHEN known_earning_lines>0 THEN known_gross::text END,'deductions',known_deductions::text,'employer_cost',known_costs::text,'net',NULL,'statutory_deductions',NULL,'statutory_contributions',NULL,'gross_complete',all_complete,'financially_qualified',false,'policy',mode,'is_transition',transition);
END $f$;
CREATE FUNCTION payroll.manifest_kind(p_manifest jsonb,p_kind text) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT COALESCE(jsonb_agg(i ORDER BY i->'head'->>'id',(i->'version'->>'revision')::int),'[]') FROM jsonb_array_elements(p_manifest->'inputs')i WHERE i->'head'->>'kind'=p_kind
$f$;
CREATE FUNCTION payroll.stale_reasons(p_old jsonb,p_current jsonb) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE reasons jsonb:='[]';kind text;key text;BEGIN
 FOREACH key IN ARRAY ARRAY['period','employees','compensation','assignments','packs','optional','corrections'] LOOP
  IF p_old->key IS DISTINCT FROM p_current->key THEN reasons:=reasons||jsonb_build_array(key||'_changed'); END IF;
 END LOOP;
 FOREACH kind IN ARRAY ARRAY['policy','component','recurring','manual_units','adjustment','opening_ytd'] LOOP
  IF payroll.manifest_kind(p_old,kind) IS DISTINCT FROM payroll.manifest_kind(p_current,kind) THEN reasons:=reasons||jsonb_build_array(kind||'_changed'); END IF;
 END LOOP;
 RETURN reasons;
END $f$;
CREATE FUNCTION public.payroll_run_access(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid();can_view boolean;BEGIN
 can_view:=a IS NOT NULL AND(platform_private.has_tenant_permission(p_tenant,a,'payroll.view') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.prepare') OR platform_private.has_tenant_permission(p_tenant,a,'payroll.review'));
 IF NOT can_view THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('can_view',can_view,'can_prepare',platform_private.has_tenant_permission(p_tenant,a,'payroll.prepare'),'can_review',platform_private.has_tenant_permission(p_tenant,a,'payroll.review'),'can_configure',platform_private.has_tenant_permission(p_tenant,a,'payroll_config.manage'),'can_compensation_fix',platform_private.has_people_permission(p_tenant,a,'people.view') AND platform_private.has_people_permission(p_tenant,a,'compensation.manage'),'can_assignment_fix',platform_private.has_people_permission(p_tenant,a,'people.view') AND platform_private.has_people_permission(p_tenant,a,'org_context.manage'),'enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.payroll',clock_timestamp()));
END $f$;
CREATE FUNCTION public.payroll_run_command(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_expected integer,p_operation text,p_reason text,p_attempt uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid;run payroll.runs%ROWTYPE;bounds payroll.periods%ROWTYPE;intent jsonb;receipt payroll.command_receipts%ROWTYPE;manifest jsonb;output jsonb;candidate uuid;result jsonb;BEGIN
 IF p_operation IS NULL OR p_operation NOT IN('calculate','cancel') OR p_expected IS NULL OR p_expected<0 OR p_attempt IS NULL OR p_period IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 PERFORM payroll.authorized(p_tenant,'payroll.prepare',true);
 PERFORM payroll.lock_run_scope(p_tenant,p_employer,p_period);
 a:=payroll.authorized(p_tenant,'payroll.prepare',true);
 SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 intent:=jsonb_build_object('operation','run_'||p_operation,'employer',p_employer,'period',p_period,'run',p_run,'expected',p_expected,'reason',COALESCE(btrim(p_reason),''));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 IF p_run IS NULL THEN
  IF p_expected<>0 OR p_operation<>'calculate' THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND status IN('draft','review')) THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409'; END IF;
  INSERT INTO payroll.runs(tenant_id,employer_id,period_id,status,created_by) VALUES(p_tenant,p_employer,p_period,'draft',a) RETURNING * INTO run;
 ELSE
  SELECT * INTO run FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
  IF run.revision<>p_expected OR run.status='cancelled' THEN RAISE EXCEPTION 'payroll_run_stale' USING ERRCODE='PT409'; END IF;
 END IF;
 IF p_operation='cancel' THEN
  IF length(COALESCE(btrim(p_reason),'')) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
  UPDATE payroll.runs SET status='cancelled',revision=revision+1,cancelled_by=a,cancelled_at=clock_timestamp(),cancel_reason=btrim(p_reason) WHERE tenant_id=p_tenant AND id=run.id;
  result:=jsonb_build_object('id',run.id,'revision',run.revision+1,'status','cancelled');
 ELSE
  manifest:=payroll.run_manifest(p_tenant,p_employer,p_period);
  output:=payroll.build_review(manifest);
  -- A source writer may commit while a candidate-only reader works. Recheck complete discovery before success.
  IF manifest IS DISTINCT FROM payroll.run_manifest(p_tenant,p_employer,p_period) THEN RAISE EXCEPTION 'payroll_source_stale' USING ERRCODE='PT409'; END IF;
  INSERT INTO payroll.candidates(tenant_id,employer_id,run_id,revision,engine_version,input_manifest,output,created_by) VALUES(p_tenant,p_employer,run.id,run.revision+1,'cube4-review-v1',manifest,output,a) RETURNING id INTO candidate;
  UPDATE payroll.runs SET status='review',revision=revision+1,candidate_id=candidate WHERE tenant_id=p_tenant AND id=run.id;
  result:=jsonb_build_object('id',run.id,'revision',run.revision+1,'candidate_id',candidate,'status','review','issue_count',jsonb_array_length(output->'issues'));
 END IF;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'run_'||p_operation,intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'payroll.prepare',true);
 RETURN result;
END $f$;
-- Public detail explains contiguous unchanged segments; exact arithmetic stays private.
CREATE FUNCTION payroll.review_segments(p_parts jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 WITH source AS(SELECT p,(p->>'date')::date AS d,p-'date'-'raw'-'component_version'-'compensation_id' AS shape FROM jsonb_array_elements(COALESCE(p_parts,'[]'))p WHERE p->>'date' IS NOT NULL),
 islands AS(SELECT *,d-(row_number() OVER(PARTITION BY shape ORDER BY d))::integer AS island FROM source),
 grouped AS(SELECT min(d) AS first_day,max(d) AS last_day,count(*) AS days,shape FROM islands GROUP BY shape,island)
 SELECT COALESCE(jsonb_agg(shape||jsonb_build_object('from',first_day,'until',last_day,'days',days) ORDER BY first_day),'[]') FROM grouped
$f$;
CREATE FUNCTION payroll.review_employee_detail(p_employee jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT p_employee-'unresolved_parts'-'lines'||jsonb_build_object(
 'unresolved_segments',payroll.review_segments(p_employee->'unresolved_parts'),
 'lines',COALESCE((SELECT jsonb_agg(l-'details'||jsonb_build_object('segments',CASE
 WHEN l->>'component'='base' AND p_employee->>'pay_basis'='daily' THEN jsonb_build_array(jsonb_build_object('from',p_employee->>'starts_on','until',p_employee->>'ends_on','units',p_employee->>'approved_units','rate',l->'details'->0->'detail'->0->>'rate'))
 WHEN l->>'component'='base' THEN payroll.review_segments(l->'details'->0->'detail')
 WHEN l->>'component' LIKE 'adjustment:%' THEN jsonb_build_array(jsonb_build_object('reason',l->'details'->0->>'reason','approved_amount',l->>'amount'))
 ELSE payroll.review_segments(l->'details') END)) FROM jsonb_array_elements(p_employee->'lines')l),'[]'))
$f$;
CREATE FUNCTION public.payroll_run_workspace(p_tenant uuid,p_employer uuid,p_period uuid,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 30,p_employee uuid DEFAULT NULL,p_query text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE access jsonb;run payroll.runs%ROWTYPE;candidate payroll.candidates%ROWTYPE;bounds payroll.periods%ROWTYPE;stale jsonb:='[]';items jsonb;detail jsonb;previous payroll.candidates%ROWTYPE;variance jsonb:='null';summary jsonb;BEGIN
 access:=public.payroll_run_access(p_tenant);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_query IS NULL OR length(p_query)>120 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO bounds FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 SELECT * INTO run FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period ORDER BY(status<>'cancelled') DESC,created_at DESC,id DESC LIMIT 1;
 IF run.candidate_id IS NOT NULL THEN
  SELECT * INTO candidate FROM payroll.candidates WHERE tenant_id=p_tenant AND id=run.candidate_id;
  IF run.status<>'cancelled' THEN stale:=payroll.stale_reasons(candidate.input_manifest,payroll.run_manifest(p_tenant,p_employer,p_period)); END IF;
  SELECT COALESCE(jsonb_agg(e-'lines'-'unresolved_parts'-'dated_rates' ORDER BY e->>'employment_id'),'[]') INTO items FROM(SELECT e FROM jsonb_array_elements(candidate.output->'employees')e WHERE(p_after IS NULL OR(e->>'employment_id')::uuid>p_after) AND(e->>'name' ILIKE '%'||p_query||'%' OR e->>'code' ILIKE '%'||p_query||'%') ORDER BY(e->>'employment_id')::uuid LIMIT p_limit)x;
  IF p_employee IS NOT NULL THEN SELECT e INTO detail FROM jsonb_array_elements(candidate.output->'employees')e WHERE(e->>'employment_id')::uuid=p_employee;IF detail IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF; END IF;
  -- Comparison is draft-to-draft evidence only; absent or unequal ordinary/transition periods remain unavailable.
  SELECT c.* INTO previous FROM payroll.candidates c JOIN payroll.runs r ON r.tenant_id=c.tenant_id AND r.id=c.run_id AND r.candidate_id=c.id JOIN payroll.periods p ON p.tenant_id=r.tenant_id AND p.id=r.period_id WHERE r.tenant_id=p_tenant AND r.employer_id=p_employer AND r.status='review' AND p.ends_on<bounds.starts_on AND p.ends_on-p.starts_on=bounds.ends_on-bounds.starts_on AND p.is_transition=bounds.is_transition ORDER BY p.ends_on DESC LIMIT 1;
  IF previous.id IS NOT NULL THEN
   IF payroll.stale_reasons(previous.input_manifest,payroll.run_manifest(p_tenant,p_employer,(previous.input_manifest->'period'->>'id')::uuid))='[]'::jsonb AND(previous.output->>'gross_complete')::boolean AND(candidate.output->>'gross_complete')::boolean THEN
    variance:=jsonb_build_object('reference','review_candidate','previous_gross',previous.output->'gross','difference',((candidate.output->>'gross')::numeric-(previous.output->>'gross')::numeric)::text,'previous_period',previous.input_manifest->'period'->>'label', 'changed_employee_count',(SELECT count(*) FROM jsonb_array_elements(candidate.output->'employees')e LEFT JOIN LATERAL(SELECT prior AS old FROM jsonb_array_elements(previous.output->'employees')prior WHERE prior->'employment_id'=e->'employment_id')p ON true WHERE old IS NULL OR(e->>'gross')::numeric IS DISTINCT FROM(old->>'gross')::numeric));
   END IF;
  END IF;
  IF variance<>'null'::jsonb THEN
   SELECT COALESCE(jsonb_agg(e||jsonb_build_object('new_employee',old IS NULL,'gross_difference',CASE WHEN old IS NULL THEN NULL ELSE((e->>'gross')::numeric-(old->>'gross')::numeric)::text END) ORDER BY e->>'employment_id'),'[]') INTO items FROM jsonb_array_elements(items)e LEFT JOIN LATERAL(SELECT prior AS old FROM jsonb_array_elements(previous.output->'employees')prior WHERE prior->'employment_id'=e->'employment_id')p ON true;
  END IF;
  summary:=candidate.output-'employees'-'issues';
 END IF;
 RETURN jsonb_build_object('access',access,'period',jsonb_build_object('id',bounds.id,'starts_on',bounds.starts_on,'ends_on',bounds.ends_on,'is_transition',bounds.is_transition),'run',CASE WHEN run.id IS NULL THEN NULL ELSE jsonb_build_object('id',run.id,'revision',run.revision,'status',run.status,'created_at',run.created_at,'cancel_reason',run.cancel_reason) END,'summary',summary,'employees',COALESCE(items,'[]'),'detail',CASE WHEN detail IS NOT NULL THEN payroll.review_employee_detail(detail) END,'stale_reasons',stale,'variance',variance,'global_issues',COALESCE((SELECT jsonb_agg(i) FROM jsonb_array_elements(candidate.output->'issues')i WHERE i->>'employment_id' IS NULL),'[]'),'issue_count',COALESCE(jsonb_array_length(candidate.output->'issues'),0),'history',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM(SELECT r.status,r.created_at,r.cancel_reason,c.revision,c.created_at AS calculated_at FROM payroll.runs r LEFT JOIN payroll.candidates c ON c.tenant_id=r.tenant_id AND c.run_id=r.id WHERE r.tenant_id=p_tenant AND r.employer_id=p_employer AND r.period_id=p_period ORDER BY r.created_at DESC,c.revision DESC LIMIT 24)x),'[]'));
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_run_access(uuid),public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid),public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_run_access(uuid),public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid),public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text) TO authenticated;
-- Append reviewer; retain all previous bundle snapshots.
DO $f$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('platform_private.people_role_bundle_catalog()'::regprocedure);
 IF definition NOT LIKE '%payroll.correction.requester.v1%' OR definition LIKE '%payroll.reviewer.v1%' THEN RAISE EXCEPTION 'unexpected_role_catalog'; END IF;
 definition:=replace(definition,'''payroll.correction.requester.v1''::text,ARRAY[''payroll.view'',''payroll.correct'']::text[])','''payroll.correction.requester.v1''::text,ARRAY[''payroll.view'',''payroll.correct'']::text[]),
 (''payroll.reviewer.v1''::text,ARRAY[''payroll.view'',''payroll.review'']::text[])');EXECUTE definition;
 definition:=pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure);
 IF definition NOT LIKE '%cardinality(p_bundle_keys) > 22%' THEN RAISE EXCEPTION 'unexpected_role_bundle_limit'; END IF;
 EXECUTE replace(definition,'cardinality(p_bundle_keys) > 22','cardinality(p_bundle_keys) > 23');
END $f$;
-- Reuse narrow Employer/period discovery with run-view authority, including a review-only principal.
DO $f$ DECLARE definition text;BEGIN
 definition:=pg_get_functiondef('public.payroll_input_employers(uuid,text,text,uuid)'::regprocedure);
 definition:=replace(definition,'public.payroll_input_employers','public.payroll_run_employers');definition:=replace(definition,'public.payroll_input_access','public.payroll_run_access');EXECUTE definition;
 definition:=pg_get_functiondef('public.payroll_input_periods(uuid,uuid,date)'::regprocedure);
 definition:=replace(definition,'public.payroll_input_periods','public.payroll_run_periods');definition:=replace(definition,'public.payroll_input_access','public.payroll_run_access');EXECUTE definition;
END $f$;
REVOKE ALL ON FUNCTION public.payroll_run_employers(uuid,text,text,uuid),public.payroll_run_periods(uuid,uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_run_employers(uuid,text,text,uuid),public.payroll_run_periods(uuid,uuid,date) TO authenticated;
