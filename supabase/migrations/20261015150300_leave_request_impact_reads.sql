-- Read-only request impact. Submission/approval remain the authoritative write paths.
CREATE FUNCTION leave.request_impact_read(p_tenant uuid,p_employee uuid,p_employer uuid,p_employment uuid,
 p_type uuid,p_start date,p_end date,p_half_day boolean,p_part text,p_show_balance boolean)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE computed jsonb; input jsonb; reason text; day jsonb; days jsonb:='[]';
 accounts jsonb:='[]'; remaining jsonb:='{}'; account record; need numeric; take_units numeric;
 total_tracked numeric:=0; available numeric:=0; shortfall numeric:=0; balance_now numeric; balance jsonb;
BEGIN
 input:=pg_catalog.jsonb_build_object('type',p_type,'start',p_start,'end',p_end,'half_day',p_half_day,'part',p_part);
 BEGIN
  computed:=leave.request_preview_with_mapping(p_tenant,p_employer,p_employment,p_type,p_start,p_end,p_half_day,p_part);
 EXCEPTION WHEN foreign_key_violation OR check_violation THEN
  reason:=CASE SQLERRM WHEN 'leave_type_unavailable' THEN 'type'
   WHEN 'leave_year_period_unavailable' THEN 'year_period'
   WHEN 'leave_calendar_unavailable' THEN 'calendar'
   WHEN 'leave_calendar_version_unavailable' THEN 'calendar'
   WHEN 'leave_type_version_unavailable' THEN 'type_version'
   WHEN 'leave_half_day_not_allowed' THEN 'half_day_not_allowed'
   WHEN 'leave_half_day_ineligible' THEN 'half_day_ineligible'
   WHEN 'leave_request_zero_days' THEN 'zero_days' END;
  IF reason IS NULL THEN RAISE; END IF;
  RETURN pg_catalog.jsonb_build_object('state','unavailable','reason',reason,'input',input,'pending_not_reserved',true);
 END;
 FOR day IN SELECT value FROM pg_catalog.jsonb_array_elements(computed->'days') LOOP
  days:=days||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('date',day->>'leave_date',
   'eligible',day->'eligible','units',pg_catalog.round((day->>'units')::numeric,2)::text,
   'is_weekly_rest',day->'is_weekly_rest','holiday_name',day->'holiday_name',
   'pay_effect',day->>'pay_effect','balance_mode',day->>'balance_mode','halfday_state',day->'halfday_mapping_state'));
  IF (day->>'eligible')::boolean AND day->>'balance_mode'='tracked' THEN
   total_tracked:=total_tracked+(day->>'units')::numeric;
  END IF;
 END LOOP;
 IF total_tracked=0 THEN balance:=pg_catalog.jsonb_build_object('state','not_tracked');
 ELSIF NOT p_show_balance THEN balance:=pg_catalog.jsonb_build_object('state','hidden');
 ELSE
  -- Same account eligibility and FIFO order as leave_approve_request; no lock or ledger mutation.
  FOR account IN SELECT ac.id,yp.starts_on,yp.ends_on,yp.label,
    coalesce((SELECT pg_catalog.sum(le.delta_days) FROM leave.ledger_entries le
     WHERE le.tenant_id=p_tenant AND le.account_id=ac.id),0) AS balance_days
   FROM leave.accounts ac JOIN leave.year_periods yp ON yp.tenant_id=ac.tenant_id AND yp.id=ac.year_period_id
   WHERE ac.tenant_id=p_tenant AND ac.employee_id=p_employee AND ac.employer_entity_id=p_employer
    AND ac.leave_type_id=p_type AND yp.starts_on<=p_end ORDER BY yp.starts_on,ac.id
  LOOP
   IF account.balance_days<0 THEN RAISE EXCEPTION 'leave_balance_invariant_violation' USING ERRCODE='23514'; END IF;
   remaining:=remaining||pg_catalog.jsonb_build_object(account.id::text,account.balance_days);
   available:=available+account.balance_days;
   accounts:=accounts||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('period_label',account.label,
    'starts_on',account.starts_on,'ends_on',account.ends_on,'balance_days',pg_catalog.round(account.balance_days,2)::text));
  END LOOP;
  FOR day IN SELECT value FROM pg_catalog.jsonb_array_elements(computed->'days') ORDER BY value->>'leave_date' LOOP
   IF NOT (day->>'eligible')::boolean OR day->>'balance_mode'='untracked' THEN CONTINUE; END IF;
   need:=(day->>'units')::numeric;
   FOR account IN SELECT ac.id FROM leave.accounts ac JOIN leave.year_periods yp
    ON yp.tenant_id=ac.tenant_id AND yp.id=ac.year_period_id
    WHERE ac.tenant_id=p_tenant AND ac.employee_id=p_employee AND ac.employer_entity_id=p_employer
     AND ac.leave_type_id=p_type AND yp.starts_on<=(day->>'leave_date')::date ORDER BY yp.starts_on,ac.id
   LOOP
    balance_now:=(remaining->>account.id::text)::numeric;
    take_units:=least(need,balance_now);
    remaining:=remaining||pg_catalog.jsonb_build_object(account.id::text,balance_now-take_units);
    need:=need-take_units;
    EXIT WHEN need=0;
   END LOOP;
   shortfall:=shortfall+need;
  END LOOP;
  balance:=pg_catalog.jsonb_build_object('state','shown','accounts',accounts,
   'available_days',pg_catalog.round(available,2)::text,'shortfall_days',pg_catalog.round(shortfall,2)::text,
   'after_approval_days',CASE WHEN shortfall=0 THEN pg_catalog.round(available-total_tracked,2)::text ELSE NULL END);
 END IF;
 RETURN pg_catalog.jsonb_build_object('state','ready','input',input,
  'total_units',pg_catalog.round((computed->>'total_units')::numeric,2)::text,
  'tracked_units',pg_catalog.round(total_tracked,2)::text,'days',days,'balance',balance,'pending_not_reserved',true);
