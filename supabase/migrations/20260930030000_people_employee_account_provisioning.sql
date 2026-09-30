-- Direct Employee account creation: Auth identity, activation intent, Membership and link.
CREATE TABLE people.employee_account_provision_intents (
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  employee_id uuid NOT NULL,
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  request_key uuid NOT NULL,
  request_signature jsonb NOT NULL,
  target_email text NOT NULL CHECK (target_email=pg_catalog.lower(pg_catalog.btrim(target_email))
    AND target_email<>'' AND pg_catalog.length(target_email)<=254),
  auth_marker uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
  auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE RESTRICT,
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','user_created','activated','manual_review')),
  delivery_state text NOT NULL DEFAULT 'not_sent' CHECK (delivery_state IN ('not_sent','sent','failed','unknown')),
  last_error_code text CHECK (last_error_code IS NULL OR (last_error_code ~ '^[a-zA-Z0-9_-]{1,80}$')),
  activation_attempts integer NOT NULL DEFAULT 0 CHECK (activation_attempts>=0),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  activated_at timestamptz,
  PRIMARY KEY (tenant_id,id),
  UNIQUE (created_by_user_id,request_key),
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT,
  CHECK ((state='activated' AND auth_user_id IS NOT NULL AND activated_at IS NOT NULL)
    OR (state<>'activated' AND activated_at IS NULL)),
  CHECK ((state='pending' AND auth_user_id IS NULL) OR state<>'pending'),
  CHECK ((state IN ('user_created','activated') AND auth_user_id IS NOT NULL) OR state NOT IN ('user_created','activated'))
);
CREATE UNIQUE INDEX employee_account_one_open_operation_idx ON people.employee_account_provision_intents(tenant_id,employee_id)
  WHERE state IN ('pending','user_created','manual_review');
CREATE INDEX employee_account_intent_history_idx ON people.employee_account_provision_intents(tenant_id,employee_id,created_at DESC);
ALTER TABLE people.employee_account_provision_intents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.employee_account_provision_intents FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE people.employee_account_provision_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL,
  intent_id uuid NOT NULL,
  employee_id uuid NOT NULL,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_key text NOT NULL CHECK (event_key IN ('employee.account_requested','employee.account_created',
    'employee.account_delivery','employee.account_manual_review','employee.account_activation_deferred','employee.account_activated')),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  FOREIGN KEY (tenant_id,intent_id) REFERENCES people.employee_account_provision_intents(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id,employee_id) REFERENCES people.employees(tenant_id,id) ON DELETE RESTRICT
);
ALTER TABLE people.employee_account_provision_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE people.employee_account_provision_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE people.employee_account_provision_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION people.prevent_employee_account_audit_mutation() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'people_employee_account_audit_append_only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER employee_account_audit_append_only BEFORE UPDATE OR DELETE ON people.employee_account_provision_audit_events
FOR EACH ROW EXECUTE FUNCTION people.prevent_employee_account_audit_mutation();
REVOKE ALL ON FUNCTION people.prevent_employee_account_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION people.capture_employee_account_auth_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_intent people.employee_account_provision_intents%ROWTYPE; v_intent_id uuid; v_marker uuid;
BEGIN
  IF NEW.raw_app_meta_data->>'people_employee_provision_intent_id' IS NULL
     AND NEW.raw_app_meta_data->>'people_employee_provision_marker' IS NULL THEN RETURN NEW; END IF;
  BEGIN
    v_intent_id := (NEW.raw_app_meta_data->>'people_employee_provision_intent_id')::uuid;
    v_marker := (NEW.raw_app_meta_data->>'people_employee_provision_marker')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'people_account_provision_marker_invalid' USING ERRCODE='23514';
  END;
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i
    WHERE i.id=v_intent_id AND i.auth_marker=v_marker AND i.state='pending'
      AND i.target_email=pg_catalog.lower(pg_catalog.btrim(NEW.email)) FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_account_provision_marker_unmatched' USING ERRCODE='23514'; END IF;
  UPDATE people.employee_account_provision_intents SET auth_user_id=NEW.id,state='user_created',updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=v_intent.tenant_id AND id=v_intent.id;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(v_intent.tenant_id,v_intent.id,v_intent.employee_id,v_intent.created_by_user_id,'employee.account_created',
      pg_catalog.jsonb_build_object('auth_user_id',NEW.id));
  RETURN NEW;
