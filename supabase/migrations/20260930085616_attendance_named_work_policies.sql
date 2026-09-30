-- Wave 2 foundation: Time owns named policy versions; People stores only effective assignment references.
ALTER TABLE platform_core.tenant_capability_entitlements DROP CONSTRAINT tenant_capability_entitlements_capability_key_check;
ALTER TABLE platform_core.tenant_capability_entitlements ADD CONSTRAINT tenant_capability_entitlements_capability_key_check CHECK (capability_key IN ('hr.people','hr.payroll','hr.attendance'));
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events DROP CONSTRAINT tenant_capability_entitlement_audit_events_capability_key_check;
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events ADD CONSTRAINT tenant_capability_entitlement_audit_events_capability_key_check CHECK (capability_key IN ('hr.people','hr.payroll','hr.attendance'));
CREATE OR REPLACE FUNCTION platform_private.tenant_capability_is_enabled(p_tenant_id uuid,p_capability_key text,p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE n integer; granted boolean; people_n integer; people_granted boolean;
BEGIN
 IF p_capability_key NOT IN ('hr.people','hr.payroll','hr.attendance') OR p_tenant_id IS NULL OR p_at IS NULL THEN RETURN false; END IF;
 SELECT count(*)::integer,bool_and(is_granted) INTO n,granted FROM platform_core.tenant_capability_entitlements
 WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from<=p_at AND (valid_until IS NULL OR valid_until>p_at);
 IF n<>1 OR NOT coalesce(granted,false) THEN RETURN false; END IF;
 IF p_capability_key='hr.payroll' THEN
  SELECT count(*)::integer,bool_and(is_granted) INTO people_n,people_granted FROM platform_core.tenant_capability_entitlements
  WHERE tenant_id=p_tenant_id AND capability_key='hr.people' AND valid_from<=p_at AND (valid_until IS NULL OR valid_until>p_at);
  RETURN people_n=1 AND coalesce(people_granted,false);
 END IF;
 RETURN true;
END $f$;
REVOKE ALL ON FUNCTION platform_private.tenant_capability_is_enabled(uuid,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.platform_tenant_entitlement_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE tenant jsonb; decisions jsonb; now_at timestamptz:=clock_timestamp();
BEGIN
 IF NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('tenant_id',id,'display_name',display_name,'lifecycle_state',lifecycle_state) INTO tenant FROM platform_core.tenants WHERE id=p_tenant_id;
 IF tenant IS NULL THEN RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE='P0002'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('capability_key',w.key,'status',CASE WHEN c.n>1 THEN 'conflict' WHEN f.n>0 THEN 'future_conflict' WHEN c.n=0 THEN 'missing' ELSE 'effective' END,
 'is_granted',c.granted,'valid_from',c.valid_from,'valid_until',c.valid_until,'effective_at',now_at,
 'evaluator_enabled',platform_private.tenant_capability_is_enabled(p_tenant_id,w.key,now_at),'last_decision',x.granted,'last_decision_valid_from',x.valid_from,'last_decision_valid_until',x.valid_until) ORDER BY w.key),'[]'::jsonb)
 INTO decisions FROM (VALUES('hr.people'),('hr.payroll'),('hr.attendance')) w(key)
 LEFT JOIN LATERAL (SELECT count(*)::integer n,bool_and(e.is_granted) granted,min(e.valid_from) valid_from,min(e.valid_until) valid_until FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key=w.key AND e.valid_from<=now_at AND (e.valid_until IS NULL OR e.valid_until>now_at)) c ON true
 LEFT JOIN LATERAL (SELECT count(*)::integer n FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key=w.key AND e.valid_from>now_at) f ON true
 LEFT JOIN LATERAL (SELECT e.is_granted granted,e.valid_from,e.valid_until FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key=w.key AND e.valid_until IS NOT NULL AND e.valid_until<=now_at ORDER BY e.valid_until DESC LIMIT 1) x ON true;
 RETURN tenant||jsonb_build_object('entitlements',decisions);