END $f$;
REVOKE ALL ON FUNCTION leave.request_impact_read(uuid,uuid,uuid,uuid,uuid,date,date,boolean,text,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_my_request_preview(p_tenant uuid,p_type uuid,p_start date,p_end date,p_half_day boolean,p_half_day_part text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employee uuid; employment people.employments%ROWTYPE;
BEGIN
 IF actor IS NULL OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN
  RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501'; END IF;
 IF p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731 OR p_half_day IS NULL
  OR (p_half_day AND p_start<>p_end) THEN RAISE EXCEPTION 'leave_request_range_invalid' USING ERRCODE='22023'; END IF;
 IF (p_half_day_part IS NOT NULL AND p_half_day_part NOT IN ('first','second'))
  OR (NOT p_half_day AND p_half_day_part IS NOT NULL) THEN RAISE EXCEPTION 'leave_half_day_part_invalid' USING ERRCODE='22023'; END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
  OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now()) THEN
  RAISE EXCEPTION 'leave_new_work_disabled' USING ERRCODE='55000'; END IF;
 SELECT l.employee_id INTO employee FROM people.employee_user_links l
  WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
 IF employee IS NULL THEN RAISE EXCEPTION 'leave_self_link_required' USING ERRCODE='42501'; END IF;
 SELECT * INTO employment FROM people.employments e WHERE e.tenant_id=p_tenant AND e.employee_id=employee
  AND e.employment_status='active' AND e.start_date<=p_start AND (e.end_date IS NULL OR e.end_date>=p_end) ORDER BY e.id LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
 RETURN leave.request_impact_read(p_tenant,employee,employment.employer_entity_id,employment.id,
  p_type,p_start,p_end,p_half_day,p_half_day_part,leave.request_actor_allowed(p_tenant,actor,'leave.self.view'));
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_request_preview(uuid,uuid,date,date,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_request_preview(uuid,uuid,date,date,boolean,text) TO authenticated;

CREATE FUNCTION public.leave_hr_request_preview(p_tenant uuid,p_employee uuid,p_employment uuid,p_type uuid,
 p_start date,p_end date,p_half_day boolean,p_half_day_part text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid; employment people.employments%ROWTYPE; show_balance boolean;
BEGIN
 actor:=leave.authorized(p_tenant,'leave.manage',true);
 IF p_start IS NULL OR p_end IS NULL OR p_end<p_start OR p_end-p_start>731 OR p_half_day IS NULL
  OR (p_half_day AND p_start<>p_end) THEN RAISE EXCEPTION 'leave_request_range_invalid' USING ERRCODE='22023'; END IF;
 IF (p_half_day_part IS NOT NULL AND p_half_day_part NOT IN ('first','second'))
  OR (NOT p_half_day AND p_half_day_part IS NOT NULL) THEN RAISE EXCEPTION 'leave_half_day_part_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO employment FROM people.employments e WHERE e.tenant_id=p_tenant AND e.id=p_employment
  AND e.employee_id=p_employee AND e.employment_status='active' AND e.start_date<=p_start AND (e.end_date IS NULL OR e.end_date>=p_end);
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities e WHERE e.tenant_id=p_tenant
  AND e.id=employment.employer_entity_id AND e.is_active) THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
 show_balance:=platform_private.has_tenant_permission(p_tenant,actor,'leave.view')
  OR platform_private.has_tenant_permission(p_tenant,actor,'leave_balance.adjust');
 RETURN leave.request_impact_read(p_tenant,p_employee,employment.employer_entity_id,employment.id,
  p_type,p_start,p_end,p_half_day,p_half_day_part,show_balance);
END $f$;
REVOKE ALL ON FUNCTION public.leave_hr_request_preview(uuid,uuid,uuid,uuid,date,date,boolean,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_hr_request_preview(uuid,uuid,uuid,uuid,date,date,boolean,text) TO authenticated;
