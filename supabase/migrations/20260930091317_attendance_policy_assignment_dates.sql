CREATE OR REPLACE FUNCTION public.assign_people_work_policy(p_tenant_id uuid,p_employment_id uuid,p_policy_id uuid,p_effective_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); today date:=timezone('Africa/Cairo',transaction_timestamp())::date; emp people.employments%ROWTYPE; prev people.work_assignments%ROWTYPE; ver integer; new_id uuid;
BEGIN
 IF actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,actor,'org_context.manage') OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) THEN RAISE EXCEPTION 'people_work_policy_assign_forbidden' USING ERRCODE='42501'; END IF;
 IF p_effective_date<today THEN RAISE EXCEPTION 'people_work_policy_backdate_not_supported' USING ERRCODE='22023'; END IF;
 SELECT * INTO emp FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id FOR UPDATE;
 IF NOT FOUND OR emp.employment_status<>'active' THEN RAISE EXCEPTION 'people_work_policy_employment_unavailable' USING ERRCODE='23514'; END IF;
 IF p_effective_date<emp.start_date THEN RAISE EXCEPTION 'people_work_policy_before_employment_start' USING ERRCODE='23514'; END IF;
 IF emp.end_date IS NOT NULL AND p_effective_date>emp.end_date THEN RAISE EXCEPTION 'people_work_policy_after_employment_end' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM time.work_policy_templates WHERE tenant_id=p_tenant_id AND id=p_policy_id AND is_active) THEN RAISE EXCEPTION 'people_work_policy_inactive_or_foreign' USING ERRCODE='23503'; END IF;
 SELECT head_version INTO ver FROM time.work_policy_templates WHERE tenant_id=p_tenant_id AND id=p_policy_id;
 IF EXISTS(SELECT 1 FROM people.work_assignments WHERE tenant_id=p_tenant_id AND employment_id=p_employment_id AND valid_from>today) THEN RAISE EXCEPTION 'people_assignment_future_exists' USING ERRCODE='23514'; END IF;
 SELECT * INTO prev FROM people.work_assignments WHERE tenant_id=p_tenant_id AND employment_id=p_employment_id AND valid_from<=today AND (valid_until IS NULL OR valid_until>today) ORDER BY valid_from DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR p_effective_date<=prev.valid_from THEN RAISE EXCEPTION 'people_work_policy_current_missing_or_date_invalid' USING ERRCODE='23514'; END IF;
 UPDATE people.work_assignments SET valid_until=p_effective_date WHERE tenant_id=p_tenant_id AND id=prev.id;
 INSERT INTO people.work_assignments(tenant_id,employment_id,site_id,department_id,job_id,manager_employee_id,work_policy_template_id,work_policy_version,valid_from)
 VALUES(p_tenant_id,p_employment_id,prev.site_id,prev.department_id,prev.job_id,prev.manager_employee_id,p_policy_id,ver,p_effective_date) RETURNING id INTO new_id;
 INSERT INTO people.work_assignment_audit_events(tenant_id,employment_id,actor_user_id,event_key,assignment_id,details) VALUES(p_tenant_id,p_employment_id,actor,CASE WHEN p_effective_date=today THEN 'assignment.policy_changed' ELSE 'assignment.policy_scheduled' END,new_id,jsonb_build_object('before',jsonb_build_object('policy_id',prev.work_policy_template_id,'version',prev.work_policy_version,'valid_until',prev.valid_until),'after',jsonb_build_object('policy_id',p_policy_id,'version',ver,'valid_from',p_effective_date)));
 RETURN jsonb_build_object('assignment_id',new_id,'version',ver,'effective_date',p_effective_date);
END $f$;
REVOKE ALL ON FUNCTION public.assign_people_work_policy(uuid,uuid,uuid,date) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.assign_people_work_policy(uuid,uuid,uuid,date) TO authenticated;
