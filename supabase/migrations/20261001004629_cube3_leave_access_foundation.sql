-- Cube 3 Slice 1: entitlement and narrowly scoped own-profile access.
ALTER TABLE platform_core.tenant_capability_entitlements DROP CONSTRAINT tenant_capability_entitlements_capability_key_check;
ALTER TABLE platform_core.tenant_capability_entitlements ADD CONSTRAINT tenant_capability_entitlements_capability_key_check CHECK (capability_key IN ('hr.people','hr.payroll','hr.attendance','hr.leave'));
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events DROP CONSTRAINT tenant_capability_entitlement_audit_events_capability_key_check;
ALTER TABLE platform_core.tenant_capability_entitlement_audit_events ADD CONSTRAINT tenant_capability_entitlement_audit_events_capability_key_check CHECK (capability_key IN ('hr.people','hr.payroll','hr.attendance','hr.leave'));

CREATE OR REPLACE FUNCTION platform_private.tenant_capability_is_enabled(p_tenant_id uuid,p_capability_key text,p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE n integer; granted boolean; parent_n integer; parent_granted boolean;
BEGIN
 IF p_capability_key NOT IN ('hr.people','hr.payroll','hr.attendance','hr.leave') OR p_tenant_id IS NULL OR p_at IS NULL THEN RETURN false; END IF;
 SELECT count(*)::integer,bool_and(is_granted) INTO n,granted FROM platform_core.tenant_capability_entitlements
 WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from<=p_at AND (valid_until IS NULL OR valid_until>p_at);
 IF n<>1 OR NOT coalesce(granted,false) THEN RETURN false; END IF;
 IF p_capability_key IN ('hr.payroll','hr.leave') THEN
  SELECT count(*)::integer,bool_and(is_granted) INTO parent_n,parent_granted FROM platform_core.tenant_capability_entitlements
  WHERE tenant_id=p_tenant_id AND capability_key='hr.people' AND valid_from<=p_at AND (valid_until IS NULL OR valid_until>p_at);
  RETURN parent_n=1 AND coalesce(parent_granted,false);
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
 INTO decisions FROM (VALUES('hr.people'),('hr.payroll'),('hr.attendance'),('hr.leave')) w(key)
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
 IF p_tenant_id IS NULL OR p_capability_key NOT IN ('hr.people','hr.payroll','hr.attendance','hr.leave') OR p_is_granted IS NULL THEN RAISE EXCEPTION 'tenant_entitlement_input_invalid' USING ERRCODE='22023'; END IF;
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
 IF p_capability_key IN ('hr.payroll','hr.leave') AND p_is_granted THEN
  SELECT count(*)::integer,bool_and(is_granted),max(valid_until) INTO people_n,people_granted,people_until FROM platform_core.tenant_capability_entitlements WHERE tenant_id=p_tenant_id AND capability_key='hr.people' AND valid_from<=now_at AND (valid_until IS NULL OR valid_until>now_at);
  IF people_n<>1 OR NOT coalesce(people_granted,false) OR (people_until IS NOT NULL AND (expiry IS NULL OR expiry>people_until)) THEN RAISE EXCEPTION 'tenant_entitlement_people_required' USING ERRCODE='23514'; END IF;
 END IF;
 IF rows_n=1 THEN SELECT * INTO old_row FROM platform_core.tenant_capability_entitlements WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from<=now_at AND (valid_until IS NULL OR valid_until>now_at) FOR UPDATE;
  IF p_capability_key='hr.people' AND ((NOT p_is_granted AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key='hr.payroll' AND e.is_granted AND e.valid_from<=now_at AND (e.valid_until IS NULL OR e.valid_until>now_at))) OR (p_is_granted AND expiry IS NOT NULL AND (old_row.valid_until IS NULL OR expiry<old_row.valid_until) AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key='hr.payroll' AND e.is_granted AND e.valid_from<expiry AND (e.valid_until IS NULL OR e.valid_until>expiry)))) THEN RAISE EXCEPTION 'tenant_entitlement_payroll_must_end_first' USING ERRCODE='23514'; END IF;
  IF p_capability_key='hr.people' AND ((NOT p_is_granted AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key='hr.leave' AND e.is_granted AND e.valid_from<=now_at AND (e.valid_until IS NULL OR e.valid_until>now_at))) OR (p_is_granted AND expiry IS NOT NULL AND (old_row.valid_until IS NULL OR expiry<old_row.valid_until) AND EXISTS(SELECT 1 FROM platform_core.tenant_capability_entitlements e WHERE e.tenant_id=p_tenant_id AND e.capability_key='hr.leave' AND e.is_granted AND e.valid_from<expiry AND (e.valid_until IS NULL OR e.valid_until>expiry)))) THEN RAISE EXCEPTION 'tenant_entitlement_leave_must_end_first' USING ERRCODE='23514'; END IF;
  before_state:=jsonb_build_object('is_granted',old_row.is_granted,'valid_from',old_row.valid_from,'valid_until',old_row.valid_until);
  UPDATE platform_core.tenant_capability_entitlements SET valid_until=now_at WHERE tenant_id=p_tenant_id AND capability_key=p_capability_key AND valid_from=old_row.valid_from;
 END IF;
 INSERT INTO platform_core.tenant_capability_entitlements(tenant_id,capability_key,is_granted,valid_from,valid_until,actor_user_id,reason) VALUES(p_tenant_id,p_capability_key,p_is_granted,now_at,expiry,actor,btrim(p_reason));
 INSERT INTO platform_core.tenant_capability_entitlement_audit_events(tenant_id,actor_user_id,capability_key,effective_at,before_state,after_state,reason) VALUES(p_tenant_id,actor,p_capability_key,now_at,before_state,jsonb_build_object('is_granted',p_is_granted,'valid_from',now_at,'valid_until',expiry),btrim(p_reason));
 RETURN jsonb_build_object('tenant_id',p_tenant_id,'capability_key',p_capability_key,'is_granted',p_is_granted,'effective_at',now_at,'valid_until',expiry);
