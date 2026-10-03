-- Reuse one arithmetic implementation for verified packs and draft comparison.
-- Public payroll consumers still enter through the unchanged verification gate.
DO $f$ DECLARE name text;definition text;start_at integer;end_at integer;signature text;BEGIN
 FOREACH name IN ARRAY ARRAY['calculate_cumulative_tax','calculate_insurance'] LOOP
  definition:=pg_get_functiondef(format('payroll.%I(uuid,jsonb)',name)::regprocedure);
  signature:=format('FUNCTION payroll.%I(p_pack uuid, p_context jsonb)',name);
  IF strpos(definition,signature)=0 THEN RAISE EXCEPTION 'unexpected_comparison_adapter_signature';END IF;
  definition:=replace(definition,signature,format('FUNCTION payroll.%I(pack payroll.statutory_packs, p_context jsonb)',name||'_data'));
  definition:=replace(definition,'pack payroll.statutory_packs;','');
  start_at:=strpos(definition,' SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;');
  end_at:=strpos(definition,' rules:=pack.');
  IF start_at=0 OR end_at<=start_at THEN RAISE EXCEPTION 'unexpected_comparison_adapter_gate';END IF;
  definition:=substring(definition,1,start_at-1)||substring(definition,end_at);EXECUTE definition;
  EXECUTE format($sql$CREATE OR REPLACE FUNCTION payroll.%I(p_pack uuid,p_context jsonb) RETURNS jsonb
   LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $body$
   DECLARE pack payroll.statutory_packs;BEGIN
    SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
    IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
     OR jsonb_typeof(pack.review_evidence->'numeric_comparisons') IS DISTINCT FROM 'array'
     OR jsonb_array_length(pack.review_evidence->'numeric_comparisons')=0 THEN
     RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';END IF;
    RETURN payroll.%I(pack,p_context);
   END $body$$sql$,name,name||'_data');
 END LOOP;
