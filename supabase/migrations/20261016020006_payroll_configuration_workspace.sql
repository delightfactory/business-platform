-- Configuration is dated by its own versions, not by a selected payroll period.
CREATE FUNCTION public.payroll_configuration_workspace(
 p_tenant uuid,p_employer uuid,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 30,
 p_head uuid DEFAULT NULL,p_query text DEFAULT ''
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE access jsonb; components jsonb; policy jsonb; selected jsonb;
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
 RETURN jsonb_build_object('access',access,'employer_name',employer_name,'components',components,
  'has_more',more,'policy',policy,'selected',selected,'component_open_ended_min',component_min,'policy_open_ended_min',policy_min);
END $f$;
REVOKE ALL ON FUNCTION public.payroll_configuration_workspace(uuid,uuid,uuid,integer,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_configuration_workspace(uuid,uuid,uuid,integer,uuid,text) TO authenticated;
