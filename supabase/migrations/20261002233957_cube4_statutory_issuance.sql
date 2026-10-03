-- Release only the reviewed tax/insurance adapter scope. This is not a labour
-- rules qualification or permission to expose the public financial lock.
CREATE TABLE payroll.statutory_draft_issuances(
 head_id uuid NOT NULL,revision integer NOT NULL,pack_id uuid NOT NULL UNIQUE REFERENCES payroll.statutory_packs(id),
 evidence_stamp text NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),reason text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),PRIMARY KEY(head_id,revision),
 FOREIGN KEY(head_id,revision) REFERENCES payroll.statutory_draft_versions(head_id,revision));
ALTER TABLE payroll.statutory_draft_issuances ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.statutory_draft_issuances FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER statutory_draft_issuances_immutable BEFORE UPDATE OR DELETE ON payroll.statutory_draft_issuances FOR EACH ROW EXECUTE FUNCTION payroll.immutable();

-- Correcting the expected result is append-only: the latest official record
-- with the same name/scenario/year represents that case; old results remain.
CREATE FUNCTION payroll.statutory_current_comparisons(p_head uuid,p_revision integer)
RETURNS SETOF payroll.statutory_draft_comparisons LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT DISTINCT ON(btrim(case_data->>'name'),case_data->>'scenario',left(case_data->'tax'->>'from',4)) c.*
 FROM payroll.statutory_draft_comparisons c WHERE head_id=p_head AND revision=p_revision AND case_data->>'origin'='official'
 ORDER BY btrim(case_data->>'name'),case_data->>'scenario',left(case_data->'tax'->>'from',4),id DESC
