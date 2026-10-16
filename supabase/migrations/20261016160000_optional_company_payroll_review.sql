-- Owner directive2026-10-16: accounting evidence/review is optional, never a publication or payroll gate.
-- Configuration integrity, dated applicability, authority, isolation, receipts and immutable financial history remain.

ALTER TABLE payroll.statutory_packs DROP CONSTRAINT statutory_packs_check1;
ALTER TABLE payroll.statutory_packs ADD CONSTRAINT statutory_packs_check1 CHECK(state<>'verified' OR (verified_by IS NOT NULL AND jsonb_typeof(source_references)='array' AND review_evidence<>'{}'::jsonb));

CREATE OR REPLACE FUNCTION public.statutory_draft_save(p_head uuid, p_expected integer, p_attempt uuid, p_version text, p_from date, p_until date, p_sources jsonb, p_reason text, p_rules jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE actor uuid;head payroll.statutory_draft_heads;receipt payroll.statutory_draft_receipts;item jsonb;
 version_label text:=btrim(p_version);reason text:=coalesce(nullif(btrim(p_reason),''),'حفظ إعدادات حساب الرواتب');sources jsonb:='[]';intent jsonb;result jsonb;
BEGIN
 actor:=payroll.statutory_draft_actor(); PERFORM payroll.validate_statutory_draft_rules(p_rules);
 IF p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 OR version_label IS NULL OR length(version_label) NOT BETWEEN 3 AND 100
  OR reason IS NULL OR length(reason) NOT BETWEEN 1 AND 500 OR p_from IS NULL
  OR NOT(p_from BETWEEN date '1900-01-01' AND date '2200-12-31')
  OR(p_until IS NOT NULL AND (p_until<=p_from OR p_until>date '2200-12-31'))
  OR jsonb_typeof(p_sources) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 IF jsonb_array_length(p_sources) NOT BETWEEN 0 AND 6 THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_sources) LOOP
  IF jsonb_typeof(item) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  IF NOT(item ?& ARRAY['title','url']) OR(SELECT count(*) FROM jsonb_object_keys(item))<>2
   OR jsonb_typeof(item->'title') IS DISTINCT FROM 'string' OR jsonb_typeof(item->'url') IS DISTINCT FROM 'string'
   OR length(btrim(item->>'title')) NOT BETWEEN 3 AND 160 OR length(btrim(item->>'url'))>2048
   OR btrim(item->>'url') !~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(/[^[:space:]<>"\\]*)?$'
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(sources)s WHERE s->>'url'=btrim(item->>'url')) THEN
   RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  sources:=sources||jsonb_build_array(jsonb_build_object('title',btrim(item->>'title'),'url',btrim(item->>'url')));
 END LOOP;
 intent:=jsonb_build_object('head',p_head,'expected',p_expected,'version',version_label,'from',p_from,'until',p_until,'sources',sources,'reason',reason,'numeric_rules',p_rules);
 -- Same authority lock as grant/revoke; account changes serialize through row lock.
 PERFORM pg_advisory_xact_lock(772412,115991);
 PERFORM 1 FROM auth.users WHERE id=actor FOR SHARE;
 PERFORM 1 FROM platform_private.platform_operator_grants WHERE user_id=actor FOR SHARE;
 actor:=payroll.statutory_draft_actor(); PERFORM payroll.validate_statutory_draft_rules(p_rules);
 SELECT * INTO receipt FROM payroll.statutory_draft_receipts WHERE actor_id=actor AND attempt=p_attempt;
 IF FOUND THEN
  IF receipt.intent<>intent THEN RAISE EXCEPTION 'statutory_draft_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN receipt.result;
 END IF;
 IF p_head IS NULL THEN
  IF p_expected<>0 THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  IF EXISTS(SELECT 1 FROM payroll.statutory_draft_heads WHERE statutory_draft_heads.version=version_label) THEN
   -- Qualified column avoids variable-name ambiguity in the identity lookup.
   RAISE EXCEPTION 'statutory_draft_exists' USING ERRCODE='PT409';END IF;
  INSERT INTO payroll.statutory_draft_heads(version,revision,created_by)VALUES(version_label,1,actor) RETURNING * INTO head;
 ELSE
  SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=p_head FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'statutory_draft_not_found' USING ERRCODE='22023';END IF;
  IF head.revision<>p_expected OR head.version<>version_label THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
  UPDATE payroll.statutory_draft_heads SET revision=revision+1 WHERE id=head.id RETURNING * INTO head;
 END IF;
 INSERT INTO payroll.statutory_draft_versions(head_id,revision,effective_from,effective_until,source_references,reason,actor_id,numeric_rules)
 VALUES(head.id,head.revision,p_from,p_until,sources,reason,actor,p_rules);
 result:=jsonb_build_object('head',head.id,'revision',head.revision,'state','unqualified');
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);
 RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION public.statutory_draft_save(p_head uuid, p_expected integer, p_attempt uuid, p_version text, p_from date, p_until date, p_sources jsonb, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE actor uuid;head payroll.statutory_draft_heads;receipt payroll.statutory_draft_receipts;item jsonb;
 version_label text:=btrim(p_version);reason text:=coalesce(nullif(btrim(p_reason),''),'حفظ إعدادات حساب الرواتب');sources jsonb:='[]';intent jsonb;result jsonb;
BEGIN
 actor:=payroll.statutory_draft_actor();
 IF p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 OR version_label IS NULL OR length(version_label) NOT BETWEEN 3 AND 100
  OR reason IS NULL OR length(reason) NOT BETWEEN 1 AND 500 OR p_from IS NULL
  OR NOT(p_from BETWEEN date '1900-01-01' AND date '2200-12-31')
  OR(p_until IS NOT NULL AND (p_until<=p_from OR p_until>date '2200-12-31'))
  OR jsonb_typeof(p_sources) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 IF jsonb_array_length(p_sources) NOT BETWEEN 0 AND 6 THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_sources) LOOP
  IF jsonb_typeof(item) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  IF NOT(item ?& ARRAY['title','url']) OR(SELECT count(*) FROM jsonb_object_keys(item))<>2
   OR jsonb_typeof(item->'title') IS DISTINCT FROM 'string' OR jsonb_typeof(item->'url') IS DISTINCT FROM 'string'
   OR length(btrim(item->>'title')) NOT BETWEEN 3 AND 160 OR length(btrim(item->>'url'))>2048
   OR btrim(item->>'url') !~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(/[^[:space:]<>"\\]*)?$'
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(sources)s WHERE s->>'url'=btrim(item->>'url')) THEN
   RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  sources:=sources||jsonb_build_array(jsonb_build_object('title',btrim(item->>'title'),'url',btrim(item->>'url')));
 END LOOP;
 intent:=jsonb_build_object('head',p_head,'expected',p_expected,'version',version_label,'from',p_from,'until',p_until,'sources',sources,'reason',reason);
 -- Same authority lock as grant/revoke; account changes serialize through row lock.
 PERFORM pg_advisory_xact_lock(772412,115991);
 PERFORM 1 FROM auth.users WHERE id=actor FOR SHARE;
 PERFORM 1 FROM platform_private.platform_operator_grants WHERE user_id=actor FOR SHARE;
 actor:=payroll.statutory_draft_actor();
 SELECT * INTO receipt FROM payroll.statutory_draft_receipts WHERE actor_id=actor AND attempt=p_attempt;
 IF FOUND THEN
  IF receipt.intent<>intent THEN RAISE EXCEPTION 'statutory_draft_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN receipt.result;
 END IF;
 IF p_head IS NULL THEN
  IF p_expected<>0 THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  IF EXISTS(SELECT 1 FROM payroll.statutory_draft_heads WHERE statutory_draft_heads.version=version_label) THEN
   -- Qualified column avoids variable-name ambiguity in the identity lookup.
   RAISE EXCEPTION 'statutory_draft_exists' USING ERRCODE='PT409';END IF;
  INSERT INTO payroll.statutory_draft_heads(version,revision,created_by)VALUES(version_label,1,actor) RETURNING * INTO head;
 ELSE
  SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=p_head FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'statutory_draft_not_found' USING ERRCODE='22023';END IF;
  IF head.revision<>p_expected OR head.version<>version_label THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
  UPDATE payroll.statutory_draft_heads SET revision=revision+1 WHERE id=head.id RETURNING * INTO head;
 END IF;
 INSERT INTO payroll.statutory_draft_versions(head_id,revision,effective_from,effective_until,source_references,reason,actor_id,numeric_rules)
 VALUES(head.id,head.revision,p_from,p_until,sources,reason,actor,(SELECT v.numeric_rules FROM payroll.statutory_draft_versions v WHERE v.head_id=head.id AND v.revision=head.revision-1));
 result:=jsonb_build_object('head',head.id,'revision',head.revision,'state','unqualified');
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);
 RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION payroll.statutory_issuance_readiness(p_head uuid, p_expected integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE h payroll.statutory_draft_heads;v payroll.statutory_draft_versions;stamp text;blockers jsonb:='[]';
 coverage jsonb:='[]';selected_ids jsonb:='[]';case_id bigint;year_number integer;scenario text;total integer;official integer;issued uuid;preview payroll.statutory_packs;
BEGIN
 SELECT * INTO h FROM payroll.statutory_draft_heads WHERE id=p_head;
 IF NOT FOUND OR h.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
 SELECT * INTO v FROM payroll.statutory_draft_versions WHERE head_id=p_head AND revision=p_expected;
 SELECT count(*),count(*) FILTER(WHERE case_data->>'origin'='official'),
  NULL::text INTO total,official,stamp
 FROM payroll.statutory_draft_comparisons c WHERE head_id=p_head AND revision=p_expected;
 stamp:=md5(to_jsonb(v)::text);
 SELECT pack_id INTO issued FROM payroll.statutory_draft_issuances WHERE head_id=p_head AND revision=p_expected;
 IF v.numeric_rules IS NULL THEN blockers:=blockers||'"numeric_rules_missing"'::jsonb;END IF;

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
  'qualification_scope','tax_insurance','financially_qualified',false,'review_policy',CASE WHEN issued IS NULL THEN 'optional_company_review_v1' ELSE coalesce((SELECT p.review_evidence->>'review_policy' FROM payroll.statutory_packs p WHERE p.id=issued),'legacy_issued_review') END);
