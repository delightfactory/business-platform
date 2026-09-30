-- Revalidate the original HR actor when the recipient activates the account.
CREATE OR REPLACE FUNCTION public.activate_people_employee_account(p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_email text; v_confirmed timestamptz; v_banned timestamptz; v_deleted timestamptz; v_password text;
  v_tenant_state text; v_workforce_state text; v_limit_mode text; v_limit integer; v_usage integer; v_role uuid; v_link_id uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.id=p_intent_id AND i.auth_user_id=v_actor FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501'; END IF;
  IF v_intent.state='activated' THEN RETURN pg_catalog.jsonb_build_object('state','activated','tenant_id',v_intent.tenant_id); END IF;
  IF v_intent.state<>'user_created' THEN RAISE EXCEPTION 'people_employee_account_activation_state_invalid' USING ERRCODE='23514'; END IF;
  SELECT u.email,u.email_confirmed_at,u.banned_until,u.deleted_at,u.encrypted_password INTO v_email,v_confirmed,v_banned,v_deleted,v_password
    FROM auth.users u WHERE u.id=v_actor AND u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
      AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text;
  IF NOT FOUND OR pg_catalog.lower(v_email)<>v_intent.target_email OR v_confirmed IS NULL OR v_deleted IS NOT NULL
    OR (v_banned IS NOT NULL AND v_banned>pg_catalog.now()) THEN
    RAISE EXCEPTION 'people_employee_account_activation_identity_unverified' USING ERRCODE='42501';
  END IF;
  IF v_password IS NULL OR v_password='' THEN RAISE EXCEPTION 'people_employee_account_password_required' USING ERRCODE='42501'; END IF;
  IF NOT platform_private.has_people_permission(v_intent.tenant_id,v_intent.created_by_user_id,'people.manage')
    OR NOT platform_private.has_tenant_permission(v_intent.tenant_id,v_intent.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_issuer_forbidden' USING ERRCODE='42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_intent.tenant_id::text,90427));
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=v_intent.tenant_id FOR UPDATE;
  IF v_tenant_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'people_employee_account_tenant_unavailable' USING ERRCODE='42501'; END IF;
  SELECT workforce_status INTO v_workforce_state FROM people.employees WHERE tenant_id=v_intent.tenant_id AND id=v_intent.employee_id FOR UPDATE;
  IF v_workforce_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'people_employee_account_employee_unavailable' USING ERRCODE='42501'; END IF;
  IF EXISTS (SELECT 1 FROM platform_core.tenant_memberships m WHERE m.tenant_id=v_intent.tenant_id AND m.user_id=v_actor) THEN
    RAISE EXCEPTION 'people_employee_account_membership_conflict' USING ERRCODE='23505';
  END IF;
  IF EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=v_intent.tenant_id AND l.employee_id=v_intent.employee_id AND l.unlinked_at IS NULL) THEN
    RAISE EXCEPTION 'people_employee_account_link_conflict' USING ERRCODE='23505';
  END IF;
  SELECT limit_mode,limit_value INTO v_limit_mode,v_limit FROM platform_core.tenant_capability_limits l
    WHERE l.tenant_id=v_intent.tenant_id AND l.capability_key='tenant.users'
      AND l.valid_from<=pg_catalog.clock_timestamp() AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.clock_timestamp());
  IF NOT FOUND OR v_limit_mode NOT IN ('limited','unlimited') OR (v_limit_mode='limited' AND (v_limit IS NULL OR v_limit<=0)) THEN
    RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000';
  END IF;
  SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships m
    WHERE m.tenant_id=v_intent.tenant_id AND m.access_state='active';
  IF v_limit_mode='limited' AND v_usage>=v_limit THEN RAISE EXCEPTION 'tenant_member_limit_full' USING ERRCODE='P0001'; END IF;
  INSERT INTO platform_core.tenant_roles(tenant_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
    VALUES(v_intent.tenant_id,'tenant.member.v1',1,ARRAY[]::text[],false) ON CONFLICT(tenant_id,role_key,role_version) DO NOTHING;
  SELECT role_id INTO v_role FROM platform_core.tenant_roles WHERE tenant_id=v_intent.tenant_id
    AND role_key='tenant.member.v1' AND role_version=1 AND NOT protects_tenant_admin AND cardinality(permission_snapshot)=0;
  IF v_role IS NULL THEN RAISE EXCEPTION 'tenant_member_role_unavailable' USING ERRCODE='55000'; END IF;
  INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
    VALUES(v_intent.tenant_id,v_actor,'active',v_intent.created_by_user_id);
  INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(v_intent.tenant_id,v_actor,v_role);
  INSERT INTO people.employee_user_links(tenant_id,employee_id,user_id,linked_by_user_id)
    VALUES(v_intent.tenant_id,v_intent.employee_id,v_actor,v_actor) RETURNING id INTO v_link_id;
  UPDATE people.employee_account_provision_intents SET state='activated',activated_at=pg_catalog.clock_timestamp(),
    delivery_state='sent',last_error_code=NULL,updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=v_intent.tenant_id AND id=v_intent.id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,actor_user_id,subject_user_id,target_email,action,details)
    VALUES(v_intent.tenant_id,v_actor,v_actor,v_intent.target_email,'accepted',
      pg_catalog.jsonb_build_object('source','direct_employee_account_activation','intent_id',v_intent.id,'role','tenant.member.v1'));
  INSERT INTO people.employee_user_link_audit_events(tenant_id,employee_id,link_id,actor_user_id,event_key,details)
    VALUES(v_intent.tenant_id,v_intent.employee_id,v_link_id,v_actor,'employee.user_linked',
      pg_catalog.jsonb_build_object('source','direct_account_activation','intent_id',v_intent.id,'requested_by',v_intent.created_by_user_id));
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(v_intent.tenant_id,v_intent.id,v_intent.employee_id,v_actor,'employee.account_activated',
      pg_catalog.jsonb_build_object('membership_role','tenant.member.v1','link_id',v_link_id));
  RETURN pg_catalog.jsonb_build_object('state','activated','tenant_id',v_intent.tenant_id,'employee_id',v_intent.employee_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.activate_people_employee_account(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.activate_people_employee_account(uuid) TO authenticated;