END $f$;
REVOKE ALL ON FUNCTION payroll.calculate_cumulative_tax_data(payroll.statutory_packs,jsonb),payroll.calculate_insurance_data(payroll.statutory_packs,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION payroll.statutory_draft_pack(p_version payroll.statutory_draft_versions,p_label text)
RETURNS payroll.statutory_packs LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE r jsonb:=p_version.numeric_rules;t jsonb;c jsonb;b jsonb;x jsonb;columns jsonb:='[]';bands jsonb;branches jsonb:='[]';pack payroll.statutory_packs;
BEGIN
 IF r IS NULL THEN RAISE EXCEPTION 'statutory_comparison_rules_missing' USING ERRCODE='22023';END IF;
 PERFORM payroll.validate_statutory_draft_rules(r);t:=r->'tax';
 FOR c IN SELECT value FROM jsonb_array_elements(t->'columns') LOOP
  bands:='[]';FOR b IN SELECT value FROM jsonb_array_elements(c->'bands') LOOP
   bands:=bands||jsonb_build_array(jsonb_build_object('upper',nullif(b->>'upper','')::numeric,'rate',(b->>'rate')::numeric/100));END LOOP;
  columns:=columns||jsonb_build_array(jsonb_build_object('through',nullif(c->>'through','')::numeric,'bands',bands));
 END LOOP;
 FOR x IN SELECT value FROM jsonb_array_elements(r->'insurance'->'branches') LOOP
  branches:=branches||jsonb_build_array(jsonb_build_object('branch',x->'branch','employee_rate',(x->>'employee')::numeric/100,'employer_rate',(x->>'employer')::numeric/100,'tax_deductible',x->'deductible'));
 END LOOP;
 pack.version:=p_label;pack.effective_from:=p_version.effective_from;pack.effective_until:=p_version.effective_until;pack.state:='unqualified';pack.engine_adapter:='eg-cumulative-tax-v1';
 pack.rules:=jsonb_build_object('schema','eg-cumulative-tax-v1','tax_treatment_code',t->'treatment','day_basis',360,'personal_exemption',(t->>'exemption')::numeric,'base_rounding','floor10','column_basis',t->'column_basis','tax_rounding','cumulative_half_up_cent','columns',columns);
 pack.insurance_rules:=jsonb_build_object('schema','eg-insurance-month-v1','category',r->'insurance'->'category','wage_minimum',(r->'insurance'->>'minimum')::numeric,'wage_maximum',(r->'insurance'->>'maximum')::numeric,'rounding','each_branch_month_half_up_cent','branches',branches);
 RETURN pack;
END $f$;

CREATE FUNCTION payroll.statutory_draft_compare(p_version payroll.statutory_draft_versions,p_label text,p_case jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE pack payroll.statutory_packs;tax jsonb;insurance jsonb;t jsonb;expected jsonb;actual jsonb;months jsonb:='[]';m jsonb;key text;matched boolean;first_date date;last_date date;
BEGIN
 IF octet_length(p_case::text)>16384 OR jsonb_typeof(p_case) IS DISTINCT FROM 'object' OR NOT(p_case ?& ARRAY['name','scenario','origin','source_url','reference','tax','insurance','expected']) OR(SELECT count(*) FROM jsonb_object_keys(p_case))<>8
  OR jsonb_typeof(p_case->'name') IS DISTINCT FROM 'string' OR length(btrim(p_case->>'name')) NOT BETWEEN 3 AND 160
  OR coalesce(p_case->>'scenario','') NOT IN('low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding')
  OR coalesce(p_case->>'origin','') NOT IN('synthetic','official') OR jsonb_typeof(p_case->'reference') IS DISTINCT FROM 'string' OR length(btrim(p_case->>'reference')) NOT BETWEEN 3 AND 160
  OR jsonb_typeof(p_case->'source_url') IS DISTINCT FROM 'string'
  OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_version.source_references)s WHERE s->>'url'=p_case->>'source_url') THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 t:=p_case->'tax';expected:=p_case->'expected';
 IF jsonb_typeof(t) IS DISTINCT FROM 'object' OR NOT(t ?& ARRAY['net','duration','prior_due','from','until']) OR(SELECT count(*) FROM jsonb_object_keys(t))<>5
  OR jsonb_typeof(p_case->'insurance') IS DISTINCT FROM 'array' OR jsonb_array_length(p_case->'insurance')>12
  OR jsonb_typeof(expected) IS DISTINCT FROM 'object' OR NOT(expected ?& ARRAY['tax_due','tax_delta','employee_insurance','employer_insurance','deductible_insurance']) OR(SELECT count(*) FROM jsonb_object_keys(expected))<>5 THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 FOREACH key IN ARRAY ARRAY['net','duration','prior_due'] LOOP
  IF jsonb_typeof(t->key) IS DISTINCT FROM 'string' OR(t->>key) !~ '^(0|[1-9][0-9]{0,11})(\.[0-9]{1,2})?$' THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 FOREACH key IN ARRAY ARRAY['tax_due','tax_delta','employee_insurance','employer_insurance','deductible_insurance'] LOOP
  IF jsonb_typeof(expected->key) IS DISTINCT FROM 'string' OR(expected->>key) !~ '^-?(0|[1-9][0-9]{0,11})(\.[0-9]{1,2})?$'
   OR(key<>'tax_delta' AND(expected->>key)::numeric<0) THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 FOREACH key IN ARRAY ARRAY['from','until'] LOOP
  IF jsonb_typeof(t->key) IS DISTINCT FROM 'string' OR(t->>key) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 first_date:=(t->>'from')::date;last_date:=(t->>'until')::date;pack:=payroll.statutory_draft_pack(p_version,p_label);
 FOR m IN SELECT value FROM jsonb_array_elements(p_case->'insurance') LOOP
  IF jsonb_typeof(m) IS DISTINCT FROM 'object' OR NOT(m ?& ARRAY['month','wage','reference']) OR(SELECT count(*) FROM jsonb_object_keys(m))<>3
   OR jsonb_typeof(m->'month') IS DISTINCT FROM 'string' OR(m->>'month') !~ '^[0-9]{4}-[0-9]{2}-01$'
   OR jsonb_typeof(m->'wage') IS DISTINCT FROM 'string' OR(m->>'wage') !~ '^(0|[1-9][0-9]{0,11})(\.[0-9]{1,2})?$'
   OR jsonb_typeof(m->'reference') IS DISTINCT FROM 'string' OR length(btrim(m->>'reference')) NOT BETWEEN 3 AND 160
   OR extract(year FROM(m->>'month')::date)<>extract(year FROM first_date) THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
  months:=months||jsonb_build_array(jsonb_build_object('month',m->>'month','insured_wage',(m->>'wage')::numeric,'insured_wage_source',m->>'reference'));
 END LOOP;
 tax:=payroll.calculate_cumulative_tax_data(pack,jsonb_build_object('cumulative_net_before_personal_exemption',(t->>'net')::numeric,'cumulative_duration_days',(t->>'duration')::numeric,'prior_tax_due',(t->>'prior_due')::numeric,'earning_from',first_date,'earning_until',last_date,'tax_treatment_code',pack.rules->'tax_treatment_code','source_reference',p_case->'reference'));
 insurance:=payroll.calculate_insurance_data(pack,jsonb_build_object('category',pack.insurance_rules->'category','source_reference',p_case->'reference','obligation_months',months));
 actual:=jsonb_build_object('tax_due',tax->'cumulative_tax_due','tax_delta',tax->'current_tax_delta','employee_insurance',insurance->'employee_total','employer_insurance',insurance->'employer_total','deductible_insurance',insurance->'tax_deductible_employee_total');matched:=true;
 FOR key IN SELECT jsonb_object_keys(actual) LOOP IF(actual->>key)::numeric<>(expected->>key)::numeric THEN matched:=false;END IF;END LOOP;
 RETURN jsonb_build_object('actual',actual,'expected',expected,'matched',matched,'tax',tax,'insurance',insurance,'qualified',false);
 EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';
