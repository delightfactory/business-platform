-- Bounded Cube 4 review queue: comparison-aware attention filtering.
-- The private core is derived from the authoritative seven-argument workspace
-- definition so employer/access/detail/summary behavior remains one implementation.
DO $migration$
DECLARE
  definition text;
  signature text := 'public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text)';
  header text := 'CREATE OR REPLACE FUNCTION public.payroll_run_workspace(p_tenant uuid, p_employer uuid, p_period uuid, p_after uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30, p_employee uuid DEFAULT NULL::uuid, p_query text DEFAULT ''''::text)';
  replacement text := 'CREATE OR REPLACE FUNCTION payroll.run_review_workspace(p_tenant uuid, p_employer uuid, p_period uuid, p_after uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30, p_employee uuid DEFAULT NULL::uuid, p_query text DEFAULT ''''::text, p_attention boolean DEFAULT false)';
  old text;
  changed text;
BEGIN
  definition := pg_get_functiondef(signature::regprocedure);
  IF position(header in definition)=0 THEN
    RAISE EXCEPTION 'review workspace extraction guard: header changed';
  END IF;
  definition := replace(definition,header,replacement);
  old := 'DECLARE access jsonb;run payroll.runs%ROWTYPE;candidate payroll.candidates%ROWTYPE;bounds payroll.periods%ROWTYPE;stale jsonb:=''[]'';items jsonb;detail jsonb;previous payroll.candidates%ROWTYPE;variance jsonb:=''null'';summary jsonb;BEGIN';
  IF position(old in definition)=0 THEN
    RAISE EXCEPTION 'review workspace extraction guard: declaration changed';
  END IF;
  definition := replace(definition,
    old,
    'DECLARE access jsonb;run payroll.runs%ROWTYPE;candidate payroll.candidates%ROWTYPE;bounds payroll.periods%ROWTYPE;stale jsonb:=''[]'';items jsonb;detail jsonb;previous payroll.candidates%ROWTYPE;variance jsonb:=''null'';summary jsonb;scope jsonb;filtered jsonb;attention_count integer:=0;matching_count integer:=0;has_more boolean:=false;next_after uuid;BEGIN');
  old := 'SELECT COALESCE(jsonb_agg(e-''lines''-''unresolved_parts''-''dated_rates''-''source_days''-''source_coverage_days'' ORDER BY e->>''employment_id''),''[]'') INTO items FROM(SELECT e FROM jsonb_array_elements(candidate.output->''employees'')e WHERE(p_after IS NULL OR(e->>''employment_id'')::uuid>p_after) AND(e->>''name'' ILIKE ''%''||p_query||''%'' OR e->>''code'' ILIKE ''%''||p_query||''%'') ORDER BY(e->>''employment_id'')::uuid LIMIT p_limit)x;';
  IF position(old in definition)=0 THEN
    RAISE EXCEPTION 'review workspace extraction guard: pre-comparison list changed';
  END IF;
  definition := replace(definition,old,
    'SELECT COALESCE(jsonb_agg(e-''lines''-''unresolved_parts''-''dated_rates''-''source_days''-''source_coverage_days'' ORDER BY e->>''employment_id''),''[]'') INTO items FROM jsonb_array_elements(candidate.output->''employees'')e;');
  old := E'  summary:=candidate.output-''employees''-''issues'';\n END IF;';
  IF position(old in definition)=0 THEN
    RAISE EXCEPTION 'review workspace extraction guard: summary boundary changed';
  END IF;
  definition := replace(definition,old,
    E'  summary:=candidate.output-''employees''-''issues'';\n  scope:=items;\n  SELECT count(*) INTO attention_count FROM jsonb_array_elements(scope)e WHERE jsonb_array_length(COALESCE(e->''issues'',''[]''::jsonb))>0 OR (stale=''[]''::jsonb AND (COALESCE((e->>''new_employee'')::boolean,false) OR ((e->>''gross_difference'') IS NOT NULL AND (e->>''gross_difference'')::numeric IS DISTINCT FROM 0)));\n  SELECT COALESCE(jsonb_agg(e ORDER BY(e->>''employment_id'')::uuid),''[]''::jsonb) INTO filtered FROM jsonb_array_elements(scope)e WHERE(p_attention IS FALSE OR jsonb_array_length(COALESCE(e->''issues'',''[]''::jsonb))>0 OR (stale=''[]''::jsonb AND (COALESCE((e->>''new_employee'')::boolean,false) OR ((e->>''gross_difference'') IS NOT NULL AND (e->>''gross_difference'')::numeric IS DISTINCT FROM 0)))) AND(e->>''name'' ILIKE ''%''||p_query||''%'' OR e->>''code'' ILIKE ''%''||p_query||''%'');\n  matching_count:=jsonb_array_length(filtered);\n  SELECT COALESCE(jsonb_agg(e ORDER BY(e->>''employment_id'')::uuid),''[]''::jsonb) INTO scope FROM jsonb_array_elements(filtered)e WHERE(p_after IS NULL OR(e->>''employment_id'')::uuid>p_after);\n  has_more:=jsonb_array_length(scope)>p_limit;\n  IF has_more THEN next_after:=(scope->(p_limit-1)->>''employment_id'')::uuid;END IF;\n  items:=CASE WHEN has_more THEN (SELECT COALESCE(jsonb_agg(e ORDER BY ord),''[]''::jsonb) FROM jsonb_array_elements(scope) WITH ORDINALITY x(e,ord) WHERE ord<=p_limit) ELSE scope END;\n END IF;');
  old := $needle$'review_filter',jsonb_build_object($needle$;
  IF position(old in definition)>0 THEN
    RAISE EXCEPTION 'review workspace extraction guard: review metadata already present';
  END IF;
  old := $needle$'issue_count',COALESCE(jsonb_array_length(candidate.output->'issues'),0),'history',$needle$;
  IF position(old in definition)=0 THEN
    RAISE EXCEPTION 'review workspace extraction guard: metadata boundary changed';
  END IF;
  changed := replace(old,$needle$'history',$needle$,$needle$'review_filter',jsonb_build_object('view',CASE WHEN p_attention THEN 'attention' ELSE 'all' END,'attention_count',CASE WHEN candidate.id IS NULL THEN 0 ELSE attention_count END,'matching_count',CASE WHEN candidate.id IS NULL THEN 0 ELSE matching_count END,'has_more',CASE WHEN candidate.id IS NULL THEN false ELSE has_more END,'next_after',next_after),'history',$needle$);
  definition := replace(definition,old,changed);
  IF definition=pg_get_functiondef(signature::regprocedure) THEN
    RAISE EXCEPTION 'review workspace extraction guard: no changes';
  END IF;
  EXECUTE definition;
END
$migration$;

CREATE OR REPLACE FUNCTION public.payroll_run_workspace(
  p_tenant uuid,p_employer uuid,p_period uuid,p_after uuid DEFAULT NULL,
  p_limit integer DEFAULT 30,p_employee uuid DEFAULT NULL,p_query text DEFAULT ''
) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $function$
  SELECT payroll.run_review_workspace(p_tenant,p_employer,p_period,p_after,p_limit,p_employee,p_query,false)-'review_filter'
$function$;

CREATE OR REPLACE FUNCTION public.payroll_run_review_workspace(
  p_tenant uuid,p_employer uuid,p_period uuid,p_after uuid DEFAULT NULL,
  p_limit integer DEFAULT 30,p_employee uuid DEFAULT NULL,p_query text DEFAULT '',
  p_view text DEFAULT 'attention'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF p_view IS NULL OR p_view NOT IN ('all','attention') THEN
    RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';
  END IF;
  RETURN payroll.run_review_workspace(p_tenant,p_employer,p_period,p_after,p_limit,p_employee,p_query,p_view='attention');
END
$function$;

REVOKE ALL ON FUNCTION payroll.run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,boolean) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text),public.payroll_run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_run_workspace(uuid,uuid,uuid,uuid,integer,uuid,text),public.payroll_run_review_workspace(uuid,uuid,uuid,uuid,integer,uuid,text,text) TO authenticated;