END $f$;
REVOKE ALL ON FUNCTION public.change_tenant_capability_entitlement(uuid,text,boolean,date,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.change_tenant_capability_entitlement(uuid,text,boolean,date,text) TO authenticated;

-- The nine previously published bundle keys and snapshots remain byte-for-byte stable.
CREATE OR REPLACE FUNCTION platform_private.people_role_bundle_catalog()
RETURNS TABLE(role_key text,role_version integer,permission_snapshot text[])
LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT b.role_key,1,b.permissions FROM (VALUES
 ('people.reader.v1'::text,ARRAY['people.view']::text[]),
 ('people.operations.v1'::text,ARRAY['people.view','people.manage','employment.manage','org_context.manage','compensation.view','compensation.manage']::text[]),
 ('people.compensation_reader.v1'::text,ARRAY['people.view','compensation.view']::text[]),
 ('people.compensation_manager.v1'::text,ARRAY['people.view','compensation.view','compensation.manage']::text[]),
 ('people.import_operator.v1'::text,ARRAY['people.view','people.manage','employment.manage','compensation.view','compensation.manage','workforce_import.execute']::text[]),
 ('attendance.policy.manager.v1'::text,ARRAY['attendance_policy.manage']::text[]),
 ('attendance.reader.v1'::text,ARRAY['attendance.view']::text[]),
 ('attendance.operator.v1'::text,ARRAY['attendance.view','attendance.manage']::text[]),
 ('attendance.reviewer.v1'::text,ARRAY['attendance.view','attendance.correct','attendance.approve']::text[]),
 ('employee.leave.self.v1'::text,ARRAY['people.self.view','leave.self.view','leave.self.request']::text[]),
 ('leave.reader.v1'::text,ARRAY['leave.view']::text[]),
 ('leave.manager.v1'::text,ARRAY['leave.view','leave.manage']::text[]),
 ('leave.approver.v1'::text,ARRAY['leave.view','leave.approve']::text[]),
 ('leave.balance.manager.v1'::text,ARRAY['leave.view','leave_balance.adjust']::text[])
 ) b(role_key,permissions)
$f$;
REVOKE ALL ON FUNCTION platform_private.people_role_bundle_catalog() FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE platform_core.tenant_membership_audit_events DROP CONSTRAINT tenant_membership_audit_events_action_check;
ALTER TABLE platform_core.tenant_membership_audit_events ADD CONSTRAINT tenant_membership_audit_events_action_check CHECK (action IN (
 'invitation_created','delivery_sent','delivery_failed','reissued','revoked','expired','accepted','already_member','deactivated','reactivated','credential_ready','admin_role_promoted','admin_role_demoted','people_role_bundles_changed','leave_self_access_changed'));
DO $f$ BEGIN
 IF pg_catalog.pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure) NOT LIKE '%cardinality(p_bundle_keys) > 9%' THEN
   RAISE EXCEPTION 'unexpected_people_bundle_writer_definition';
 END IF;
 EXECUTE replace(pg_catalog.pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure),'cardinality(p_bundle_keys) > 9','cardinality(p_bundle_keys) > 14');