END $f$;
REVOKE ALL ON FUNCTION payroll.statutory_draft_pack(payroll.statutory_draft_versions,text),payroll.statutory_draft_compare(payroll.statutory_draft_versions,text,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE payroll.statutory_draft_comparisons(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,head_id uuid NOT NULL,revision integer NOT NULL,
 case_data jsonb NOT NULL,result jsonb NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 FOREIGN KEY(head_id,revision) REFERENCES payroll.statutory_draft_versions(head_id,revision));
CREATE INDEX statutory_draft_comparison_history ON payroll.statutory_draft_comparisons(head_id,id DESC);
ALTER TABLE payroll.statutory_draft_comparisons ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.statutory_draft_comparisons FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER statutory_draft_comparisons_immutable BEFORE UPDATE OR DELETE ON payroll.statutory_draft_comparisons FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
CREATE FUNCTION public.statutory_draft_compare(p_head uuid,p_expected integer,p_attempt uuid,p_case jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;head payroll.statutory_draft_heads;version payroll.statutory_draft_versions;receipt payroll.statutory_draft_receipts;intent jsonb;result jsonb;row_id bigint;
BEGIN
 actor:=payroll.statutory_draft_actor();IF p_head IS NULL OR p_expected IS NULL OR p_expected<1 OR p_attempt IS NULL OR p_case IS NULL THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 intent:=jsonb_build_object('operation','compare','head',p_head,'revision',p_expected,'case',p_case);
 PERFORM pg_advisory_xact_lock(772412,115991);PERFORM 1 FROM auth.users WHERE id=actor FOR SHARE;PERFORM 1 FROM platform_private.platform_operator_grants WHERE user_id=actor FOR SHARE;actor:=payroll.statutory_draft_actor();
 SELECT * INTO receipt FROM payroll.statutory_draft_receipts WHERE actor_id=actor AND attempt=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'statutory_draft_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=p_head FOR UPDATE;
 IF NOT FOUND OR head.revision<>p_expected THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO version FROM payroll.statutory_draft_versions WHERE head_id=p_head AND revision=p_expected;
 result:=payroll.statutory_draft_compare(version,head.version,p_case);
 INSERT INTO payroll.statutory_draft_comparisons(head_id,revision,case_data,result,actor_id) VALUES(p_head,p_expected,p_case,result,actor) RETURNING id INTO row_id;
 result:=jsonb_build_object('id',row_id,'revision',p_expected,'matched',result->'matched','qualified',false);
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);RETURN result;
END $f$;
CREATE FUNCTION public.statutory_draft_comparison_history(p_head uuid,p_before bigint DEFAULT NULL,p_limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE rows jsonb;more boolean;current_revision integer;BEGIN
 PERFORM payroll.statutory_draft_actor();IF p_head IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 OR(p_before IS NOT NULL AND p_before<1) THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 SELECT revision INTO current_revision FROM payroll.statutory_draft_heads WHERE id=p_head;IF NOT FOUND THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY id DESC),'[]') INTO rows FROM(SELECT * FROM payroll.statutory_draft_comparisons WHERE head_id=p_head AND(p_before IS NULL OR id<p_before) ORDER BY id DESC LIMIT p_limit+1)c;
 more:=jsonb_array_length(rows)>p_limit;IF more THEN rows:=rows-p_limit;END IF;
 RETURN jsonb_build_object('rows',rows,'current_revision',current_revision,'next',CASE WHEN more THEN(rows->(jsonb_array_length(rows)-1)->>'id')::bigint END,'qualified',false);
END $f$;
REVOKE ALL ON FUNCTION public.statutory_draft_compare(uuid,integer,uuid,jsonb),public.statutory_draft_comparison_history(uuid,bigint,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.statutory_draft_compare(uuid,integer,uuid,jsonb),public.statutory_draft_comparison_history(uuid,bigint,integer) TO authenticated;