END $f$;
REVOKE ALL ON FUNCTION public.platform_tenant_entitlement_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.platform_tenant_entitlement_snapshot(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.change_tenant_capability_entitlement(p_tenant_id uuid,p_capability_key text,p_is_granted boolean,p_valid_until date,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); now_at timestamptz; expiry timestamptz; old_row platform_core.tenant_capability_entitlements%ROWTYPE; rows_n integer; future_n integer; people_n integer; people_granted boolean; people_until timestamptz; before_state jsonb;
BEGIN
 IF p_tenant_id IS NULL OR p_capability_key NOT IN ('hr.people','hr.payroll','hr.attendance') OR p_is_granted IS NULL THEN RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023'; END IF;
 IF coalesce(nullif(btrim(p_reason),''),'')='' OR length(btrim(p_reason))>500 THEN RAISE EXCEPTION 'tenant_entitlement_reason_required' USING ERRCODE='22023'; END IF;
 IF actor IS NULL OR NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant_id::text,90427));
 IF NOT public.current_operator_can_manage_commercial_access() THEN RAISE EXCEPTION 'commercial_access_forbidden' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenants WHERE id=p_tenant_id) THEN RAISE EXCEPTION 'commercial_tenant_unavailable' USING ERRCODE='P0002'; END IF;
 now_at:=clock_timestamp(); IF p_valid_until IS NOT NULL THEN expiry:=((p_valid_until+1)::timestamp AT TIME ZONE 'Africa/Cairo'); END IF;
 IF expiry IS NOT NULL AND expiry<=now_at THEN RAISE EXCEPTION 'tenant_entitlement_expiry_invalid' USING ERRCODE='22023'; END IF;
 SELECT count(*)::integer INTO future_n FROM platform_core.tenant_capability_entitlements WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from>now_at;
 IF future_n>0 THEN RAISE EXCEPTION 'tenant_entitlement_future_conflict' USING ERRCODE='23P01'; END IF;
 SELECT count(*)::integer INTO rows_n FROM platform_core.tenant_capability_entitlements WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from<=now_at AND (valid_until IS NULL OR valid_until>now_at);
 IF rows_n>1 THEN RAISE EXCEPTION 'tenant_entitlement_conflict' USING ERRCODE='55000'; END IF;
 IF p_capability_key='hr.payroll' AND p_is_granted THEN
  SELECT count(*)::integer,bool_and(is_granted),max(valid_until) INTO people_n,people_granted,people_until FROM platform_core.tenant_capability_entitlements WHERE tenant_id=p_tenant_id AND capability_key='hr.people' AND valid_from<=now_at AND (valid_until IS NULL OR valid_until>now_at);
  IF people_n<>1 OR NOT coalesce(people_granted,false) OR (people_until IS NOT NULL AND (expiry IS NULL OR expiry>people_until)) THEN RAISE EXCEPTION 'tenant_entitlement_people_required' USING ERRCODE='23514'; END IF;
 END IF;
 IF rows_n=1 THEN SELECT * INTO old_row FROM platform_core.tenant_capability_entitlements WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from<=now_at AND (valid_until IS NULL OR valid_until>now_at) FOR UPDATE;
  IF p_capability_key='hr.people' AND ((NOT p_is_granted AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key='hr.payroll' AND e.is_granted AND e.valid_from<=now_at AND (e.valid_until IS NULL OR e.valid_until>now_at))) OR (p_is_granted AND expiry IS NOT NULL AND (old_row.valid_until IS NULL OR expiry<old_row.valid_until) AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key='hr.payroll' AND e.is_granted AND e.valid_from<expiry AND (e.valid_until IS NULL OR e.valid_until>expiry)))) THEN RAISE EXCEPTION 'tenant_entitlement_payroll_must_end_first' USING ERRCODE='23514'; END IF;
  before_state:=jsonb_build_object('is_granted',old_row.is_granted,'valid_from',old_row.valid_from,'valid_until',old_row.valid_until);
  UPDATE platform_core.tenant_capability_entitlements SET valid_until=now_at WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from=old_row.valid_from;
 END IF;
 INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,valid_until,actor_user_id,reason) VALUES(p_tenant_id,p_capability_key,p_is_granted,now_at,expiry,actor,btrim(p_reason));
 INSERT INTO platform_core.tenant_capability_entitlement_audit_events(tenant_id,actor_user_id,capability_key,effective_at,before_state,after_state,reason) VALUES(p_tenant_id,actor,p_capability_key,now_at,before_state,jsonb_build_object('is_granted',p_is_granted,'valid_from',now_at,'valid_until',expiry),btrim(p_reason));
 RETURN jsonb_build_object('tenant_id',p_tenant_id,'capability_key',p_capability_key,'is_granted',p_is_granted,'effective_at',now_at,'valid_until',expiry);
