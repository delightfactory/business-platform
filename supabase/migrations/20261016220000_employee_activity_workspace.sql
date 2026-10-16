-- Specific, bounded history for the company employee profile. Each section keeps
-- its existing permission boundary; People access never grants financial access.
-- SECURITY DEFINER is required because these source tables intentionally have
-- no authenticated SELECT grants. No source-table privileges are added here.
CREATE FUNCTION public.people_employee_activity(
  p_tenant uuid,p_employee uuid,p_kind text,p_after uuid DEFAULT NULL,p_limit integer DEFAULT 20
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE
  actor uuid:=auth.uid(); items jsonb; more boolean; valid_cursor boolean; employer uuid;
BEGIN
  IF actor IS NULL OR NOT platform_private.has_people_permission(p_tenant,actor,'people.view') THEN
    RAISE EXCEPTION 'employee_activity_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN('attendance','leave','payroll','advances')
    OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 30 THEN
    RAISE EXCEPTION 'employee_activity_invalid' USING ERRCODE='22023';
  END IF;
  CASE p_kind
    WHEN 'attendance' THEN PERFORM public.time_attendance_access_snapshot(p_tenant);
    WHEN 'leave' THEN
      IF NOT leave.request_hr_can_read(p_tenant,actor) THEN
        RAISE EXCEPTION 'leave_forbidden' USING ERRCODE='42501';
      END IF;
      PERFORM leave.authorized(p_tenant,CASE
        WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view') THEN 'leave.view'
        WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage') THEN 'leave.manage'
        ELSE 'leave.approve' END,false);
    WHEN 'payroll' THEN PERFORM payroll.authorized(p_tenant,'payroll.view',false);
    WHEN 'advances' THEN PERFORM payroll.advance_authorized(p_tenant,'view');
  END CASE;
  IF NOT EXISTS(SELECT 1 FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee) THEN
    RAISE EXCEPTION 'employee_activity_forbidden' USING ERRCODE='42501';
  END IF;

  -- A record id is the cursor, not an untrusted date or a text-search code.
  -- The cursor must occur in this exact tenant, employee and section. Date/id
  -- ordering is deterministic, including tied dates and historical rehires.
  WITH sources AS NOT MATERIALIZED (
    SELECT i.id,i.operational_date AS sort_date,jsonb_build_object(
      'id',i.id,'employment_id',emp.id,'employer_id',emp.employer_entity_id,
      'date',i.operational_date,'operational_date',i.operational_date,'state',i.status,
      'expected_start',i.expected_start,'expected_end',i.expected_end,
      'first_in',latest.first_in,'last_out',latest.last_out,'worked_minutes',latest.worked_minutes
    ) AS item
    FROM time.work_instances i
    JOIN people.employments emp ON emp.tenant_id=i.tenant_id AND emp.id=i.employment_id
      AND emp.employee_id=i.employee_id
    LEFT JOIN LATERAL(SELECT x.first_in,x.last_out,x.worked_minutes FROM time.interpretations x
      WHERE x.tenant_id=i.tenant_id AND x.work_instance_id=i.id ORDER BY x.version DESC LIMIT 1) latest ON true
    WHERE p_kind='attendance' AND i.tenant_id=p_tenant AND i.employee_id=p_employee
    UNION ALL
    SELECT r.id,r.start_date,jsonb_build_object(
      'id',r.id,'employment_id',emp.id,'employer_id',emp.employer_entity_id,
      'date',r.start_date,'end_date',r.end_date,'state',r.state,'type_name',t.name,
      'total_units',preview.total_units::text,'is_half_day',r.is_half_day
    ) FROM leave.requests r
    JOIN people.employments emp ON emp.tenant_id=r.tenant_id AND emp.id=r.employment_id
      AND emp.employee_id=r.employee_id AND emp.employer_entity_id=r.employer_entity_id
    JOIN leave.types t ON t.tenant_id=r.tenant_id AND t.id=r.leave_type_id
      AND t.employer_entity_id=r.employer_entity_id
    JOIN leave.request_previews preview ON preview.tenant_id=r.tenant_id AND preview.request_id=r.id
      AND preview.preview_version=r.current_preview_version
    WHERE p_kind='leave' AND r.tenant_id=p_tenant AND r.employee_id=p_employee
    UNION ALL
    SELECT c.id,p.starts_on,jsonb_build_object(
      'id',c.id,'output_id',c.id,'run_id',c.run_id,'period_id',p.id,'employer_id',c.employer_id,
      'employment_ids',jsonb_agg(f.employment_id ORDER BY f.employment_id),
      'date',p.starts_on,'end_date',p.ends_on,'starts_on',p.starts_on,'ends_on',p.ends_on,
      'net',sum(f.net)::text,'state',CASE WHEN EXISTS(SELECT 1 FROM payroll.output_successions s
        WHERE s.tenant_id=c.tenant_id AND s.original_output=c.id) THEN 'superseded' ELSE 'final' END
    ) FROM payroll.final_contexts c
    JOIN payroll.periods p ON p.tenant_id=c.tenant_id AND p.id=c.period_id AND p.employer_id=c.employer_id
    JOIN payroll.final_employees f ON f.tenant_id=c.tenant_id AND f.output_id=c.id AND f.employer_id=c.employer_id
    JOIN people.employments emp ON emp.tenant_id=f.tenant_id AND emp.id=f.employment_id
      AND emp.employer_entity_id=f.employer_id
    WHERE p_kind='payroll' AND c.tenant_id=p_tenant AND emp.employee_id=p_employee
    GROUP BY c.tenant_id,c.id,c.run_id,c.employer_id,p.id,p.starts_on,p.ends_on
    UNION ALL
    SELECT h.id,(v.created_at AT TIME ZONE 'Africa/Cairo')::date,jsonb_build_object(
      'id',h.id,'employment_id',emp.id,'employer_id',emp.employer_entity_id,
      'date',(v.created_at AT TIME ZONE 'Africa/Cairo')::date,
      'state',payroll.advance_status(p_tenant,h.id),'principal',v.principal::text,
      'outstanding',payroll.advance_balance(p_tenant,h.id)::text
    ) FROM payroll.advance_heads h
    JOIN payroll.advance_versions v ON v.tenant_id=h.tenant_id AND v.advance_id=h.id AND v.id=h.version_id
    JOIN people.employments emp ON emp.tenant_id=h.tenant_id AND emp.id=h.employment_id
      AND emp.employer_entity_id=h.employer_id
    WHERE p_kind='advances' AND h.tenant_id=p_tenant AND emp.employee_id=p_employee
  ), cursor_row AS MATERIALIZED (
    SELECT id,sort_date FROM sources WHERE id=p_after
  ), batch AS MATERIALIZED (
    SELECT s.* FROM sources s WHERE p_after IS NULL
      OR (s.sort_date,s.id)<(SELECT c.sort_date,c.id FROM cursor_row c)
    ORDER BY s.sort_date DESC,s.id DESC LIMIT p_limit+1
  ), visible AS (
    SELECT * FROM batch ORDER BY sort_date DESC,id DESC LIMIT p_limit
  )
  SELECT coalesce((SELECT jsonb_agg(v.item ORDER BY v.sort_date DESC,v.id DESC) FROM visible v),'[]'),
    (SELECT count(*)>p_limit FROM batch),p_after IS NULL OR EXISTS(SELECT 1 FROM cursor_row)
    INTO items,more,valid_cursor;
  IF NOT valid_cursor THEN
    RAISE EXCEPTION 'employee_activity_cursor_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_kind='payroll' THEN
    -- Final financial reads retain the audit contract of payroll_final_output.
    -- One event per employer contains only returned output ids and this employee.
    FOR employer IN SELECT DISTINCT (x->>'employer_id')::uuid FROM jsonb_array_elements(items)x LOOP
      INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)
      VALUES(p_tenant,employer,actor,'employee_final_history_access',jsonb_build_object(
        'employee',p_employee,'after',p_after,'outputs',(SELECT jsonb_agg(x->'output_id')
          FROM jsonb_array_elements(items)x WHERE (x->>'employer_id')::uuid=employer)));
    END LOOP;
    PERFORM payroll.authorized(p_tenant,'payroll.view',false);
  END IF;
  RETURN jsonb_build_object('kind',p_kind,'employee_id',p_employee,'items',items,'has_more',more,
    'next_after',CASE WHEN more THEN items->(jsonb_array_length(items)-1)->>'id' END,'limit',p_limit);
END $f$;
REVOKE ALL ON FUNCTION public.people_employee_activity(uuid,uuid,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_activity(uuid,uuid,text,uuid,integer) TO authenticated;