$f$;
REVOKE ALL ON FUNCTION payroll.statutory_current_comparisons(uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

-- An issued revision and its reviewed evidence are frozen together. Original
-- receipt recovery still happens before this check. New review needs a revision.
DO $f$ DECLARE definition text;needle text:=' result:=payroll.statutory_draft_compare(version,head.version,p_case);';BEGIN
 definition:=pg_get_functiondef('public.statutory_draft_compare(uuid,integer,uuid,jsonb)'::regprocedure);
 IF strpos(definition,needle)=0 THEN RAISE EXCEPTION 'unexpected_comparison_issuance_guard';END IF;
 definition:=replace(definition,needle,' IF EXISTS(SELECT 1 FROM payroll.statutory_draft_issuances WHERE head_id=p_head AND revision=p_expected) THEN RAISE EXCEPTION ''statutory_revision_issued'' USING ERRCODE=''PT409'';END IF;'||needle);
 EXECUTE definition;
END $f$;

CREATE FUNCTION payroll.statutory_issuance_readiness(p_head uuid,p_expected integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
DECLARE h payroll.statutory_draft_heads;v payroll.statutory_draft_versions;stamp text;blockers jsonb:='[]';
 coverage jsonb:='[]';selected_ids jsonb:='[]';case_id bigint;year_number integer;scenario text;total integer;official integer;issued uuid;preview payroll.statutory_packs;
BEGIN
 SELECT * INTO h FROM payroll.statutory_draft_heads WHERE id=p_head;
 IF NOT FOUND OR h.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO v FROM payroll.statutory_draft_versions WHERE head_id=p_head AND revision=p_expected;
 SELECT count(*),count(*) FILTER(WHERE case_data->>'origin'='official'),
  md5(coalesce(string_agg(md5(to_jsonb(c)::text),'' ORDER BY id),'')) INTO total,official,stamp
 FROM payroll.statutory_draft_comparisons c WHERE head_id=p_head AND revision=p_expected;
 stamp:=md5(to_jsonb(v)::text||stamp);
 SELECT pack_id INTO issued FROM payroll.statutory_draft_issuances WHERE head_id=p_head AND revision=p_expected;
 IF v.numeric_rules IS NULL THEN blockers:=blockers||'"numeric_rules_missing"'::jsonb;END IF;
 IF v.effective_until IS NULL THEN blockers:=blockers||'"review_end_missing"'::jsonb;END IF;
 IF EXISTS(SELECT 1 FROM payroll.statutory_current_comparisons(p_head,p_expected) WHERE(result->>'matched' IS DISTINCT FROM 'true'
   OR case_data->>'source_url' !~ '^https://([a-zA-Z0-9-]+\.)*(eta|nosi)\.gov\.eg(/|$)')) THEN
  blockers:=blockers||'"official_result_unresolved"'::jsonb;
 END IF;
 IF v.numeric_rules IS NOT NULL AND v.effective_until IS NOT NULL THEN
  FOR year_number IN SELECT generate_series(extract(year FROM v.effective_from)::integer,extract(year FROM(v.effective_until-1))::integer) LOOP
   FOREACH scenario IN ARRAY ARRAY['low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding'] LOOP
    SELECT id INTO case_id FROM payroll.statutory_current_comparisons(p_head,p_expected) c
    WHERE c.result->>'matched'='true'
     AND c.case_data->>'scenario'=scenario AND extract(year FROM(c.case_data->'tax'->>'from')::date)=year_number
     AND c.case_data->>'source_url' ~ '^https://([a-zA-Z0-9-]+\.)*(eta|nosi)\.gov\.eg(/|$)'
     AND (scenario<>'insurance_min' OR EXISTS(SELECT 1 FROM jsonb_array_elements(c.case_data->'insurance')m WHERE(m->>'wage')::numeric=(v.numeric_rules->'insurance'->>'minimum')::numeric))
     AND (scenario<>'insurance_max' OR EXISTS(SELECT 1 FROM jsonb_array_elements(c.case_data->'insurance')m WHERE(m->>'wage')::numeric=(v.numeric_rules->'insurance'->>'maximum')::numeric))
     AND (scenario<>'mid_year' OR(c.case_data->'tax'->>'from')::date>make_date(year_number,1,1))
     AND (scenario<>'cumulative' OR(c.case_data->'tax'->>'prior_due')::numeric>0)
     AND (scenario<>'correction' OR(c.case_data->'tax'->>'prior_due')::numeric>0)
    ORDER BY id DESC LIMIT 1;
    IF case_id IS NULL THEN coverage:=coverage||jsonb_build_array(jsonb_build_object('year',year_number,'scenario',scenario));
    ELSE selected_ids:=selected_ids||to_jsonb(case_id);END IF;
   END LOOP;
  END LOOP;
 END IF;
 IF jsonb_array_length(coverage)>0 THEN blockers:=blockers||'"official_coverage_missing"'::jsonb;END IF;
 IF v.numeric_rules IS NOT NULL THEN preview:=payroll.statutory_draft_pack(v,h.version);END IF;
 IF issued IS NULL AND v.numeric_rules IS NOT NULL AND EXISTS(SELECT 1 FROM payroll.statutory_packs p WHERE p.state='verified'
  AND p.engine_adapter='eg-cumulative-tax-v1' AND p.effective_from<coalesce(v.effective_until,date '2201-01-01')
  AND coalesce(p.effective_until,date '2201-01-01')>v.effective_from
  AND(
   p.rules->>'tax_treatment_code' IS NULL OR p.insurance_rules->>'category' IS NULL
   OR(p.rules->>'tax_treatment_code'=preview.rules->>'tax_treatment_code' AND p.rules IS DISTINCT FROM preview.rules)
   OR(p.insurance_rules->>'category'=preview.insurance_rules->>'category' AND p.insurance_rules IS DISTINCT FROM preview.insurance_rules)
   OR(p.rules->>'tax_treatment_code'=preview.rules->>'tax_treatment_code' AND p.insurance_rules->>'category'=preview.insurance_rules->>'category')
  )) THEN
  blockers:=blockers||'"qualified_scope_overlap"'::jsonb;
 END IF;
 RETURN jsonb_build_object('revision',h.revision,'evidence_stamp',stamp,'ready',blockers='[]'::jsonb,'blockers',blockers,
  'missing_coverage',coverage,'selected_ids',selected_ids,'total',total,'official',official,'issued_pack',issued,
  'qualification_scope','tax_insurance','financially_qualified',false);
END $f$;
REVOKE ALL ON FUNCTION payroll.statutory_issuance_readiness(uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.statutory_draft_issuance_status(p_head uuid,p_expected integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM payroll.statutory_draft_actor();RETURN payroll.statutory_issuance_readiness(p_head,p_expected)-'selected_ids';
END $f$;

CREATE FUNCTION public.statutory_draft_issue(p_head uuid,p_expected integer,p_attempt uuid,p_evidence_stamp text,p_reviewed boolean,p_reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;h payroll.statutory_draft_heads;v payroll.statutory_draft_versions;receipt payroll.statutory_draft_receipts;
 intent jsonb;status jsonb;result jsonb;pack payroll.statutory_packs;pack_id uuid;comparisons jsonb;reason text:=btrim(p_reason);
BEGIN
 actor:=payroll.statutory_draft_actor();
 IF p_head IS NULL OR p_expected IS NULL OR p_expected<1 OR p_attempt IS NULL OR p_evidence_stamp IS NULL
  OR p_evidence_stamp !~ '^[0-9a-f]{32}$' OR p_reviewed IS DISTINCT FROM true OR reason IS NULL OR length(reason) NOT BETWEEN 10 AND 1000 THEN
  RAISE EXCEPTION 'statutory_issuance_invalid' USING ERRCODE='22023';END IF;
 intent:=jsonb_build_object('operation','issue_tax_insurance','head',p_head,'revision',p_expected,'evidence_stamp',p_evidence_stamp,'reviewed',p_reviewed,'reason',reason);
 PERFORM pg_advisory_xact_lock(772412,115991);
 PERFORM 1 FROM auth.users WHERE id=actor FOR SHARE;PERFORM 1 FROM platform_private.platform_operator_grants WHERE user_id=actor FOR SHARE;
 actor:=payroll.statutory_draft_actor();
 SELECT * INTO receipt FROM payroll.statutory_draft_receipts WHERE actor_id=actor AND attempt=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'statutory_draft_attempt_conflict' USING ERRCODE='PT409';END IF;RETURN receipt.result;END IF;
 SELECT * INTO h FROM payroll.statutory_draft_heads WHERE id=p_head FOR UPDATE;
 IF NOT FOUND OR h.revision<>p_expected THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
 -- Same authority lock serializes issuance; the table lock coordinates readers
 -- using the existing SHARE lock during finalization. No payroll row is changed.
 LOCK TABLE payroll.statutory_packs IN SHARE ROW EXCLUSIVE MODE;
 status:=payroll.statutory_issuance_readiness(p_head,p_expected);
 SELECT i.pack_id INTO pack_id FROM payroll.statutory_draft_issuances i WHERE i.head_id=p_head AND i.revision=p_expected;
 IF pack_id IS NULL THEN
  IF status->>'evidence_stamp'<>p_evidence_stamp THEN RAISE EXCEPTION 'statutory_issuance_evidence_stale' USING ERRCODE='PT409';END IF;
  IF status->>'ready' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'statutory_issuance_not_ready' USING ERRCODE='23514';END IF;
  SELECT * INTO v FROM payroll.statutory_draft_versions WHERE head_id=p_head AND revision=p_expected;
  pack:=payroll.statutory_draft_pack(v,h.version);
  SELECT jsonb_agg(to_jsonb(c) ORDER BY id) INTO comparisons FROM payroll.statutory_draft_comparisons c
   WHERE head_id=p_head AND revision=p_expected AND case_data->>'origin'='official';
  pack_id:=gen_random_uuid();
  INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules)
   VALUES(pack_id,'EG','egypt_payroll',h.version,v.effective_from,v.effective_until,v.source_references,
    jsonb_build_object('scope','tax_insurance','draft_head',p_head,'draft_revision',p_expected,'evidence_stamp',p_evidence_stamp,
     'numeric_comparisons',comparisons,'representative_case_ids',status->'selected_ids','reviewer',actor,'reviewed_at',clock_timestamp(),'reason',reason,
     'attestation','Official result provenance, category, period applicability and representative tax/insurance coverage reviewed; not labour or complete payroll qualification'),
    'verified',actor,'eg-cumulative-tax-v1',pack.rules,pack.insurance_rules);
  INSERT INTO payroll.statutory_draft_issuances(head_id,revision,pack_id,evidence_stamp,actor_id,reason) VALUES(p_head,p_expected,pack_id,p_evidence_stamp,actor,reason);
 END IF;
 result:=jsonb_build_object('pack',pack_id,'revision',p_expected,'qualification_scope','tax_insurance','financially_qualified',false);
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.statutory_draft_issuance_status(uuid,integer),public.statutory_draft_issue(uuid,integer,uuid,text,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.statutory_draft_issuance_status(uuid,integer),public.statutory_draft_issue(uuid,integer,uuid,text,boolean,text) TO authenticated;