END $function$;

CREATE OR REPLACE FUNCTION public.statutory_draft_issue(p_head uuid, p_expected integer, p_attempt uuid, p_evidence_stamp text, p_reviewed boolean, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE actor uuid;h payroll.statutory_draft_heads;v payroll.statutory_draft_versions;receipt payroll.statutory_draft_receipts;
 intent jsonb;status jsonb;result jsonb;pack payroll.statutory_packs;pack_id uuid;comparisons jsonb;reason text:=coalesce(nullif(btrim(p_reason),''),'تفعيل إعدادات حساب الرواتب');
BEGIN
 actor:=payroll.statutory_draft_actor();
 IF p_head IS NULL OR p_expected IS NULL OR p_expected<1 OR p_attempt IS NULL OR p_evidence_stamp IS NULL
  OR p_evidence_stamp !~ '^[0-9a-f]{32}$' OR length(reason) NOT BETWEEN 3 AND 1000 THEN
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
  SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY id),'[]'::jsonb) INTO comparisons FROM payroll.statutory_draft_comparisons c
   WHERE head_id=p_head AND revision=p_expected;
  pack_id:=gen_random_uuid();
  INSERT INTO payroll.statutory_packs(id,jurisdiction,family,version,effective_from,effective_until,source_references,review_evidence,state,verified_by,engine_adapter,rules,insurance_rules,earning_rules,labour_rules)
   VALUES(pack_id,'EG','egypt_payroll',h.version,v.effective_from,v.effective_until,v.source_references,
    jsonb_build_object('scope','tax_insurance','draft_head',p_head,'draft_revision',p_expected,'evidence_stamp',p_evidence_stamp,
     'review_policy','optional_company_review_v1','numeric_comparisons',comparisons,'representative_case_ids',status->'selected_ids','published_by',actor,'published_at',clock_timestamp(),'reason',reason,
     'attestation','Calculation configuration activated by an authorized operator; company evidence and accounting review are optional; no government certification asserted'),
    'verified',actor,'eg-cumulative-tax-v1',pack.rules,pack.insurance_rules,pack.earning_rules,pack.labour_rules);
  INSERT INTO payroll.statutory_draft_issuances(head_id,revision,pack_id,evidence_stamp,actor_id,reason) VALUES(p_head,p_expected,pack_id,p_evidence_stamp,actor,reason);
 END IF;
 result:=jsonb_build_object('pack',pack_id,'revision',p_expected,'qualification_scope','tax_insurance','financially_qualified',false);
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION payroll.issued_tax_qualification(p_pack uuid, p_from date, p_until date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE pack payroll.statutory_packs%ROWTYPE;issuance payroll.statutory_draft_issuances%ROWTYPE;
 version payroll.statutory_draft_versions%ROWTYPE;head payroll.statutory_draft_heads%ROWTYPE;
 expected payroll.statutory_packs%ROWTYPE;comparison payroll.statutory_draft_comparisons%ROWTYPE;
 stamp text;comparisons jsonb;scenario text;selected jsonb:='[]'::jsonb;year_number integer;BEGIN
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 SELECT * INTO issuance FROM payroll.statutory_draft_issuances WHERE pack_id=p_pack;
 IF pack.id IS NULL OR issuance.pack_id IS NULL OR pack.state<>'verified' OR pack.engine_adapter<>'eg-cumulative-tax-v1'
  OR pack.review_evidence->>'scope' IS DISTINCT FROM 'tax_insurance'
  OR pack.verified_by IS DISTINCT FROM issuance.actor_id
  OR p_from IS NULL OR p_until IS NULL OR NOT isfinite(p_from) OR NOT isfinite(p_until) OR p_from>p_until
  OR extract(year FROM p_from)<>extract(year FROM p_until)
  OR pack.effective_from>p_from OR (pack.effective_until IS NOT NULL AND pack.effective_until<=p_until) THEN
  RETURN jsonb_build_object('ready',false,'reason','issued_tax_evidence_required');END IF;
 SELECT * INTO version FROM payroll.statutory_draft_versions WHERE head_id=issuance.head_id AND revision=issuance.revision;
 SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=issuance.head_id;
 expected:=payroll.statutory_draft_pack(version,head.version);
 -- New publication policy validates the actual immutable configuration. Optional
 -- comparisons can be added later without changing this configuration fingerprint.
 IF pack.review_evidence->>'review_policy'='optional_company_review_v1' THEN
  stamp:=md5(to_jsonb(version)::text);
  IF stamp IS DISTINCT FROM issuance.evidence_stamp OR stamp IS DISTINCT FROM pack.review_evidence->>'evidence_stamp'
   OR pack.review_evidence->>'draft_head' IS DISTINCT FROM issuance.head_id::text
   OR pack.review_evidence->>'draft_revision' IS DISTINCT FROM issuance.revision::text
   OR pack.rules IS DISTINCT FROM expected.rules OR pack.insurance_rules IS DISTINCT FROM expected.insurance_rules
   OR pack.earning_rules IS DISTINCT FROM expected.earning_rules OR pack.labour_rules IS DISTINCT FROM expected.labour_rules
   OR pack.effective_from IS DISTINCT FROM version.effective_from OR pack.effective_until IS DISTINCT FROM version.effective_until THEN
   RETURN jsonb_build_object('ready',false,'reason','issued_tax_evidence_mismatch');END IF;
  RETURN jsonb_build_object('ready',true,'scope','issued_tax_insurance','pack_id',p_pack,'head',issuance.head_id,
   'revision',issuance.revision,'evidence_stamp',stamp,'actor',issuance.actor_id,'year',extract(year FROM p_from),
   'case_ids','[]'::jsonb,'review_policy','optional_company_review_v1','origin','published_configuration');
 END IF;

 SELECT md5(to_jsonb(version)::text||md5(coalesce(string_agg(md5(to_jsonb(c)::text),'' ORDER BY id),''))) INTO stamp
  FROM payroll.statutory_draft_comparisons c WHERE head_id=issuance.head_id AND revision=issuance.revision;
 SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY id),'[]'::jsonb) INTO comparisons
  FROM payroll.statutory_draft_comparisons c WHERE head_id=issuance.head_id AND revision=issuance.revision AND case_data->>'origin'='official';
 IF stamp IS DISTINCT FROM issuance.evidence_stamp OR stamp IS DISTINCT FROM pack.review_evidence->>'evidence_stamp'
  OR pack.review_evidence->>'draft_head' IS DISTINCT FROM issuance.head_id::text
  OR pack.review_evidence->>'draft_revision' IS DISTINCT FROM issuance.revision::text
  OR pack.review_evidence->'numeric_comparisons' IS DISTINCT FROM comparisons
  OR pack.rules IS DISTINCT FROM expected.rules OR pack.insurance_rules IS DISTINCT FROM expected.insurance_rules
  OR pack.earning_rules IS DISTINCT FROM expected.earning_rules OR pack.labour_rules IS DISTINCT FROM expected.labour_rules
  OR pack.effective_from IS DISTINCT FROM version.effective_from OR pack.effective_until IS DISTINCT FROM version.effective_until THEN
  RETURN jsonb_build_object('ready',false,'reason','issued_tax_evidence_mismatch');END IF;
 year_number:=extract(year FROM p_from);
 FOREACH scenario IN ARRAY ARRAY['low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding'] LOOP
  SELECT * INTO comparison FROM payroll.statutory_current_comparisons(issuance.head_id,issuance.revision) c
   WHERE c.case_data->>'scenario'=scenario AND extract(year FROM(c.case_data->'tax'->>'from')::date)=year_number
    AND c.result->>'matched'='true' AND c.case_data->>'source_url' ~ '^https://([a-zA-Z0-9-]+\.)*(eta|nosi)\.gov\.eg(/|$)'
    AND pack.review_evidence->'representative_case_ids' @> to_jsonb(c.id)
   ORDER BY id DESC LIMIT 1;
  IF comparison.id IS NULL OR comparison.result IS DISTINCT FROM payroll.statutory_draft_compare(version,head.version,comparison.case_data) THEN
   RETURN jsonb_build_object('ready',false,'reason','official_tax_coverage_required');END IF;
  selected:=selected||to_jsonb(comparison.id);
 END LOOP;
 RETURN jsonb_build_object('ready',true,'scope','issued_tax_insurance','pack_id',p_pack,'head',issuance.head_id,
  'revision',issuance.revision,'evidence_stamp',stamp,'actor',issuance.actor_id,'year',year_number,'case_ids',selected);
