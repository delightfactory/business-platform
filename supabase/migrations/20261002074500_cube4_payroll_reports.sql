-- Cube4 report source foundations. No legal adapter or public finalization is added.
-- Private projections are callable only through current-authority public surfaces.
CREATE FUNCTION payroll.report_authorized(p_tenant uuid,p_report text,p_export boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE actor uuid;BEGIN
 IF p_report IS NULL OR p_report NOT IN('sheet','payslip','components','statutory','variance','payments','advances') OR p_export IS NULL THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
 IF p_report='advances' THEN actor:=payroll.advance_authorized(p_tenant,'view');IF p_export THEN PERFORM payroll.authorized(p_tenant,'payroll.export',false);END IF;
 ELSE actor:=payroll.authorized(p_tenant,CASE WHEN p_export THEN 'payroll.export' ELSE 'payroll.view' END,false);END IF;
 RETURN actor;
END $f$;
CREATE FUNCTION public.payroll_report_choices(p_tenant uuid,p_employer uuid,p_after uuid DEFAULT NULL,p_selected uuid[] DEFAULT '{}',p_report text DEFAULT 'sheet') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;items jsonb;selected jsonb;employer jsonb;BEGIN
 actor:=payroll.report_authorized(p_tenant,p_report,false);
 IF p_selected IS NULL OR cardinality(p_selected)>2 OR array_position(p_selected,NULL) IS NOT NULL THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
 SELECT jsonb_build_object('name',display_name,'legal_name',legal_name) INTO employer FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_report='advances' THEN items:='[]';selected:='[]';
 ELSE
  IF p_after IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_after) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  IF EXISTS(SELECT 1 FROM unnest(p_selected) selected_ref(wanted_id) WHERE NOT EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.id=selected_ref.wanted_id)) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY ends_on DESC,id DESC),'[]') INTO items FROM(SELECT f.id,(f.period_snapshot->>'starts_on')::date starts_on,(f.period_snapshot->>'ends_on')::date ends_on,EXISTS(SELECT 1 FROM payroll.output_successions s WHERE s.tenant_id=f.tenant_id AND s.original_output=f.id) superseded FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND(p_after IS NULL OR ((f.period_snapshot->>'ends_on')::date,f.id)<(SELECT (cursor.period_snapshot->>'ends_on')::date,cursor.id FROM payroll.final_contexts cursor WHERE cursor.tenant_id=p_tenant AND cursor.employer_id=p_employer AND cursor.id=p_after)) ORDER BY (f.period_snapshot->>'ends_on')::date DESC,f.id DESC LIMIT 30)x;
  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY ends_on DESC,id DESC),'[]') INTO selected FROM(SELECT f.id,(f.period_snapshot->>'starts_on')::date starts_on,(f.period_snapshot->>'ends_on')::date ends_on,EXISTS(SELECT 1 FROM payroll.output_successions s WHERE s.tenant_id=f.tenant_id AND s.original_output=f.id) superseded FROM payroll.final_contexts f WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.id=ANY(p_selected))x;
 END IF;
 PERFORM payroll.report_authorized(p_tenant,p_report,false);
 RETURN jsonb_build_object('employer',employer,'items',items,'selected',selected,'next',CASE WHEN jsonb_array_length(items)=30 THEN items->29->>'id' END);
END $f$;
-- All amounts are existing finalized/ledger decimals. Missing statutory values
-- remain NULL and are surfaced by the workspace, never converted to zero.
-- Filters select complete employee outputs by a saved assignment segment.
-- valid_until is exclusive; salary is not guessed across multiple assignments.
CREATE FUNCTION payroll.report_employment_matches(p_tenant uuid,p_employer uuid,p_output uuid,p_employment uuid,p_site uuid,p_department uuid) RETURNS boolean LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT (p_site IS NULL AND p_department IS NULL) OR EXISTS(
  SELECT 1 FROM payroll.final_contexts c CROSS JOIN LATERAL jsonb_array_elements(c.manifest->'assignments') assignment
  WHERE c.tenant_id=p_tenant AND c.employer_id=p_employer AND c.id=p_output
   AND assignment->>'employment_id'=p_employment::text
   AND (p_site IS NULL OR assignment->>'site_id'=p_site::text)
   AND (p_department IS NULL OR assignment->>'department_id'=p_department::text)
   AND daterange((assignment->>'valid_from')::date,(assignment->>'valid_until')::date,'[)')&&daterange((c.period_snapshot->>'starts_on')::date,(c.period_snapshot->>'ends_on')::date,'[]'))