END $f$;

-- Own access is independent of hr.people being enabled after identity/link setup.
CREATE OR REPLACE FUNCTION platform_private.has_leave_self_permission(p_tenant_id uuid,p_actor uuid,p_permission text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT p_permission IN ('people.self.view','leave.self.view','leave.self.request')
   AND p_actor IS NOT NULL
   AND EXISTS(SELECT 1 FROM platform_core.tenants t WHERE t.id=p_tenant_id AND t.lifecycle_state='active')
   AND EXISTS(SELECT 1 FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
     WHERE m.tenant_id=p_tenant_id AND m.user_id=p_actor AND m.access_state='active'
       AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()))
   AND EXISTS(SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id AND l.user_id=p_actor AND l.unlinked_at IS NULL)
   AND EXISTS(SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
     WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_actor AND p_permission=ANY(r.permission_snapshot));
$f$;
REVOKE ALL ON FUNCTION platform_private.has_leave_self_permission(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

-- Protected tenant admins keep their existing role and receive only the explicit own-service bundle.
CREATE FUNCTION public.set_tenant_member_leave_self_access(p_tenant_id uuid,p_user_id uuid,p_enabled boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); target_access text; target_protected boolean; bundle_id uuid; was_assigned boolean;
BEGIN
 IF p_tenant_id IS NULL OR p_user_id IS NULL OR p_enabled IS NULL THEN RAISE EXCEPTION 'tenant_leave_self_access_input_invalid' USING ERRCODE='22023'; END IF;
 IF actor IS NULL THEN RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant_id::text,90427));
 IF NOT platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.members.manage') THEN RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501'; END IF;
 SELECT m.access_state,EXISTS(SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
   WHERE mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id AND r.protects_tenant_admin)
 INTO target_access,target_protected FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
 WHERE m.tenant_id=p_tenant_id AND m.user_id=p_user_id AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
   AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) FOR UPDATE OF m;
 IF NOT FOUND OR target_access<>'active' OR NOT target_protected THEN RAISE EXCEPTION 'tenant_leave_self_access_target_unavailable' USING ERRCODE='42501'; END IF;
 INSERT INTO platform_core.tenant_roles(tenant_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
 SELECT p_tenant_id,b.role_key,b.role_version,b.permission_snapshot,false FROM platform_private.people_role_bundle_catalog() b
 WHERE b.role_key='employee.leave.self.v1' ON CONFLICT(tenant_id,role_key,role_version) DO NOTHING;
 SELECT r.role_id INTO bundle_id FROM platform_core.tenant_roles r JOIN platform_private.people_role_bundle_catalog() b
   ON b.role_key=r.role_key AND b.role_version=r.role_version AND b.permission_snapshot=r.permission_snapshot
 WHERE r.tenant_id=p_tenant_id AND r.role_key='employee.leave.self.v1' AND NOT r.protects_tenant_admin;
 IF bundle_id IS NULL THEN RAISE EXCEPTION 'tenant_people_role_bundle_catalog_unavailable' USING ERRCODE='55000'; END IF;
 SELECT EXISTS(SELECT 1 FROM platform_core.membership_roles WHERE tenant_id=p_tenant_id AND user_id=p_user_id AND role_id=bundle_id) INTO was_assigned;
 IF was_assigned=p_enabled THEN RETURN jsonb_build_object('state','unchanged','enabled',p_enabled); END IF;
 IF p_enabled THEN INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(p_tenant_id,p_user_id,bundle_id);
 ELSE DELETE FROM platform_core.membership_roles WHERE tenant_id=p_tenant_id AND user_id=p_user_id AND role_id=bundle_id; END IF;
 INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,actor_user_id,subject_user_id,action,details)
 VALUES(p_tenant_id,actor,p_user_id,'leave_self_access_changed',jsonb_build_object('enabled',p_enabled,'role_key','employee.leave.self.v1'));
 RETURN jsonb_build_object('state','updated','enabled',p_enabled);
