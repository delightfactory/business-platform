-- Numeric draft values are reviewed configuration, never live packs.
ALTER TABLE payroll.statutory_draft_versions ADD COLUMN numeric_rules jsonb;
CREATE FUNCTION payroll.validate_statutory_draft_rules(p_rules jsonb) RETURNS void
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE t jsonb;i jsonb;c jsonb;b jsonb;x jsonb;bands jsonb;previous numeric:=0;upper numeric;idx integer:=0;n integer;seen text[]:='{}';employee_total numeric:=0;employer_total numeric:=0;key text;
BEGIN
 IF p_rules IS NULL THEN RETURN;END IF;
 IF octet_length(p_rules::text)>65536 OR jsonb_typeof(p_rules) IS DISTINCT FROM 'object'
  OR NOT(p_rules ?& ARRAY['tax','insurance','base_taxable']) OR(SELECT count(*) FROM jsonb_object_keys(p_rules))<>3
  OR jsonb_typeof(p_rules->'base_taxable') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 t:=p_rules->'tax';i:=p_rules->'insurance';
 IF jsonb_typeof(t) IS DISTINCT FROM 'object' OR NOT(t ?& ARRAY['treatment','exemption','column_basis','columns']) OR(SELECT count(*) FROM jsonb_object_keys(t))<>4
  OR jsonb_typeof(t->'treatment') IS DISTINCT FROM 'string' OR(t->>'treatment') !~ '^[0-9]{2}$'
  OR jsonb_typeof(t->'exemption') IS DISTINCT FROM 'string' OR(t->>'exemption') !~ '^(0|[1-9][0-9]{0,9})(\.[0-9]{1,2})?$'
  OR(t->>'exemption')::numeric>1000000000 OR coalesce(t->>'column_basis','') NOT IN('annual_raw','annual_floor10')
  OR jsonb_typeof(t->'columns') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 n:=jsonb_array_length(t->'columns');IF n NOT BETWEEN 1 AND 16 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 FOR c IN SELECT value FROM jsonb_array_elements(t->'columns') LOOP
  idx:=idx+1;bands:='[]';
  IF jsonb_typeof(c) IS DISTINCT FROM 'object' OR NOT(c ?& ARRAY['through','bands']) OR(SELECT count(*) FROM jsonb_object_keys(c))<>2
   OR jsonb_typeof(c->'through') IS DISTINCT FROM 'string' OR jsonb_typeof(c->'bands') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
  IF idx=n THEN IF c->>'through'<>'' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
  ELSE
   IF(c->>'through') !~ '^(0|[1-9][0-9]{0,9})(\.[0-9]{1,2})?$' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
   upper:=(c->>'through')::numeric;IF upper<=previous OR upper>1000000000 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;previous:=upper;
  END IF;
  IF jsonb_array_length(c->'bands') NOT BETWEEN 1 AND 32 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
  FOR b IN SELECT value FROM jsonb_array_elements(c->'bands') LOOP
   IF jsonb_typeof(b) IS DISTINCT FROM 'object' OR NOT(b ?& ARRAY['upper','rate']) OR(SELECT count(*) FROM jsonb_object_keys(b))<>2
    OR jsonb_typeof(b->'upper') IS DISTINCT FROM 'string' OR jsonb_typeof(b->'rate') IS DISTINCT FROM 'string'
    OR(b->>'rate') !~ '^(0|[1-9][0-9]{0,2})(\.[0-9]{1,6})?$' OR(b->>'rate')::numeric>100
    OR(b->>'upper'<>'' AND ((b->>'upper') !~ '^(0|[1-9][0-9]{0,9})(\.[0-9]{1,2})?$')) THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
   IF(b->>'upper')<>'' AND(b->>'upper')::numeric>1000000000 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
   bands:=bands||jsonb_build_array(jsonb_build_object('upper',nullif(b->>'upper','')::numeric,'rate',(b->>'rate')::numeric/100));
  END LOOP;
  PERFORM payroll.progressive_annual_arithmetic(0,bands);
 END LOOP;
 IF jsonb_typeof(i) IS DISTINCT FROM 'object' OR NOT(i ?& ARRAY['category','minimum','maximum','branches']) OR(SELECT count(*) FROM jsonb_object_keys(i))<>4
  OR jsonb_typeof(i->'category') IS DISTINCT FROM 'string' OR length(btrim(i->>'category')) NOT BETWEEN 1 AND 160
  OR jsonb_typeof(i->'branches') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 FOREACH key IN ARRAY ARRAY['minimum','maximum'] LOOP
  IF jsonb_typeof(i->key) IS DISTINCT FROM 'string' OR(i->>key) !~ '^(0|[1-9][0-9]{0,9})(\.[0-9]{1,2})?$'
   OR(i->>key)::numeric>1000000000 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 END LOOP;
 IF(i->>'maximum')::numeric<=(i->>'minimum')::numeric OR jsonb_array_length(i->'branches') NOT BETWEEN 1 AND 6 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(i->'branches') LOOP
  IF jsonb_typeof(x) IS DISTINCT FROM 'object' OR NOT(x ?& ARRAY['branch','employee','employer','deductible']) OR(SELECT count(*) FROM jsonb_object_keys(x))<>4
   OR coalesce(x->>'branch','') NOT IN('pension','reward','injury','sickness','unemployment','universal_health') OR(x->>'branch')=ANY(seen)
   OR jsonb_typeof(x->'deductible') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
  FOREACH key IN ARRAY ARRAY['employee','employer'] LOOP
   IF jsonb_typeof(x->key) IS DISTINCT FROM 'string' OR(x->>key) !~ '^(0|[1-9][0-9]{0,2})(\.[0-9]{1,6})?$'
    OR(x->>key)::numeric>100 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
  END LOOP;
  seen:=array_append(seen,x->>'branch');employee_total:=employee_total+(x->>'employee')::numeric;employer_total:=employer_total+(x->>'employer')::numeric;
 END LOOP;
 IF employee_total>100 OR employer_total>100 THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';END IF;
 EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN RAISE EXCEPTION 'statutory_numeric_invalid' USING ERRCODE='22023';