$f$;
REVOKE ALL ON FUNCTION payroll.report_employment_matches(uuid,uuid,uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
-- Payslip presentation resolves saved component-version metadata from the
-- immutable result/manifest; no current catalog participates in old payslips.
CREATE FUNCTION payroll.report_payslip_lines(p_manifest jsonb,p_result jsonb,p_employment uuid,p_explanation jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 WITH employee AS(SELECT e FROM jsonb_array_elements(p_result->'employees') e WHERE e->>'employment_id'=p_employment::text),
 saved_lines AS(SELECT line,ordinal FROM jsonb_array_elements(p_explanation->'lines') WITH ORDINALITY x(line,ordinal)),
 resolved AS(SELECT l.line,l.ordinal,
  CASE WHEN l.line->>'component'='base' OR l.line->>'component' LIKE 'advance:%' THEN true
   ELSE COALESCE(metadata.known,false) END known,
  CASE WHEN l.line->>'classification'='employer_cost' THEN false
   WHEN l.line->>'component'='base' OR l.line->>'component' LIKE 'advance:%' THEN true
   ELSE metadata.visible END visible,
  CASE WHEN l.line->>'component'='base' THEN -1 WHEN l.line->>'component' LIKE 'advance:%' THEN 1000 ELSE COALESCE(metadata.display_order,999) END display_order
 FROM saved_lines l LEFT JOIN LATERAL(
  SELECT count(*)>0 AND bool_and(component->'version'->'data'->>'visible' IN('true','false')) AND count(DISTINCT component->'version'->'data'->>'visible')=1 AND count(component->'version'->'data'->>'visible')=count(*) known,
   bool_and(component->'version'->'data'->>'visible'='true') visible,
   min(CASE WHEN component->'version'->'data'->>'order' ~ '^[0-9]{1,3}$' THEN(component->'version'->'data'->>'order')::integer END) display_order
  FROM employee CROSS JOIN LATERAL jsonb_array_elements(employee.e->'lines') raw_line CROSS JOIN LATERAL jsonb_array_elements(raw_line->'details') part
  LEFT JOIN LATERAL(SELECT CASE
   WHEN part->>'component_version' IS NOT NULL THEN(SELECT input FROM jsonb_array_elements(p_manifest->'inputs') input WHERE input->'head'->>'kind'='component' AND input->'version'->>'id'=part->>'component_version' LIMIT 1)
   WHEN part->>'input_version' IS NOT NULL THEN(SELECT payroll.manifest_input(p_manifest,(input->'version'->'data'->>'component_id')::uuid,(p_manifest->'period'->>'starts_on')::date) FROM jsonb_array_elements(p_manifest->'inputs') input WHERE input->'head'->>'kind'='adjustment' AND input->'version'->>'id'=part->>'input_version' LIMIT 1)
   END component) version ON true
  WHERE raw_line->>'component'=l.line->>'component' AND raw_line->>'classification'=l.line->>'classification'
 ) metadata ON true)
 SELECT jsonb_build_object('complete',COALESCE(bool_and(known),true),'lines',COALESCE(jsonb_agg(jsonb_build_object('name',line->>'name','classification',line->>'classification','amount',line->>'amount') ORDER BY display_order,ordinal) FILTER(WHERE known AND visible),'[]')) FROM resolved
$f$;
REVOKE ALL ON FUNCTION payroll.report_payslip_lines(jsonb,jsonb,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION payroll.report_rows(p_tenant uuid,p_employer uuid,p_output uuid,p_report text,p_previous uuid,p_employee uuid,p_query text,p_site uuid,p_department uuid) RETURNS TABLE(row_id uuid,row_data jsonb) LANGUAGE plpgsql STABLE SET search_path='' AS $f$
BEGIN
 IF p_report='advances' THEN
  RETURN QUERY SELECT h.id,jsonb_build_object('id',h.id,'employee',jsonb_build_object('name',e.full_name,'code',e.employee_code),'recorded_principal',v.principal::text,'principal',CASE WHEN payroll.advance_status(h.tenant_id,h.id)='record_corrected' THEN NULL ELSE v.principal::text END,'outstanding',payroll.advance_balance(h.tenant_id,h.id)::text,'status',payroll.advance_status(h.tenant_id,h.id))
  FROM payroll.advance_heads h JOIN payroll.advance_versions v ON v.tenant_id=h.tenant_id AND v.id=h.version_id JOIN people.employments employment ON employment.tenant_id=h.tenant_id AND employment.id=h.employment_id AND employment.employer_entity_id=h.employer_id JOIN people.employees e ON e.tenant_id=employment.tenant_id AND e.id=employment.employee_id
  WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND h.status='active' AND(e.full_name ILIKE '%'||p_query||'%' OR e.employee_code ILIKE '%'||p_query||'%');RETURN;
 END IF;
 IF p_report='components' THEN
  RETURN QUERY SELECT md5(grouped.component||':'||grouped.classification)::uuid,jsonb_build_object('id',md5(grouped.component||':'||grouped.classification)::uuid,'label',grouped.name,'classification',grouped.classification,'status',grouped.classification,'amount',grouped.amount::text)
  FROM(SELECT line->>'component' component,line->>'classification' classification,max(line->>'name') name,sum((line->>'amount')::numeric) amount FROM payroll.final_employees f CROSS JOIN LATERAL jsonb_array_elements(f.explanation->'lines') line WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.output_id=p_output AND payroll.report_employment_matches(p_tenant,p_employer,f.output_id,f.employment_id,p_site,p_department) AND(p_employee IS NULL OR f.employment_id=p_employee) AND(f.employee_snapshot->>'name' ILIKE '%'||p_query||'%' OR f.employee_snapshot->>'code' ILIKE '%'||p_query||'%') GROUP BY line->>'component',line->>'classification')grouped;RETURN;
 END IF;
 IF p_report='variance' THEN
  RETURN QUERY WITH saved AS(
   SELECT f.output_id,f.employment_id,f.employee_snapshot,f.net,COALESCE((matched.person->'employment'->>'employee_id')::uuid,f.employment_id) employee_id
   FROM payroll.final_employees f JOIN payroll.final_contexts c ON c.tenant_id=f.tenant_id AND c.id=f.output_id LEFT JOIN LATERAL(SELECT person FROM jsonb_array_elements(c.manifest->'employees') person WHERE person->'employment'->>'id'=f.employment_id::text LIMIT 1)matched ON true
   WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.output_id IN(p_output,p_previous) AND payroll.report_employment_matches(p_tenant,p_employer,f.output_id,f.employment_id,p_site,p_department)
  ),current_rows AS(SELECT employee_id,sum(net) net,min(employment_id::text)::uuid employment_id,(array_agg(employee_snapshot ORDER BY employment_id))[1] employee FROM saved WHERE output_id=p_output GROUP BY employee_id),previous_rows AS(SELECT employee_id,sum(net) net,(array_agg(employee_snapshot ORDER BY employment_id))[1] employee FROM saved WHERE output_id=p_previous GROUP BY employee_id)
  SELECT COALESCE(c.employee_id,p.employee_id),jsonb_build_object('id',COALESCE(c.employee_id,p.employee_id),'detail_employment',c.employment_id,'employee',COALESCE(c.employee,p.employee),'net',c.net::text,'previous',p.net::text,'difference',CASE WHEN c.net IS NOT NULL AND p.net IS NOT NULL THEN(c.net-p.net)::text END,'status',CASE WHEN c.employee_id IS NULL THEN 'left' WHEN p.employee_id IS NULL THEN 'new' ELSE 'continuing' END)
  FROM current_rows c FULL JOIN previous_rows p ON p.employee_id=c.employee_id WHERE(COALESCE(c.employee,p.employee)->>'name' ILIKE '%'||p_query||'%' OR COALESCE(c.employee,p.employee)->>'code' ILIKE '%'||p_query||'%');RETURN;
 END IF;
 RETURN QUERY SELECT f.employment_id,jsonb_build_object('id',f.employment_id,'detail_employment',f.employment_id,'employee',f.employee_snapshot,'base',f.explanation->>'base','gross',f.explanation->>'gross','deductions',f.explanation->>'deductions','statutory_deductions',f.explanation->>'statutory_deductions','net',f.net::text,'paid',b.paid::text,'remaining',b.remaining::text,'insured_wage',CASE WHEN p_report='statutory' THEN f.statutory_context->>'insured_wage' END,'statutory_context',CASE WHEN p_report='statutory' THEN jsonb_build_object('calendar_year',f.statutory_context->'calendar_year','category',f.statutory_context->'category','insured_wage_source',f.statutory_context->'insured_wage_source','obligation_months',f.statutory_context->'obligation_months','insured_wage',f.statutory_context->'insured_wage') END,'visibility_complete',CASE WHEN p_report='payslip' THEN(payslip.presentation->>'complete')::boolean ELSE true END,'lines',CASE WHEN p_report='payslip' THEN payslip.presentation->'lines' ELSE(SELECT COALESCE(jsonb_agg(jsonb_build_object('name',line->>'name','classification',line->>'classification','amount',line->>'amount') ORDER BY ord),'[]') FROM jsonb_array_elements(f.explanation->'lines') WITH ORDINALITY x(line,ord)) END)
 FROM payroll.final_employees f JOIN payroll.final_contexts context ON context.tenant_id=f.tenant_id AND context.id=f.output_id LEFT JOIN LATERAL(SELECT payroll.report_payslip_lines(context.manifest,context.result,f.employment_id,f.explanation) presentation WHERE p_report='payslip') payslip ON true LEFT JOIN payroll.payment_balances(p_tenant,p_output) b ON b.employment_id=f.employment_id AND p_report='payments' WHERE f.tenant_id=p_tenant AND f.employer_id=p_employer AND f.output_id=p_output AND payroll.report_employment_matches(p_tenant,p_employer,f.output_id,f.employment_id,p_site,p_department) AND(p_employee IS NULL OR f.employment_id=p_employee) AND(f.employee_snapshot->>'name' ILIKE '%'||p_query||'%' OR f.employee_snapshot->>'code' ILIKE '%'||p_query||'%');
END $f$;
REVOKE ALL ON FUNCTION payroll.report_authorized(uuid,text,boolean),payroll.report_rows(uuid,uuid,uuid,text,uuid,uuid,text,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_report_choices(uuid,uuid,uuid,uuid[],text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_report_choices(uuid,uuid,uuid,uuid[],text) TO authenticated;

CREATE FUNCTION payroll.report_revision(p_tenant uuid,p_employer uuid,p_output uuid,p_report text,p_previous uuid,p_employee uuid,p_query text,p_site uuid,p_department uuid) RETURNS text LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT md5(jsonb_build_object('tenant',p_tenant,'employer',p_employer,'output',p_output,'report',p_report,'previous',p_previous,'employee',p_employee,'query',p_query,'site',p_site,'department',p_department,
  'succession',(SELECT jsonb_agg(to_jsonb(s) ORDER BY original_output) FROM payroll.output_successions s WHERE s.tenant_id=p_tenant AND s.original_output IN(p_output,p_previous)),
  'payments',CASE WHEN p_report='payments' THEN COALESCE((SELECT revision FROM payroll.payment_heads WHERE tenant_id=p_tenant AND output_id=p_output),0) END,
  'finance_employer',CASE WHEN p_report='advances' THEN(SELECT jsonb_build_object('name',display_name,'legal_name',legal_name) FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer) END,
  'finance',CASE WHEN p_report='advances' THEN(SELECT jsonb_agg(jsonb_build_object('head',h.id,'revision',h.revision,'version',h.version_id,'status',h.status,'name',e.full_name,'code',e.employee_code) ORDER BY h.id) FROM payroll.advance_heads h JOIN people.employments employment ON employment.tenant_id=h.tenant_id AND employment.id=h.employment_id AND employment.employer_entity_id=h.employer_id JOIN people.employees e ON e.tenant_id=employment.tenant_id AND e.id=employment.employee_id WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer) END)::text)
$f$;
CREATE FUNCTION public.payroll_report_workspace(p_tenant uuid,p_employer uuid,p_output uuid,p_report text,p_previous uuid DEFAULT NULL,p_employee uuid DEFAULT NULL,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_limit integer DEFAULT 30,p_expected_revision text DEFAULT NULL,p_export boolean DEFAULT false,p_site uuid DEFAULT NULL,p_department uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;c payroll.final_contexts%ROWTYPE;prior payroll.final_contexts%ROWTYPE;employer jsonb;period jsonb;items jsonb;summary jsonb;issues jsonb:='[]';source text;total_count integer;replacement uuid;has_more boolean;last_id uuid;BEGIN
 actor:=payroll.report_authorized(p_tenant,p_report,p_export);
 IF p_query IS NULL OR length(p_query)>120 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR(p_report IN('advances','variance') AND p_employee IS NOT NULL) THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
 IF p_report='advances' THEN
  IF p_output IS NOT NULL OR p_previous IS NOT NULL OR p_site IS NOT NULL OR p_department IS NOT NULL THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
  SELECT jsonb_build_object('name',display_name,'legal_name',legal_name) INTO employer FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 ELSE
  SELECT * INTO c FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
  IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  employer:=jsonb_build_object('name',c.legal_employer->>'display_name','legal_name',c.legal_employer->>'legal_name');period:=jsonb_build_object('starts_on',c.period_snapshot->>'starts_on','ends_on',c.period_snapshot->>'ends_on');
  SELECT replacement_output INTO replacement FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output;
  IF replacement IS NOT NULL THEN IF p_export THEN RAISE EXCEPTION 'payroll_output_superseded' USING ERRCODE='23514';END IF;issues:=issues||'"superseded"'::jsonb;END IF;
  IF p_employee IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.final_employees WHERE tenant_id=p_tenant AND employer_id=p_employer AND output_id=p_output AND employment_id=p_employee) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 END IF;
 IF p_site IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.final_contexts saved CROSS JOIN LATERAL jsonb_array_elements(saved.manifest->'assignments') assignment WHERE saved.tenant_id=p_tenant AND saved.employer_id=p_employer AND saved.id IN(p_output,CASE WHEN p_report='variance' THEN p_previous END) AND assignment->>'site_id'=p_site::text) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_department IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.final_contexts saved CROSS JOIN LATERAL jsonb_array_elements(saved.manifest->'assignments') assignment WHERE saved.tenant_id=p_tenant AND saved.employer_id=p_employer AND saved.id IN(p_output,CASE WHEN p_report='variance' THEN p_previous END) AND assignment->>'department_id'=p_department::text) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 IF p_report='variance' THEN
  IF p_previous IS NULL THEN issues:=issues||'"previous_missing"'::jsonb;
  ELSE
   SELECT * INTO prior FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_previous;
   IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
   IF(prior.period_snapshot->>'ends_on')::date>=(c.period_snapshot->>'starts_on')::date OR EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_previous) THEN RAISE EXCEPTION 'payroll_report_previous_invalid' USING ERRCODE='23514';END IF;
  END IF;
 ELSIF p_previous IS NOT NULL THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
 source:=payroll.report_revision(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department);
 IF p_expected_revision IS NOT NULL AND p_expected_revision<>source THEN RAISE EXCEPTION 'payroll_report_source_changed' USING ERRCODE='PT409';END IF;
 SELECT count(*) INTO total_count FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department);
 SELECT COALESCE(jsonb_agg(row_data ORDER BY row_id),'[]') INTO items FROM(SELECT row_id,row_data FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department) WHERE(p_after IS NULL OR row_id>p_after) ORDER BY row_id LIMIT p_limit)x;
 IF jsonb_array_length(items)>0 THEN last_id:=(items->(jsonb_array_length(items)-1)->>'id')::uuid;END IF;
 SELECT EXISTS(SELECT 1 FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department) WHERE last_id IS NOT NULL AND row_id>last_id) INTO has_more;
 SELECT jsonb_build_object(
  'base',CASE WHEN count(*)>0 AND count(row_data->>'base')=count(*) THEN sum((row_data->>'base')::numeric)::text END,
  'gross',CASE WHEN count(*)>0 AND count(row_data->>'gross')=count(*) THEN sum((row_data->>'gross')::numeric)::text END,
  'deductions',CASE WHEN count(*)>0 AND count(row_data->>'deductions')=count(*) THEN sum((row_data->>'deductions')::numeric)::text END,
  'statutory_deductions',CASE WHEN count(*)>0 AND count(row_data->>'statutory_deductions')=count(*) THEN sum((row_data->>'statutory_deductions')::numeric)::text END,
  'previous',CASE WHEN p_report='variance' AND p_previous IS NOT NULL THEN COALESCE(sum((row_data->>'previous')::numeric),0)::text END,
  'net',CASE WHEN count(*)>0 AND count(row_data->>'net')=count(*) THEN sum((row_data->>'net')::numeric)::text END,
  'paid',CASE WHEN p_report='payments' THEN COALESCE(sum((row_data->>'paid')::numeric),0)::text END,
  'remaining',CASE WHEN p_report='payments' THEN COALESCE(sum((row_data->>'remaining')::numeric),0)::text END,
  'principal',CASE WHEN p_report='advances' THEN COALESCE(sum((row_data->>'principal')::numeric),0)::text END,
  'outstanding',CASE WHEN p_report='advances' THEN COALESCE(sum((row_data->>'outstanding')::numeric),0)::text END,
  'difference',CASE WHEN p_report='variance' AND p_previous IS NOT NULL THEN(COALESCE(sum((row_data->>'net')::numeric),0)-COALESCE(sum((row_data->>'previous')::numeric),0))::text END
 ) INTO summary FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department);
 IF p_report='payments' THEN summary:=jsonb_build_object('net',summary->'net','paid',summary->'paid','remaining',summary->'remaining');
 ELSIF p_report='variance' THEN
  SELECT jsonb_build_object('net',COALESCE(sum((row_data->>'net')::numeric),0)::text,'previous',CASE WHEN p_previous IS NOT NULL THEN COALESCE(sum((row_data->>'previous')::numeric),0)::text END,'difference',CASE WHEN p_previous IS NOT NULL THEN(COALESCE(sum((row_data->>'net')::numeric),0)-COALESCE(sum((row_data->>'previous')::numeric),0))::text END) INTO summary FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department);
 ELSIF p_report='advances' THEN summary:=jsonb_build_object('principal',summary->'principal','outstanding',summary->'outstanding');
 ELSIF p_report='components' THEN
  SELECT jsonb_build_object('gross',COALESCE(sum((row_data->>'amount')::numeric) FILTER(WHERE row_data->>'classification'='earning'),0)::text,'deductions',COALESCE(sum((row_data->>'amount')::numeric) FILTER(WHERE row_data->>'classification'='deduction'),0)::text,'employer_cost',COALESCE(sum((row_data->>'amount')::numeric) FILTER(WHERE row_data->>'classification'='employer_cost'),0)::text) INTO summary FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department);
 ELSE summary:=jsonb_build_object('base',summary->'base','gross',summary->'gross','deductions',summary->'deductions','statutory_deductions',summary->'statutory_deductions','net',summary->'net');END IF;
 IF p_report IN('sheet','payslip','statutory') AND EXISTS(SELECT 1 FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department) WHERE row_data->>'statutory_deductions' IS NULL) THEN issues:=issues||'"statutory_missing"'::jsonb;END IF;
 IF p_report='statutory' THEN
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(c.manifest->'packs') pack WHERE pack->>'state'='verified') OR EXISTS(SELECT 1 FROM jsonb_array_elements(c.manifest->'packs') pack WHERE pack->>'state' IS DISTINCT FROM 'verified') THEN issues:=issues||'"statutory_pack_unqualified"'::jsonb;END IF;
  IF EXISTS(SELECT 1 FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department) WHERE row_data->'statutory_context'->>'calendar_year' IS NULL OR row_data->'statutory_context'->>'category' IS NULL OR row_data->'statutory_context'->>'insured_wage_source' IS NULL OR row_data->>'insured_wage' IS NULL OR jsonb_typeof(row_data->'statutory_context'->'obligation_months') IS DISTINCT FROM 'array') THEN issues:=issues||'"statutory_basis_missing"'::jsonb;END IF;
 END IF;
 IF p_report='payslip' AND EXISTS(SELECT 1 FROM payroll.report_rows(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department) WHERE row_data->>'visibility_complete' IS DISTINCT FROM 'true') THEN issues:=issues||'"payslip_metadata_missing"'::jsonb;END IF;
 IF p_export AND jsonb_array_length(issues)>0 THEN RAISE EXCEPTION 'payroll_report_incomplete' USING ERRCODE='23514';END IF;
 IF source<>payroll.report_revision(p_tenant,p_employer,p_output,p_report,p_previous,p_employee,p_query,p_site,p_department) THEN RAISE EXCEPTION 'payroll_report_source_changed' USING ERRCODE='PT409';END IF;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,actor,CASE WHEN p_export THEN 'report_export_access' ELSE 'report_access' END,jsonb_build_object('report',p_report,'output',p_output,'previous',p_previous,'employee',p_employee,'site',p_site,'department',p_department,'after',p_after,'count',jsonb_array_length(items),'total_count',total_count,'source_revision',source));
 PERFORM payroll.report_authorized(p_tenant,p_report,p_export);
 RETURN jsonb_build_object('statutory_sources',CASE WHEN p_report='statutory' THEN(SELECT COALESCE(jsonb_agg(jsonb_build_object('version',pack->>'version','effective_from',pack->>'effective_from','effective_until',pack->>'effective_until','verified',pack->>'state'='verified') ORDER BY pack->>'effective_from',pack->>'id'),'[]') FROM jsonb_array_elements(c.manifest->'packs') pack) END,'filters',jsonb_build_object('site',p_site,'department',p_department),'report',p_report,'output_id',p_output,'employer',employer,'period',period,'previous_period',CASE WHEN prior.id IS NOT NULL THEN jsonb_build_object('starts_on',prior.period_snapshot->>'starts_on','ends_on',prior.period_snapshot->>'ends_on') END,'superseded',replacement IS NOT NULL,'replacement_output_id',replacement,'rows',items,'next',CASE WHEN has_more THEN last_id END,'total_count',total_count,'summary',summary,'issues',issues,'source_revision',source,'can_export',platform_private.has_tenant_permission(p_tenant,actor,'payroll.export'));