END $f$;
REVOKE ALL ON FUNCTION public.change_tenant_capability_entitlement(uuid,text,boolean,date,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_tenant_capability_entitlement(uuid,text,boolean,date,text) TO authenticated;

CREATE SCHEMA IF NOT EXISTS time;
REVOKE ALL ON SCHEMA time FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE time.work_policy_templates(tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,id uuid NOT NULL DEFAULT gen_random_uuid(),code text NOT NULL,is_active boolean NOT NULL DEFAULT true,head_version integer NOT NULL DEFAULT 1,created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,code));
CREATE TABLE time.work_policy_versions(tenant_id uuid NOT NULL,template_id uuid NOT NULL,version integer NOT NULL,name text NOT NULL,schedule_kind text NOT NULL CHECK(schedule_kind IN('fixed','flexible')),timezone_name text NOT NULL DEFAULT 'Africa/Cairo',work_days smallint[] NOT NULL CHECK(cardinality(work_days) BETWEEN 1 AND 7 AND work_days <@ ARRAY[1,2,3,4,5,6,7]::smallint[]),shift_start time,shift_end time,ends_next_day boolean NOT NULL DEFAULT false,break_minutes integer NOT NULL DEFAULT 0 CHECK(break_minutes BETWEEN 0 AND 360),required_minutes integer,earliest_punch time,latest_punch time,attribution_before_minutes integer NOT NULL DEFAULT 120 CHECK(attribution_before_minutes BETWEEN 0 AND 720),attribution_after_minutes integer NOT NULL DEFAULT 360 CHECK(attribution_after_minutes BETWEEN 0 AND 720),created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),PRIMARY KEY(tenant_id,template_id,version),FOREIGN KEY(tenant_id,template_id) REFERENCES time.work_policy_templates(tenant_id,id) ON DELETE RESTRICT,CHECK((schedule_kind='fixed' AND shift_start IS NOT NULL AND shift_end IS NOT NULL AND required_minutes IS NULL AND (ends_next_day OR shift_end>shift_start)) OR (schedule_kind='flexible' AND required_minutes BETWEEN 60 AND 960 AND shift_start IS NULL AND shift_end IS NULL AND NOT ends_next_day)));
CREATE TABLE time.work_policy_audit_events(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,event_key text NOT NULL,template_id uuid,version integer,details jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT transaction_timestamp());
ALTER TABLE time.work_policy_templates ENABLE ROW LEVEL SECURITY; ALTER TABLE time.work_policy_versions ENABLE ROW LEVEL SECURITY; ALTER TABLE time.work_policy_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA time FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE people.work_assignments ADD COLUMN work_policy_template_id uuid, ADD COLUMN work_policy_version integer;
ALTER TABLE people.work_assignments ADD CONSTRAINT work_assignment_policy_pair CHECK((work_policy_template_id IS NULL)=(work_policy_version IS NULL));
ALTER TABLE people.work_assignments ADD CONSTRAINT work_assignment_policy_fk FOREIGN KEY(tenant_id,work_policy_template_id,work_policy_version) REFERENCES time.work_policy_versions(tenant_id,template_id,version) ON DELETE RESTRICT;
CREATE OR REPLACE FUNCTION time.has_policy_permission(p_tenant_id uuid,p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT p_actor IS NOT NULL AND (platform_private.has_tenant_permission(p_tenant_id,p_actor,'attendance_policy.manage') OR platform_private.has_tenant_permission(p_tenant_id,p_actor,'tenant.administer')) AND platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp())
$f$;
REVOKE ALL ON FUNCTION time.has_policy_permission(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.time_work_policy_catalog(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); rows jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) OR NOT platform_private.has_tenant_permission(p_tenant_id,actor,'people.view') THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'is_active',t.is_active,'head_version',t.head_version,'name',v.name,'schedule_kind',v.schedule_kind,'timezone_name',v.timezone_name,'work_days',v.work_days,'shift_start',v.shift_start,'shift_end',v.shift_end,'ends_next_day',v.ends_next_day,'break_minutes',v.break_minutes,'required_minutes',v.required_minutes,'earliest_punch',v.earliest_punch,'latest_punch',v.latest_punch,'attribution_before_minutes',v.attribution_before_minutes,'attribution_after_minutes',v.attribution_after_minutes) ORDER BY t.code),'[]'::jsonb) INTO rows FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id;
 RETURN jsonb_build_object('items',rows,'can_manage',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.time_work_policy_catalog(uuid) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.time_work_policy_catalog(uuid) TO authenticated;
CREATE FUNCTION public.save_time_work_policy(p_tenant_id uuid,p_template_id uuid,p_code text,p_name text,p_kind text,p_timezone text,p_work_days smallint[],p_start time,p_end time,p_next_day boolean,p_break integer,p_required integer,p_earliest time,p_latest time,p_before integer,p_after integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); id uuid:=p_template_id; version_n integer;
BEGIN
 IF NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
 IF coalesce(btrim(p_code),'')='' OR length(btrim(p_code))>32 OR coalesce(btrim(p_name),'')='' OR length(btrim(p_name))>100 OR p_kind NOT IN('fixed','flexible') OR cardinality(p_work_days) NOT BETWEEN 1 AND 7 OR p_before NOT BETWEEN 0 AND 720 OR p_after NOT BETWEEN 0 AND 720 OR p_break NOT BETWEEN 0 AND 360 OR (p_required IS NOT NULL AND p_required NOT BETWEEN 60 AND 960) OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'time_policy_input_invalid' USING ERRCODE='22023'; END IF;
 IF id IS NULL THEN INSERT INTO time.work_policy_templates(tenant_id,code) VALUES(p_tenant_id,upper(btrim(p_code))) RETURNING time.work_policy_templates.id INTO id; version_n:=1;
 ELSE SELECT head_version+1 INTO version_n FROM time.work_policy_templates WHERE tenant_id=p_tenant_id AND time.work_policy_templates.id=id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'time_policy_not_found' USING ERRCODE='P0002'; END IF; UPDATE time.work_policy_templates SET code=upper(btrim(p_code)),head_version=version_n WHERE tenant_id=p_tenant_id AND time.work_policy_templates.id=id; END IF;
 INSERT INTO time.work_policy_versions(tenant_id,template_id,version,name,schedule_kind,timezone_name,work_days,shift_start,shift_end,ends_next_day,break_minutes,required_minutes,earliest_punch,latest_punch,attribution_before_minutes,attribution_after_minutes,created_by)
 VALUES(p_tenant_id,id,version_n,btrim(p_name),p_kind,p_timezone,p_work_days,p_start,p_end,coalesce(p_next_day,false),p_break,p_required,p_earliest,p_latest,p_before,p_after,actor);
 INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details) VALUES(p_tenant_id,actor,CASE WHEN version_n=1 THEN 'policy.created' ELSE 'policy.versioned' END,id,version_n,jsonb_build_object('code',upper(btrim(p_code)),'name',btrim(p_name),'kind',p_kind));
 RETURN jsonb_build_object('id',id,'version',version_n);