END $f$;
REVOKE ALL ON FUNCTION payroll.validate_statutory_draft_rules(jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- Preserve legacy metadata receipts and numeric data on metadata-only edits.
-- New endpoint binds numerical intent to the same atomic CAS/receipt command.
DO $f$ DECLARE original text;extended text;old_anchor text;new_anchor text;BEGIN
 original:=pg_get_functiondef('public.statutory_draft_save(uuid,integer,uuid,text,date,date,jsonb,text)'::regprocedure);
 extended:=replace(original,'p_reason text)','p_reason text, p_rules jsonb)');
 IF extended=original THEN RAISE EXCEPTION 'unexpected_numeric_draft_signature';END IF;
 extended:=replace(extended,'actor:=payroll.statutory_draft_actor();', 'actor:=payroll.statutory_draft_actor(); PERFORM payroll.validate_statutory_draft_rules(p_rules);');
 old_anchor:='''sources'',sources,''reason'',reason);';new_anchor:='''sources'',sources,''reason'',reason,''numeric_rules'',p_rules);';
 IF strpos(extended,old_anchor)=0 THEN RAISE EXCEPTION 'unexpected_numeric_draft_intent';END IF;extended:=replace(extended,old_anchor,new_anchor);
 old_anchor:='source_references,reason,actor_id)';new_anchor:='source_references,reason,actor_id,numeric_rules)';
 IF strpos(extended,old_anchor)=0 THEN RAISE EXCEPTION 'unexpected_numeric_draft_insert';END IF;extended:=replace(extended,old_anchor,new_anchor);
 old_anchor:='p_from,p_until,sources,reason,actor);';new_anchor:='p_from,p_until,sources,reason,actor,p_rules);';
 IF strpos(extended,old_anchor)=0 THEN RAISE EXCEPTION 'unexpected_numeric_draft_values';END IF;extended:=replace(extended,old_anchor,new_anchor);EXECUTE extended;
 original:=replace(original,'source_references,reason,actor_id)','source_references,reason,actor_id,numeric_rules)');
 original:=replace(original,'p_from,p_until,sources,reason,actor);','p_from,p_until,sources,reason,actor,(SELECT v.numeric_rules FROM payroll.statutory_draft_versions v WHERE v.head_id=head.id AND v.revision=head.revision-1));');EXECUTE original;
END $f$;
REVOKE ALL ON FUNCTION public.statutory_draft_save(uuid,integer,uuid,text,date,date,jsonb,text,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.statutory_draft_save(uuid,integer,uuid,text,date,date,jsonb,text,jsonb) TO authenticated;