END $f$;
REVOKE ALL ON FUNCTION payroll.report_revision(uuid,uuid,uuid,text,uuid,uuid,text,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_report_workspace(uuid,uuid,uuid,text,uuid,uuid,text,uuid,integer,text,boolean,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_report_workspace(uuid,uuid,uuid,text,uuid,uuid,text,uuid,integer,text,boolean,uuid,uuid) TO authenticated;

CREATE FUNCTION public.payroll_report_employers(p_tenant uuid,p_report text,p_query text DEFAULT '',p_after_name text DEFAULT NULL,p_after_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;items jsonb;BEGIN
 actor:=payroll.report_authorized(p_tenant,p_report,false);
 IF p_query IS NULL OR length(p_query)>120 OR(p_after_name IS NULL)<>(p_after_id IS NULL) THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
 SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY name,id),'[]') INTO items FROM(SELECT e.id,e.display_name name FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant AND e.display_name ILIKE '%'||p_query||'%' AND(p_after_id IS NULL OR(e.display_name,e.id)>(p_after_name,p_after_id)) AND((p_report='advances' AND EXISTS(SELECT 1 FROM payroll.advance_heads h WHERE h.tenant_id=e.tenant_id AND h.employer_id=e.id AND h.status='active')) OR(p_report<>'advances' AND EXISTS(SELECT 1 FROM payroll.final_contexts f WHERE f.tenant_id=e.tenant_id AND f.employer_id=e.id))) ORDER BY e.display_name,e.id LIMIT 30)x;
 PERFORM payroll.report_authorized(p_tenant,p_report,false);
 RETURN jsonb_build_object('items',items);
END $f$;
REVOKE ALL ON FUNCTION public.payroll_report_employers(uuid,text,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_report_employers(uuid,text,text,text,uuid) TO authenticated;


-- Reference labels are current; frozen assignment identifiers govern membership.
CREATE FUNCTION public.payroll_report_dimensions(p_tenant uuid,p_employer uuid,p_output uuid,p_report text,p_kind text,p_previous uuid DEFAULT NULL,p_query text DEFAULT '',p_after uuid DEFAULT NULL,p_selected uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;items jsonb;selected jsonb;BEGIN
 actor:=payroll.report_authorized(p_tenant,p_report,false);
 IF p_report='advances' OR p_kind IS NULL OR p_kind NOT IN('site','department') OR p_query IS NULL OR length(p_query)>120 THEN RAISE EXCEPTION 'payroll_report_invalid' USING ERRCODE='22023';END IF;
 IF NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output) OR(p_previous IS NOT NULL AND(p_report<>'variance' OR NOT EXISTS(SELECT 1 FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_previous))) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 WITH saved AS(SELECT DISTINCT (assignment->>(CASE WHEN p_kind='site' THEN 'site_id' ELSE 'department_id' END))::uuid id FROM payroll.final_contexts c CROSS JOIN LATERAL jsonb_array_elements(c.manifest->'assignments') assignment WHERE c.tenant_id=p_tenant AND c.employer_id=p_employer AND c.id IN(p_output,p_previous)),choices AS(SELECT s.id,CASE WHEN p_kind='site' THEN site.display_name ELSE department.name END name FROM saved s LEFT JOIN platform_core.tenant_sites site ON p_kind='site' AND site.tenant_id=p_tenant AND site.legal_entity_id=p_employer AND site.id=s.id LEFT JOIN people.departments department ON p_kind='department' AND department.tenant_id=p_tenant AND department.id=s.id WHERE s.id IS NOT NULL)
 SELECT COALESCE(jsonb_agg(jsonb_build_object('id',id,'name',COALESCE(name,'مرجع محفوظ بلا اسم متاح')) ORDER BY id),'[]') INTO items FROM(SELECT * FROM choices WHERE(p_after IS NULL OR id>p_after) AND COALESCE(name,'') ILIKE '%'||p_query||'%' ORDER BY id LIMIT 30)page;
 IF p_selected IS NOT NULL THEN
  IF NOT EXISTS(SELECT 1 FROM payroll.final_contexts c CROSS JOIN LATERAL jsonb_array_elements(c.manifest->'assignments') assignment WHERE c.tenant_id=p_tenant AND c.employer_id=p_employer AND c.id IN(p_output,p_previous) AND assignment->>(CASE WHEN p_kind='site' THEN 'site_id' ELSE 'department_id' END)=p_selected::text) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
  SELECT jsonb_build_object('id',p_selected,'name',COALESCE(CASE WHEN p_kind='site' THEN(SELECT display_name FROM platform_core.tenant_sites WHERE tenant_id=p_tenant AND legal_entity_id=p_employer AND id=p_selected) ELSE(SELECT name FROM people.departments WHERE tenant_id=p_tenant AND id=p_selected) END,'مرجع محفوظ بلا اسم متاح')) INTO selected;
 END IF;
 PERFORM payroll.report_authorized(p_tenant,p_report,false);
 RETURN jsonb_build_object('items',items,'selected',selected,'next',CASE WHEN jsonb_array_length(items)=30 THEN items->29->>'id' END);
END $f$;
REVOKE ALL ON FUNCTION public.payroll_report_dimensions(uuid,uuid,uuid,text,text,uuid,text,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_report_dimensions(uuid,uuid,uuid,text,text,uuid,text,uuid,uuid) TO authenticated;
