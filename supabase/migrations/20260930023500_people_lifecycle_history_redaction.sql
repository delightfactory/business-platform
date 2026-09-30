CREATE OR REPLACE FUNCTION public.people_employment_history(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.view') THEN
    RAISE EXCEPTION 'people_view_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM people.employees e WHERE e.tenant_id=p_tenant_id AND e.id=p_employee_id) THEN
    RAISE EXCEPTION 'people_employee_not_found' USING ERRCODE='P0002';
  END IF;
  SELECT pg_catalog.jsonb_build_object('items',COALESCE(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object('id',e.id,'employer',le.display_name,'start_date',e.start_date,
      'end_date',e.end_date,'status',e.employment_status,'pay_basis',e.pay_basis)
    ORDER BY e.start_date DESC,e.id DESC),'[]'::jsonb),
    'events',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'event',a.event_key,'created_at',a.created_at,
      'details',CASE WHEN a.event_key='employment.ended' THEN pg_catalog.jsonb_build_object(
        'before',a.details->'before','after',a.details->'after',
        'cancelled_future_assignment_count',COALESCE(pg_catalog.jsonb_array_length(a.details->'cancelled_future_assignments'),0),
        'cancelled_future_compensation_count',COALESCE(pg_catalog.jsonb_array_length(a.details->'cancelled_future_compensation'),0),
        'handoff_required',a.details->'handoff_required')
        ELSE pg_catalog.jsonb_build_object('before',a.details->'before','after',a.details->'after',
          'handoff_required',a.details->'handoff_required') END)
      ORDER BY a.created_at DESC,a.id DESC) FROM (
        SELECT * FROM people.employment_lifecycle_audit_events
        WHERE tenant_id=p_tenant_id AND employee_id=p_employee_id
        ORDER BY created_at DESC,id DESC LIMIT 100
      ) a),'[]'::jsonb),
    'events_truncated',(SELECT pg_catalog.count(*)>100 FROM people.employment_lifecycle_audit_events
      WHERE tenant_id=p_tenant_id AND employee_id=p_employee_id))
  INTO v_result
  FROM people.employments e
  JOIN platform_core.tenant_legal_entities le ON le.tenant_id=e.tenant_id AND le.id=e.employer_entity_id
  WHERE e.tenant_id=p_tenant_id AND e.employee_id=p_employee_id;
  RETURN COALESCE(v_result,pg_catalog.jsonb_build_object('items','[]'::jsonb,'events','[]'::jsonb,'events_truncated',false));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employment_history(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employment_history(uuid,uuid) TO authenticated;