END $function$;

CREATE OR REPLACE FUNCTION payroll.issued_labour_qualification(p_pack uuid, p_from date, p_until date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE qualification jsonb;pack payroll.statutory_packs;version payroll.statutory_draft_versions;
 issuance payroll.statutory_draft_issuances;comparison payroll.statutory_draft_comparisons;scenario text;year_number integer;ids jsonb:='[]';BEGIN
 qualification:=payroll.issued_tax_qualification(p_pack,p_from,p_until);
 IF qualification->>'ready' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('ready',false,'reason','issued_labour_evidence_required');END IF;
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 SELECT * INTO issuance FROM payroll.statutory_draft_issuances WHERE pack_id=p_pack;
 SELECT * INTO version FROM payroll.statutory_draft_versions WHERE head_id=issuance.head_id AND revision=issuance.revision;
 IF pack.labour_rules->>'adapter' IS DISTINCT FROM 'eg-wage-deductions113114-v1' THEN
  RETURN jsonb_build_object('ready',false,'reason','issued_labour_rules_required');END IF;
 RETURN jsonb_build_object('ready',true,'scope','issued_labour_deductions113114','pack_id',p_pack,'evidence_stamp',issuance.evidence_stamp,'case_ids',ids);
END $function$;

CREATE OR REPLACE FUNCTION payroll.calculate_cumulative_tax(p_pack uuid, p_context jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
   DECLARE pack payroll.statutory_packs;BEGIN
    SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
    IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
 THEN
     RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';END IF;
    RETURN payroll.calculate_cumulative_tax_data(pack,p_context);
   END $function$;

CREATE OR REPLACE FUNCTION payroll.calculate_insurance(p_pack uuid, p_context jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
   DECLARE pack payroll.statutory_packs;BEGIN
    SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
    IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
 THEN
     RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';END IF;
    RETURN payroll.calculate_insurance_data(pack,p_context);
   END $function$;

CREATE OR REPLACE FUNCTION payroll.resolve_taxable_earnings(p_employee jsonb, p_pack uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE pack payroll.statutory_packs;rules jsonb;sources jsonb;line jsonb;part jsonb;
 taxable_parts jsonb;amount numeric;taxable numeric;total_taxable numeric:=0;total_nontaxable numeric:=0;
 lines jsonb:='[]';starts date;ends date;fraction jsonb;
BEGIN
 SELECT * INTO pack FROM payroll.statutory_packs WHERE id=p_pack;
 IF NOT FOUND OR pack.state<>'verified' OR pack.engine_adapter IS DISTINCT FROM 'eg-cumulative-tax-v1'
 THEN
  RAISE EXCEPTION 'payroll_statutory_pack_unqualified' USING ERRCODE='22023';END IF;
 rules:=pack.earning_rules;
 IF jsonb_typeof(rules) IS DISTINCT FROM 'object' OR NOT(rules ?& ARRAY['schema','base_taxable','component_treatment','mixed_rounding'])
  OR(rules-'date_partition_rounding'-ARRAY['schema','base_taxable','component_treatment','mixed_rounding'])<>'{}'::jsonb OR(rules ? 'date_partition_rounding' AND rules->>'date_partition_rounding' IS DISTINCT FROM 'chronological_prefix_half_up_cent') OR rules->>'schema' IS DISTINCT FROM 'eg-earning-treatment-v1'
  OR jsonb_typeof(rules->'base_taxable') IS DISTINCT FROM 'boolean'
  OR rules->>'component_treatment' IS DISTINCT FROM 'reviewed_dated_declarations'
  OR rules->>'mixed_rounding' IS DISTINCT FROM 'taxable_half_up_cent_remainder_nontaxable' THEN
  RAISE EXCEPTION 'payroll_earning_rules_unqualified' USING ERRCODE='22023';END IF;
 IF p_employee->>'gross_complete' IS DISTINCT FROM 'true' OR coalesce(p_employee->>'gross','') !~ '^[0-9]+(\.[0-9]{1,2}0*)?$'
  OR coalesce(p_employee->>'starts_on','') !~ '^\d{4}-\d{2}-\d{2}$' OR coalesce(p_employee->>'ends_on','') !~ '^\d{4}-\d{2}-\d{2}$' THEN
  RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END IF;
 BEGIN starts:=(p_employee->>'starts_on')::date;ends:=(p_employee->>'ends_on')::date;
 EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN RAISE EXCEPTION 'payroll_earning_sources_invalid' USING ERRCODE='22023';END;
 IF starts>ends OR NOT isfinite(pack.effective_from) OR(pack.effective_until IS NOT NULL AND NOT isfinite(pack.effective_until))
  OR starts<pack.effective_from OR(pack.effective_until IS NOT NULL AND ends>=pack.effective_until) THEN
  RAISE EXCEPTION 'payroll_statutory_period_unsupported' USING ERRCODE='22023';END IF;
 sources:=payroll.current_earning_sources(p_employee);
 FOR line IN SELECT value FROM jsonb_array_elements(sources->'lines') LOOP
  amount:=(line->>'amount')::numeric;
  IF line->>'component'='base' THEN taxable:=CASE WHEN(rules->>'base_taxable')::boolean THEN amount ELSE 0 END;
  ELSIF line->>'declaration_state'='uniform_declared_taxable' THEN taxable:=amount;
  ELSIF line->>'declaration_state'='uniform_declared_nontaxable' THEN taxable:=0;
  ELSIF line->>'declaration_state'='mixed_declarations_require_allocation' THEN
   taxable_parts:='[]';
   FOR part IN SELECT value FROM jsonb_array_elements(line->'source_parts') LOOP
    IF coalesce(part->>'_numerator','') !~ '^[0-9]+(\.0+)?$' OR coalesce(part->>'_denominator','') !~ '^[0-9]+(\.0+)?$'
     OR(part->>'_denominator')::numeric<=0 THEN RAISE EXCEPTION 'payroll_earning_allocation_unknown' USING ERRCODE='22023';END IF;
    IF part->'declared_taxable'='true'::jsonb THEN taxable_parts:=taxable_parts||jsonb_build_array(part);END IF;
   END LOOP;
   -- Verify the original total using exact parts, then round the taxable share
   -- once under the explicit pack rule. The complementary share retains cents.
   IF payroll.round_fraction(payroll.parts_fraction(line->'source_parts'))<>amount THEN
    RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
   fraction:=payroll.parts_fraction(taxable_parts);taxable:=payroll.round_fraction(fraction);
  ELSE RAISE EXCEPTION 'payroll_earning_allocation_unknown' USING ERRCODE='22023';END IF;
  IF taxable<0 OR taxable>amount THEN RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
  total_taxable:=total_taxable+taxable;total_nontaxable:=total_nontaxable+amount-taxable;
  lines:=lines||jsonb_build_array(line||jsonb_build_object('taxable_amount',taxable,'nontaxable_amount',amount-taxable,'rounding',rules->>'mixed_rounding'));
 END LOOP;
 IF total_taxable+total_nontaxable<>(p_employee->>'gross')::numeric THEN
  RAISE EXCEPTION 'payroll_earning_source_mismatch' USING ERRCODE='22023';END IF;
 RETURN jsonb_build_object('contract','eg-earning-attribution-v1','pack_id',pack.id,'pack_version',pack.version,
  'earning_rules',rules,'taxable_earnings',total_taxable,'nontaxable_earnings',total_nontaxable,'lines',lines,'financially_qualified',false);
END $function$;

CREATE OR REPLACE FUNCTION public.statutory_draft_compare(p_head uuid, p_expected integer, p_attempt uuid, p_case jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 IF EXISTS(SELECT 1 FROM payroll.statutory_draft_issuances i JOIN payroll.statutory_packs p ON p.id=i.pack_id WHERE i.head_id=p_head AND i.revision=p_expected AND p.review_evidence->>'review_policy' IS DISTINCT FROM 'optional_company_review_v1') THEN RAISE EXCEPTION 'statutory_revision_issued' USING ERRCODE='PT409';END IF; result:=payroll.statutory_draft_compare(version,head.version,p_case);
 INSERT INTO payroll.statutory_draft_comparisons(head_id,revision,case_data,result,actor_id) VALUES(p_head,p_expected,p_case,result,actor) RETURNING id INTO row_id;
 result:=jsonb_build_object('id',row_id,'revision',p_expected,'matched',result->'matched','qualified',false);
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);RETURN result;
END $function$;

CREATE OR REPLACE FUNCTION payroll.statutory_draft_compare(p_version payroll.statutory_draft_versions, p_label text, p_case jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE pack payroll.statutory_packs;tax jsonb;insurance jsonb;t jsonb;expected jsonb;actual jsonb;months jsonb:='[]';m jsonb;key text;matched boolean;first_date date;last_date date;
BEGIN
 IF p_case->>'domain'='labour_deductions' THEN RETURN payroll.compare_labour_deduction_case(p_version,p_case);END IF; IF octet_length(p_case::text)>16384 OR jsonb_typeof(p_case) IS DISTINCT FROM 'object' OR NOT(p_case ?& ARRAY['name','scenario','origin','source_url','reference','tax','insurance','expected']) OR(SELECT count(*) FROM jsonb_object_keys(p_case))<>8
  OR jsonb_typeof(p_case->'name') IS DISTINCT FROM 'string' OR length(btrim(p_case->>'name')) NOT BETWEEN 3 AND 160
  OR coalesce(p_case->>'scenario','') NOT IN('low','medium','high','mid_year','cumulative','insurance_min','insurance_max','component_mix','correction','rounding')
  OR coalesce(p_case->>'origin','') NOT IN('synthetic','official') OR jsonb_typeof(p_case->'reference') IS DISTINCT FROM 'string' OR length(btrim(p_case->>'reference')) NOT BETWEEN 3 AND 160
  OR jsonb_typeof(p_case->'source_url') IS DISTINCT FROM 'string'
  OR (p_case->>'source_url'<>'' AND p_case->>'source_url' !~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(/[^[:space:]<>"\\]*)?$') OR (p_case->>'origin'='official' AND p_case->>'source_url'='') THEN RAISE EXCEPTION 'statutory_comparison_invalid' USING ERRCODE='22023';END IF;
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
END $function$;