END;
$function$;
CREATE TRIGGER people_capture_employee_account_provision
AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION people.capture_employee_account_auth_user();
REVOKE ALL ON FUNCTION people.capture_employee_account_auth_user() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.start_people_employee_account_provision(p_tenant_id uuid,p_employee_id uuid,p_target_email text,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_email text := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_target_email,'')));
  v_signature jsonb; v_existing people.employee_account_provision_intents%ROWTYPE; v_tenant_state text; v_workforce_state text; v_email_conflict boolean;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_request_key IS NULL OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'people_employee_account_request_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text||':people-account:'||p_employee_id::text,917541));
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=p_tenant_id FOR SHARE;
  IF v_tenant_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'people_employee_account_tenant_unavailable' USING ERRCODE='42501'; END IF;
  SELECT workforce_status INTO v_workforce_state FROM people.employees WHERE tenant_id=p_tenant_id AND id=p_employee_id FOR UPDATE;
  IF NOT FOUND OR v_workforce_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'people_employee_account_employee_unavailable' USING ERRCODE='42501'; END IF;
  IF EXISTS (SELECT 1 FROM people.employee_user_links l WHERE l.tenant_id=p_tenant_id AND l.employee_id=p_employee_id AND l.unlinked_at IS NULL) THEN
    RAISE EXCEPTION 'people_employee_account_already_linked' USING ERRCODE='23505';
  END IF;
  v_signature:=pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'employee_id',p_employee_id,'target_email',v_email);
  SELECT * INTO v_existing FROM people.employee_account_provision_intents i
    WHERE i.created_by_user_id=v_actor AND i.request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing.request_signature IS DISTINCT FROM v_signature THEN RAISE EXCEPTION 'people_employee_account_request_key_conflict' USING ERRCODE='P0001'; END IF;
    RETURN pg_catalog.jsonb_build_object('intent_id',v_existing.id,'state',v_existing.state,'target_email',v_existing.target_email);
  END IF;
  IF EXISTS (SELECT 1 FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id
    AND i.employee_id=p_employee_id AND i.state IN ('pending','user_created','manual_review')) THEN
    RAISE EXCEPTION 'people_employee_account_operation_in_progress' USING ERRCODE='23505';
  END IF;
  v_email_conflict:=EXISTS (SELECT 1 FROM auth.users u WHERE pg_catalog.lower(u.email)=v_email);
  INSERT INTO people.employee_account_provision_intents(tenant_id,employee_id,created_by_user_id,request_key,request_signature,target_email)
    VALUES(p_tenant_id,p_employee_id,v_actor,p_request_key,v_signature,v_email) RETURNING * INTO v_existing;
  IF v_email_conflict THEN
    UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='email_conflict',updated_at=pg_catalog.clock_timestamp()
      WHERE tenant_id=p_tenant_id AND id=v_existing.id;
    v_existing.state:='manual_review';
    v_existing.last_error_code:='email_conflict';
  END IF;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,v_existing.id,p_employee_id,v_actor,'employee.account_requested',pg_catalog.jsonb_build_object('target_email',v_email));
  IF v_email_conflict THEN
    INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
      VALUES(p_tenant_id,v_existing.id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','email_conflict'));
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_existing.id,'state',v_existing.state,'target_email',v_email);
END;
$function$;
REVOKE ALL ON FUNCTION public.start_people_employee_account_provision(uuid,uuid,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.start_people_employee_account_provision(uuid,uuid,text,uuid) TO authenticated;

CREATE FUNCTION public.prepare_people_employee_account_provision(p_tenant_id uuid,p_employee_id uuid,p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_tenant_state text; v_workforce_state text;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id
    AND i.employee_id=p_employee_id AND i.id=p_intent_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_account_operation_unavailable' USING ERRCODE='P0002'; END IF;
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=p_tenant_id;
  SELECT workforce_status INTO v_workforce_state FROM people.employees WHERE tenant_id=p_tenant_id AND id=p_employee_id;
  IF v_tenant_state IS DISTINCT FROM 'active' OR v_workforce_state IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'people_employee_account_subject_unavailable' USING ERRCODE='42501';
  END IF;
  IF v_intent.state='pending' AND EXISTS (SELECT 1 FROM auth.users u WHERE pg_catalog.lower(u.email)=v_intent.target_email) THEN
    UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='email_conflict',updated_at=pg_catalog.clock_timestamp()
      WHERE tenant_id=p_tenant_id AND id=p_intent_id;
    INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
      VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','email_conflict'));
    RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state','manual_review','target_email',v_intent.target_email);
  END IF;
  IF v_intent.state='user_created' AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_intent.auth_user_id
    AND pg_catalog.lower(u.email)=v_intent.target_email
    AND u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
    AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text) THEN
    UPDATE people.employee_account_provision_intents SET state='manual_review',last_error_code='marker_conflict',updated_at=pg_catalog.clock_timestamp()
      WHERE tenant_id=p_tenant_id AND id=p_intent_id;
    INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
      VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_manual_review',pg_catalog.jsonb_build_object('reason','marker_conflict'));
    RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state','manual_review','target_email',v_intent.target_email);
  END IF;
  IF v_intent.state NOT IN ('pending','user_created') THEN
    RETURN pg_catalog.jsonb_build_object('intent_id',p_intent_id,'state',v_intent.state,'target_email',v_intent.target_email);
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'target_email',v_intent.target_email,
    'auth_marker',v_intent.auth_marker,'auth_user_id',v_intent.auth_user_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.prepare_people_employee_account_provision(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.prepare_people_employee_account_provision(uuid,uuid,uuid) TO authenticated;

CREATE FUNCTION public.record_people_employee_account_delivery(p_tenant_id uuid,p_employee_id uuid,p_intent_id uuid,p_delivery_state text,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_email text;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF p_delivery_state NOT IN ('sent','failed','unknown') OR (p_error_code IS NOT NULL AND p_error_code !~ '^[a-zA-Z0-9_-]{1,80}$') THEN
    RAISE EXCEPTION 'people_employee_account_delivery_invalid' USING ERRCODE='22023';
  END IF;
  UPDATE people.employee_account_provision_intents SET delivery_state=p_delivery_state,last_error_code=p_error_code,
    activation_attempts=activation_attempts+1,updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=p_tenant_id AND employee_id=p_employee_id AND id=p_intent_id AND state='user_created'
    RETURNING target_email INTO v_email;
  IF NOT FOUND THEN RAISE EXCEPTION 'people_employee_account_operation_unavailable' USING ERRCODE='P0002'; END IF;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(p_tenant_id,p_intent_id,p_employee_id,v_actor,'employee.account_delivery',pg_catalog.jsonb_build_object('state',p_delivery_state,'error_code',p_error_code));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_people_employee_account_delivery(uuid,uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.record_people_employee_account_delivery(uuid,uuid,uuid,text,text) TO authenticated;

CREATE FUNCTION public.people_employee_account_provision_snapshot(p_tenant_id uuid,p_employee_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb;
BEGIN
  IF v_actor IS NULL OR NOT platform_private.has_people_permission(p_tenant_id,v_actor,'people.manage')
    OR NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'people_employee_account_manage_forbidden' USING ERRCODE='42501';
  END IF;
  SELECT pg_catalog.jsonb_build_object('intent_id',i.id,'state',i.state,'target_email',i.target_email,
    'delivery_state',i.delivery_state,'last_error_code',i.last_error_code,'activation_attempts',i.activation_attempts,
    'created_at',i.created_at,'updated_at',i.updated_at)
    INTO v_result FROM people.employee_account_provision_intents i WHERE i.tenant_id=p_tenant_id AND i.employee_id=p_employee_id
    ORDER BY i.created_at DESC LIMIT 1;
  RETURN COALESCE(v_result,pg_catalog.jsonb_build_object('state','none'));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_account_provision_snapshot(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_account_provision_snapshot(uuid,uuid) TO authenticated;

CREATE FUNCTION public.people_employee_account_activation_snapshot(p_intent_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
  v_email text; v_confirmed timestamptz; v_deleted timestamptz;
BEGIN
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.id=p_intent_id AND i.auth_user_id=v_actor;
  IF NOT FOUND OR v_actor IS NULL THEN RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501'; END IF;
  SELECT u.email,u.email_confirmed_at,u.deleted_at INTO v_email,v_confirmed,v_deleted FROM auth.users u
    WHERE u.id=v_actor AND (v_intent.state='activated' OR (
      u.raw_app_meta_data->>'people_employee_provision_intent_id'=v_intent.id::text
      AND u.raw_app_meta_data->>'people_employee_provision_marker'=v_intent.auth_marker::text));
  IF NOT FOUND OR pg_catalog.lower(v_email)<>v_intent.target_email OR v_confirmed IS NULL OR v_deleted IS NOT NULL THEN
    RAISE EXCEPTION 'people_employee_account_activation_identity_unverified' USING ERRCODE='42501';
  END IF;
  RETURN pg_catalog.jsonb_build_object('intent_id',v_intent.id,'state',v_intent.state,'email',v_intent.target_email,
    'tenant_name',(SELECT t.display_name FROM platform_core.tenants t WHERE t.id=v_intent.tenant_id),
    'employee_name',(SELECT e.full_name FROM people.employees e WHERE e.tenant_id=v_intent.tenant_id AND e.id=v_intent.employee_id));
END;
$function$;
REVOKE ALL ON FUNCTION public.people_employee_account_activation_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.people_employee_account_activation_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.defer_people_employee_account_activation(p_intent_id uuid,p_error_code text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_intent people.employee_account_provision_intents%ROWTYPE;
BEGIN
  SELECT * INTO v_intent FROM people.employee_account_provision_intents i WHERE i.id=p_intent_id AND i.auth_user_id=v_actor FOR UPDATE;
  IF NOT FOUND OR v_actor IS NULL OR p_error_code IS NULL OR p_error_code !~ '^[a-zA-Z0-9_-]{1,80}$' THEN
    RAISE EXCEPTION 'people_employee_account_activation_unavailable' USING ERRCODE='42501';
  END IF;
  IF v_intent.state<>'user_created' THEN RAISE EXCEPTION 'people_employee_account_activation_state_invalid' USING ERRCODE='23514'; END IF;
  UPDATE people.employee_account_provision_intents SET last_error_code=p_error_code,updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=v_intent.tenant_id AND id=v_intent.id;
  INSERT INTO people.employee_account_provision_audit_events(tenant_id,intent_id,employee_id,actor_user_id,event_key,details)
    VALUES(v_intent.tenant_id,v_intent.id,v_intent.employee_id,v_actor,'employee.account_activation_deferred',pg_catalog.jsonb_build_object('reason',p_error_code));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.defer_people_employee_account_activation(uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.defer_people_employee_account_activation(uuid,text) TO authenticated;

CREATE FUNCTION public.activate_people_employee_account(p_intent_id uuid)
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