END $f$;
REVOKE ALL ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.save_time_work_policy(uuid,uuid,text,text,text,text,smallint[],time,time,boolean,integer,integer,time,time,integer,integer) TO authenticated;
CREATE FUNCTION public.set_time_work_policy_active(p_tenant_id uuid,p_template_id uuid,p_active boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid();
BEGIN
 IF NOT time.has_policy_permission(p_tenant_id,actor) THEN RAISE EXCEPTION 'attendance_policy_manage_forbidden' USING ERRCODE='42501'; END IF;
 UPDATE time.work_policy_templates SET is_active=p_active WHERE tenant_id=p_tenant_id AND id=p_template_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'time_policy_not_found' USING ERRCODE='P0002'; END IF;
 INSERT INTO time.work_policy_audit_events(tenant_id,actor_user_id,event_key,template_id,version,details) SELECT p_tenant_id,actor,CASE WHEN p_active THEN 'policy.activated' ELSE 'policy.deactivated' END,t.id,t.head_version,jsonb_build_object('is_active',p_active) FROM time.work_policy_templates t WHERE t.tenant_id=p_tenant_id AND t.id=p_template_id;
END $f$;
REVOKE ALL ON FUNCTION public.set_time_work_policy_active(uuid,uuid,boolean) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.set_time_work_policy_active(uuid,uuid,boolean) TO authenticated;
CREATE FUNCTION public.people_work_policy_panel(p_tenant_id uuid,p_employment_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); items jsonb; options jsonb;
BEGIN
 IF actor IS NULL OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) OR NOT platform_private.has_people_permission(p_tenant_id,actor,'people.view') THEN RAISE EXCEPTION 'time_policy_view_forbidden' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('assignment_id',a.id,'policy_id',a.work_policy_template_id,'version',a.work_policy_version,'name',v.name,'code',t.code,'valid_from',a.valid_from,'valid_until',a.valid_until) ORDER BY a.valid_from DESC),'[]'::jsonb) INTO items FROM people.work_assignments a LEFT JOIN time.work_policy_templates t ON t.tenant_id=a.tenant_id AND t.id=a.work_policy_template_id LEFT JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id AND v.template_id=a.work_policy_template_id AND v.version=a.work_policy_version WHERE a.tenant_id=p_tenant_id AND a.employment_id=p_employment_id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',t.id,'code',t.code,'name',v.name,'version',v.version) ORDER BY t.code),'[]'::jsonb) INTO options FROM time.work_policy_templates t JOIN time.work_policy_versions v ON v.tenant_id=t.tenant_id AND v.template_id=t.id AND v.version=t.head_version WHERE t.tenant_id=p_tenant_id AND t.is_active;
 RETURN jsonb_build_object('history',items,'options',options,'can_assign',platform_private.has_people_permission(p_tenant_id,actor,'org_context.manage'),'can_manage_catalog',time.has_policy_permission(p_tenant_id,actor));
END $f$;
REVOKE ALL ON FUNCTION public.people_work_policy_panel(uuid,uuid) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.people_work_policy_panel(uuid,uuid) TO authenticated;
CREATE FUNCTION public.assign_people_work_policy(p_tenant_id uuid,p_employment_id uuid,p_policy_id uuid,p_effective_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); today date:=timezone('Africa/Cairo',transaction_timestamp())::date; emp people.employments%ROWTYPE; prev people.work_assignments%ROWTYPE; ver integer; new_id uuid;
BEGIN
 IF actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,actor,'org_context.manage') OR NOT platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.attendance',transaction_timestamp()) THEN RAISE EXCEPTION 'people_work_policy_assign_forbidden' USING ERRCODE='42501'; END IF;
 IF p_effective_date<today THEN RAISE EXCEPTION 'people_work_policy_backdate_not_supported' USING ERRCODE='22023'; END IF;
 SELECT * INTO emp FROM people.employments WHERE tenant_id=p_tenant_id AND id=p_employment_id FOR UPDATE;
 IF NOT FOUND OR emp.employment_status<>'active' THEN RAISE EXCEPTION 'people_work_policy_employment_unavailable' USING ERRCODE='23514'; END IF;
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