END $f$;
REVOKE ALL ON FUNCTION public.set_tenant_member_leave_self_access(uuid,uuid,boolean) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_member_leave_self_access(uuid,uuid,boolean) TO authenticated;

CREATE FUNCTION public.tenant_my_employee_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb; enabled boolean;
BEGIN
 IF actor IS NULL OR NOT platform_private.has_leave_self_permission(p_tenant_id,actor,'people.self.view')
   OR NOT platform_private.has_leave_self_permission(p_tenant_id,actor,'leave.self.view') THEN
   RAISE EXCEPTION 'leave_self_profile_forbidden' USING ERRCODE='42501';
 END IF;
 enabled:=platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.people',transaction_timestamp())
   AND platform_private.tenant_capability_is_enabled(p_tenant_id,'hr.leave',transaction_timestamp());
 SELECT jsonb_build_object('employee_code',e.employee_code,'display_name',e.full_name,'employee_status',e.workforce_status,'employment_status',em.employment_status,
   'employment_start_date',em.start_date,'site_name',site.display_name,'job_title',job.name,'new_work_enabled',enabled)
 INTO result FROM people.employee_user_links l
 JOIN people.employees e ON e.tenant_id=l.tenant_id AND e.id=l.employee_id
 LEFT JOIN LATERAL (SELECT x.employment_status,x.start_date,x.id FROM people.employments x
   WHERE x.tenant_id=e.tenant_id AND x.employee_id=e.id AND x.start_date<=((pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date)
   ORDER BY (x.end_date IS NULL OR x.end_date>=((pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date)) DESC,x.start_date DESC,x.id DESC LIMIT 1) em ON true
 LEFT JOIN LATERAL (SELECT a.site_id,a.job_id FROM people.work_assignments a WHERE a.tenant_id=e.tenant_id AND a.employment_id=em.id
   AND a.valid_from<=((pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date)
   ORDER BY (a.valid_until IS NULL OR a.valid_until>((pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date)) DESC,a.valid_from DESC,a.id DESC LIMIT 1) a ON true
 LEFT JOIN platform_core.tenant_sites site ON site.tenant_id=e.tenant_id AND site.id=a.site_id
 LEFT JOIN people.jobs job ON job.tenant_id=e.tenant_id AND job.id=a.job_id
 WHERE l.tenant_id=p_tenant_id AND l.user_id=actor AND l.unlinked_at IS NULL;
 enabled:=coalesce(enabled,false);
 enabled:=enabled AND coalesce((result->>'employee_status')='active',false)
   AND coalesce((result->>'employment_status')='active',false);
 result:=result||jsonb_build_object('new_work_enabled',enabled);
 IF result IS NULL THEN RAISE EXCEPTION 'leave_self_profile_unavailable' USING ERRCODE='42501'; END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.tenant_my_employee_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_my_employee_snapshot(uuid) TO authenticated;
