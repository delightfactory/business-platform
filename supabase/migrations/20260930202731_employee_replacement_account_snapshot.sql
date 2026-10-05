-- Tell the employee profile whether the latest activated intent is the identity
-- currently linked to this exact employee. Do not expose the Auth user id.
CREATE OR REPLACE FUNCTION public.people_employee_account_provision_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('intent_id',i.id,'state',i.state,'target_email',i.target_email,
    'delivery_state',i.delivery_state,'last_error_code',i.last_error_code,'activation_attempts',i.activation_attempts,
    'password_ready',EXISTS(SELECT 1 FROM people.employee_account_password_readiness r
      WHERE r.tenant_id=i.tenant_id AND r.intent_id=i.id AND r.employee_id=i.employee_id AND r.user_id=i.auth_user_id),
    'currently_linked',EXISTS(SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=i.tenant_id
      AND l.employee_id=i.employee_id AND l.user_id=i.auth_user_id AND l.unlinked_at IS NULL),
    'created_at',i.created_at,'updated_at',i.updated_at)
    INTO v_result FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id AND i.employee_id=p_employee_id
    ORDER BY i.created_at DESC LIMIT 1;
  RETURN COALESCE(v_result,pg_catalog.jsonb_build_object('state','none'));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_account_provision_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_account_provision_snapshot(uuid,uuid) TO authenticated;
