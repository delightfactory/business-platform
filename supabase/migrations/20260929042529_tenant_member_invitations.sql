-- Tenant member access is issued only through a verified, tenant-scoped invitation.
ALTER TABLE platform_private.platform_auth_password_readiness
  DROP CONSTRAINT platform_auth_password_readiness_source_invitation_id_fkey;
ALTER TABLE platform_private.platform_auth_password_readiness
  ADD COLUMN source_workflow text NOT NULL DEFAULT 'tenant_admin_onboarding'
    CHECK (source_workflow IN ('tenant_admin_onboarding','tenant_member_invitation'));

-- Keep record-field access inside the matching trigger-table branch. The previous
-- combined OR condition evaluated OLD.role_id on tenant_memberships updates.
CREATE OR REPLACE FUNCTION platform_core.prevent_last_tenant_admin_removal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_replacement_exists boolean; v_removes_admin boolean;
BEGIN
  IF TG_TABLE_NAME='tenant_memberships' THEN
    IF TG_OP='UPDATE' AND (NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
      RAISE EXCEPTION 'Tenant membership identity cannot be reassigned' USING ERRCODE='23514';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(OLD.tenant_id::text,90427));
    v_removes_admin := TG_OP='DELETE';
    IF TG_OP='UPDATE' THEN v_removes_admin := NEW.access_state IS DISTINCT FROM 'active'; END IF;
    IF OLD.access_state='active' AND v_removes_admin AND EXISTS (
      SELECT 1 FROM platform_core.membership_roles a JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
      WHERE a.tenant_id=OLD.tenant_id AND a.user_id=OLD.user_id AND r.protects_tenant_admin
    ) THEN
      SELECT EXISTS(
        SELECT 1 FROM platform_core.tenant_memberships m
        JOIN auth.users u ON u.id=m.user_id
        JOIN platform_core.membership_roles a ON a.tenant_id=m.tenant_id AND a.user_id=m.user_id
        JOIN platform_core.tenant_roles r ON r.tenant_id=a.tenant_id AND r.role_id=a.role_id
        WHERE m.tenant_id=OLD.tenant_id AND m.user_id<>OLD.user_id AND m.access_state='active' AND r.protects_tenant_admin
          AND r.permission_snapshot @> ARRAY['tenant.administer']::text[]
          AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      ) INTO v_replacement_exists;
      IF NOT v_replacement_exists THEN RAISE EXCEPTION 'The final active Tenant administrator cannot be removed' USING ERRCODE='23514'; END IF;
    END IF;
  ELSIF TG_TABLE_NAME='membership_roles' THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(OLD.tenant_id::text,90427));
    IF EXISTS (
      SELECT 1 FROM platform_core.tenant_roles r WHERE r.tenant_id=OLD.tenant_id AND r.role_id=OLD.role_id
        AND r.protects_tenant_admin AND r.permission_snapshot @> ARRAY['tenant.administer']::text[]
    ) THEN
      v_removes_admin := TG_OP='DELETE';
      IF TG_OP='UPDATE' THEN
        v_removes_admin := NEW.tenant_id IS DISTINCT FROM OLD.tenant_id OR NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.role_id IS DISTINCT FROM OLD.role_id;
      END IF;
      IF v_removes_admin AND NOT EXISTS (
        SELECT 1 FROM platform_core.tenant_memberships m
        JOIN auth.users u ON u.id=m.user_id
        JOIN platform_core.membership_roles a ON a.tenant_id=m.tenant_id AND a.user_id=m.user_id
        JOIN platform_core.tenant_roles r ON r.tenant_id=a.tenant_id AND r.role_id=a.role_id
        WHERE m.tenant_id=OLD.tenant_id AND (m.user_id<>OLD.user_id OR a.role_id<>OLD.role_id)
          AND m.access_state='active' AND r.protects_tenant_admin
          AND r.permission_snapshot @> ARRAY['tenant.administer']::text[]
          AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      ) THEN RAISE EXCEPTION 'The final active Tenant administrator cannot be removed' USING ERRCODE='23514'; END IF;
    END IF;
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;

CREATE TABLE platform_core.tenant_member_invitations (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  target_email text NOT NULL CHECK (target_email = pg_catalog.lower(pg_catalog.btrim(target_email)) AND target_email <> '' AND pg_catalog.length(target_email) <= 254),
  created_by_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  lifecycle_state text NOT NULL DEFAULT 'pending' CHECK (lifecycle_state IN ('pending','accepted','expired','revoked')),
  delivery_state text NOT NULL DEFAULT 'sending' CHECK (delivery_state IN ('sending','sent','failed')),
  delivery_error_code text CHECK (delivery_error_code IS NULL OR pg_catalog.length(delivery_error_code) <= 80),
  issuance integer NOT NULL DEFAULT 1 CHECK (issuance > 0),
  expires_at timestamptz NOT NULL,
  accepted_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  accepted_at timestamptz,
  idempotency_key uuid NOT NULL,
  request_signature jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp(),
  UNIQUE (created_by_user_id,idempotency_key),
  CHECK ((lifecycle_state='accepted' AND accepted_user_id IS NOT NULL AND accepted_at IS NOT NULL)
    OR (lifecycle_state<>'accepted' AND accepted_user_id IS NULL AND accepted_at IS NULL))
);
CREATE UNIQUE INDEX tenant_member_invitation_one_pending_email_idx
  ON platform_core.tenant_member_invitations(tenant_id,target_email) WHERE lifecycle_state='pending';
CREATE INDEX tenant_member_invitation_tenant_history_idx
  ON platform_core.tenant_member_invitations(tenant_id,created_at DESC);

CREATE TABLE platform_core.tenant_membership_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
  invitation_id uuid REFERENCES platform_core.tenant_member_invitations(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  subject_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  target_email text,
  action text NOT NULL CHECK (action IN ('invitation_created','delivery_sent','delivery_failed','reissued','revoked','expired','accepted','already_member','deactivated','reactivated','credential_ready')),
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.transaction_timestamp()
);
ALTER TABLE platform_core.tenant_member_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_core.tenant_membership_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE platform_core.tenant_member_invitations, platform_core.tenant_membership_audit_events FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON SEQUENCE platform_core.tenant_membership_audit_events_id_seq FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION platform_core.prevent_member_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'Tenant membership audit is append-only' USING ERRCODE='55000'; END;
$function$;
CREATE TRIGGER tenant_membership_audit_append_only BEFORE UPDATE OR DELETE ON platform_core.tenant_membership_audit_events
FOR EACH ROW EXECUTE FUNCTION platform_core.prevent_member_audit_mutation();
REVOKE ALL ON FUNCTION platform_core.prevent_member_audit_mutation() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION platform_private.has_tenant_permission(p_tenant_id uuid,p_user_id uuid,p_permission text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT p_user_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM platform_core.tenants t
    JOIN platform_core.tenant_memberships m ON m.tenant_id=t.id
    JOIN platform_core.membership_roles mr ON mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
    JOIN platform_core.tenant_roles r ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id
    JOIN auth.users u ON u.id=m.user_id
    WHERE t.id=p_tenant_id AND t.lifecycle_state='active' AND m.user_id=p_user_id AND m.access_state='active'
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())
      AND r.permission_snapshot @> ARRAY[p_permission]::text[]
  );
$function$;
REVOKE ALL ON FUNCTION platform_private.has_tenant_permission(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.tenant_membership_snapshot(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_result jsonb; v_manage boolean;
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (SELECT 1 FROM platform_core.tenant_memberships m
    JOIN platform_core.tenants t ON t.id=m.tenant_id JOIN auth.users u ON u.id=m.user_id
    WHERE m.tenant_id=p_tenant_id AND m.user_id=v_actor AND m.access_state='active' AND t.lifecycle_state='active'
      AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
    RAISE EXCEPTION 'tenant_membership_forbidden' USING ERRCODE='42501';
  END IF;
  v_manage := platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage');
  SELECT pg_catalog.jsonb_build_object('tenant_id',t.id,'tenant_name',t.display_name,'lifecycle_state',t.lifecycle_state,
    'can_manage_members',v_manage,'member_email',u.email,'member_role',r.role_key)
    INTO v_result
  FROM platform_core.tenants t JOIN platform_core.tenant_memberships m ON m.tenant_id=t.id AND m.user_id=v_actor
  JOIN auth.users u ON u.id=m.user_id
  LEFT JOIN platform_core.membership_roles mr ON mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
  LEFT JOIN platform_core.tenant_roles r ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id AND NOT r.protects_tenant_admin
  WHERE t.id=p_tenant_id;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_membership_snapshot(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_membership_snapshot(uuid) TO authenticated;

CREATE FUNCTION public.current_tenant_memberships()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT COALESCE(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('tenant_id',t.id,'tenant_name',t.display_name) ORDER BY t.display_name),'[]'::jsonb)
  FROM platform_core.tenant_memberships m JOIN platform_core.tenants t ON t.id=m.tenant_id JOIN auth.users u ON u.id=m.user_id
  WHERE m.user_id=(SELECT auth.uid()) AND m.access_state='active' AND t.lifecycle_state='active'
    AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now());
$function$;
REVOKE ALL ON FUNCTION public.current_tenant_memberships() FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.current_tenant_memberships() TO authenticated;

CREATE FUNCTION public.tenant_member_access_list(p_tenant_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_rows jsonb; v_limits jsonb; v_usage integer; v_limit_rows integer;
BEGIN
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  WITH expired AS (
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=p_tenant_id AND lifecycle_state='pending' AND expires_at<=pg_catalog.now()
    RETURNING id,target_email,issuance
  )
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    SELECT p_tenant_id,id,v_actor,target_email,'expired',pg_catalog.jsonb_build_object('issuance',issuance) FROM expired;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('user_id',m.user_id,'email',u.email,'access_state',m.access_state,
    'role_key',r.role_key,'protected_admin',r.protects_tenant_admin) ORDER BY u.email)
  INTO v_rows FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
  LEFT JOIN platform_core.membership_roles mr ON mr.tenant_id=m.tenant_id AND mr.user_id=m.user_id
  LEFT JOIN platform_core.tenant_roles r ON r.tenant_id=mr.tenant_id AND r.role_id=mr.role_id
  WHERE m.tenant_id=p_tenant_id;
  SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships m
  WHERE m.tenant_id=p_tenant_id AND m.access_state='active';
  SELECT pg_catalog.count(*)::integer INTO v_limit_rows FROM platform_core.tenant_capability_limits l
  WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
    AND l.valid_from<=pg_catalog.transaction_timestamp()
    AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp());
  IF v_limit_rows<>1 THEN RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000'; END IF;
  SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',i.id,'target_email',i.target_email,'lifecycle_state',i.lifecycle_state,
    'delivery_state',i.delivery_state,'issuance',i.issuance,'expires_at',i.expires_at)
    ORDER BY i.created_at DESC) INTO v_limits FROM platform_core.tenant_member_invitations i WHERE i.tenant_id=p_tenant_id;
  RETURN pg_catalog.jsonb_build_object('memberships',COALESCE(v_rows,'[]'::jsonb),'invitations',COALESCE(v_limits,'[]'::jsonb),
    'seat_usage',v_usage,'seat_limit',(
      SELECT pg_catalog.jsonb_build_object('mode',l.limit_mode,'value',l.limit_value)
      FROM platform_core.tenant_capability_limits l WHERE l.tenant_id=p_tenant_id AND l.capability_key='tenant.users'
        AND l.valid_from<=pg_catalog.transaction_timestamp() AND (l.valid_until IS NULL OR l.valid_until>pg_catalog.transaction_timestamp())
    ));
END;
$function$;
REVOKE ALL ON FUNCTION public.tenant_member_access_list(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.tenant_member_access_list(uuid) TO authenticated;

CREATE FUNCTION public.create_tenant_member_invitation(p_tenant_id uuid,p_target_email text,p_idempotency_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_email text := pg_catalog.lower(pg_catalog.btrim(p_target_email));
  v_signature jsonb; v_row platform_core.tenant_member_invitations%ROWTYPE; v_existing jsonb;
BEGIN
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_email IS NULL OR v_email='' OR pg_catalog.length(v_email)>254 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' OR p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'tenant_member_invite_invalid' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  v_signature := pg_catalog.jsonb_build_object('tenant_id',p_tenant_id,'target_email',v_email,'role','tenant.member.v1');
  SELECT * INTO v_row FROM platform_core.tenant_member_invitations WHERE created_by_user_id=v_actor AND idempotency_key=p_idempotency_key FOR UPDATE;
  IF FOUND THEN
    IF v_row.request_signature<>v_signature THEN RAISE EXCEPTION 'tenant_member_invite_idempotency_conflict' USING ERRCODE='P0001'; END IF;
    RETURN pg_catalog.jsonb_build_object('id',v_row.id,'issuance',v_row.issuance,'target_email',v_row.target_email,
      'lifecycle_state',v_row.lifecycle_state,'delivery_state',v_row.delivery_state,'created',false,'state','existing');
  END IF;
  SELECT pg_catalog.jsonb_build_object('id',m.user_id,'access_state',m.access_state) INTO v_existing
  FROM platform_core.tenant_memberships m JOIN auth.users u ON u.id=m.user_id
  WHERE m.tenant_id=p_tenant_id AND pg_catalog.lower(u.email)=v_email;
  IF v_existing->>'access_state'='active' THEN RETURN pg_catalog.jsonb_build_object('created',false,'state','already_member'); END IF;
  IF v_existing IS NOT NULL AND EXISTS (
    SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING (tenant_id,role_id)
    WHERE mr.tenant_id=p_tenant_id AND mr.user_id=(v_existing->>'id')::uuid AND r.protects_tenant_admin
  ) THEN
    RAISE EXCEPTION 'tenant_member_admin_requires_governed_change' USING ERRCODE='42501';
  END IF;
  WITH expired AS (
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp()
    WHERE tenant_id=p_tenant_id AND target_email=v_email AND lifecycle_state='pending' AND expires_at<=pg_catalog.now()
    RETURNING id,target_email,issuance
  )
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    SELECT p_tenant_id,id,v_actor,target_email,'expired',pg_catalog.jsonb_build_object('issuance',issuance) FROM expired;
  SELECT * INTO v_row FROM platform_core.tenant_member_invitations WHERE tenant_id=p_tenant_id AND target_email=v_email AND lifecycle_state='pending' FOR UPDATE;
  IF FOUND THEN RETURN pg_catalog.jsonb_build_object('id',v_row.id,'issuance',v_row.issuance,'target_email',v_row.target_email,
    'lifecycle_state',v_row.lifecycle_state,'delivery_state',v_row.delivery_state,'created',false,'state','pending_exists'); END IF;
  INSERT INTO platform_core.tenant_roles(tenant_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
  VALUES(p_tenant_id,'tenant.member.v1',1,ARRAY[]::text[],false) ON CONFLICT(tenant_id,role_key,role_version) DO NOTHING;
  INSERT INTO platform_core.tenant_member_invitations(tenant_id,target_email,created_by_user_id,expires_at,idempotency_key,request_signature)
    VALUES(p_tenant_id,v_email,v_actor,pg_catalog.transaction_timestamp()+interval '7 days',p_idempotency_key,v_signature)
    RETURNING * INTO v_row;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(p_tenant_id,v_row.id,v_actor,v_email,'invitation_created',pg_catalog.jsonb_build_object('issuance',1,'role','tenant.member.v1'));
  RETURN pg_catalog.jsonb_build_object('id',v_row.id,'issuance',v_row.issuance,'target_email',v_email,'lifecycle_state','pending','delivery_state','sending','created',true,'state','created');
END;
$function$;
REVOKE ALL ON FUNCTION public.create_tenant_member_invitation(uuid,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.create_tenant_member_invitation(uuid,text,uuid) TO authenticated;

CREATE FUNCTION public.record_tenant_member_invitation_delivery(p_invitation_id uuid,p_issuance integer,p_actor_user_id uuid,p_succeeded boolean,p_error_code text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := p_actor_user_id; v_inv platform_core.tenant_member_invitations%ROWTYPE;
BEGIN
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR v_inv.issuance<>p_issuance OR v_inv.lifecycle_state<>'pending'
    OR NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='42501';
  END IF;
  UPDATE platform_core.tenant_member_invitations SET delivery_state=CASE WHEN p_succeeded THEN 'sent' ELSE 'failed' END,
    delivery_error_code=CASE WHEN p_succeeded THEN NULL ELSE pg_catalog.left(COALESCE(p_error_code,'auth_invite_failed'),80) END,
    updated_at=pg_catalog.clock_timestamp() WHERE id=p_invitation_id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,CASE WHEN p_succeeded THEN 'delivery_sent' ELSE 'delivery_failed' END,
      pg_catalog.jsonb_build_object('issuance',p_issuance,'error_code',CASE WHEN p_succeeded THEN NULL ELSE p_error_code END));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_tenant_member_invitation_delivery(uuid,integer,uuid,boolean,text) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.record_tenant_member_invitation_delivery(uuid,integer,uuid,boolean,text) TO service_role;

CREATE FUNCTION public.reissue_tenant_member_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_inv platform_core.tenant_member_invitations%ROWTYPE;
BEGIN
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  IF v_inv.lifecycle_state='pending' AND v_inv.expires_at<=pg_catalog.now() THEN
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
    INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
      VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'expired',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
    RETURN pg_catalog.jsonb_build_object('state','expired','created',false);
  END IF;
  IF v_inv.lifecycle_state<>'pending' THEN RETURN pg_catalog.jsonb_build_object('state',v_inv.lifecycle_state,'created',false); END IF;
  UPDATE platform_core.tenant_member_invitations SET issuance=issuance+1,expires_at=pg_catalog.transaction_timestamp()+interval '7 days',
    delivery_state='sending',delivery_error_code=NULL,updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id RETURNING * INTO v_inv;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'reissued',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
  RETURN pg_catalog.jsonb_build_object('id',v_inv.id,'issuance',v_inv.issuance,'target_email',v_inv.target_email,
    'lifecycle_state',v_inv.lifecycle_state,'delivery_state',v_inv.delivery_state,'created',true,'state','reissued');
END;
$function$;
REVOKE ALL ON FUNCTION public.reissue_tenant_member_invitation(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.reissue_tenant_member_invitation(uuid) TO authenticated;

CREATE FUNCTION public.revoke_tenant_member_invitation(p_invitation_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_inv platform_core.tenant_member_invitations%ROWTYPE;
BEGIN
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND OR NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_actor,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501';
  END IF;
  IF v_inv.lifecycle_state<>'pending' THEN RETURN false; END IF;
  UPDATE platform_core.tenant_member_invitations SET lifecycle_state='revoked',updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'revoked',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.revoke_tenant_member_invitation(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.revoke_tenant_member_invitation(uuid) TO authenticated;

CREATE FUNCTION public.validate_tenant_member_invitation(p_invitation_id uuid,p_issuance integer)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_inv platform_core.tenant_member_invitations%ROWTYPE; v_email text; v_ready boolean;
BEGIN
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND OR v_inv.issuance<>p_issuance OR v_inv.lifecycle_state<>'pending' OR v_inv.expires_at<=pg_catalog.now() THEN RETURN 'unavailable'; END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN RETURN 'issuer_authority_lost'; END IF;
  SELECT u.email, (u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND
    (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id)))
    INTO v_email,v_ready FROM auth.users u JOIN platform_core.tenants t ON t.id=v_inv.tenant_id
    WHERE u.id=v_actor AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND t.lifecycle_state='active';
  IF NOT FOUND THEN RETURN 'identity_mismatch'; END IF;
  IF pg_catalog.lower(v_email)<>v_inv.target_email THEN RETURN 'identity_mismatch'; END IF;
  RETURN CASE WHEN v_ready THEN 'ready' ELSE 'password_required' END;
END;
$function$;
REVOKE ALL ON FUNCTION public.validate_tenant_member_invitation(uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.validate_tenant_member_invitation(uuid,integer) TO authenticated;

CREATE FUNCTION public.record_tenant_member_password_readiness(p_invitation_id uuid,p_issuance integer,p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_inv platform_core.tenant_member_invitations%ROWTYPE; v_email text;
BEGIN
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id AND issuance=p_issuance
    AND lifecycle_state='pending' AND expires_at>pg_catalog.now() FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  SELECT u.email INTO v_email FROM auth.users u WHERE u.id=p_user_id AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
    AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now()) AND u.invited_at IS NOT NULL
    AND u.encrypted_password IS NOT NULL AND u.encrypted_password<>'';
  IF v_email IS NULL OR pg_catalog.lower(v_email)<>v_inv.target_email THEN RAISE EXCEPTION 'tenant_member_invite_identity_mismatch' USING ERRCODE='42501'; END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  INSERT INTO platform_private.platform_auth_password_readiness(user_id,source_workflow,source_invitation_id,source_issuance)
    VALUES(p_user_id,'tenant_member_invitation',p_invitation_id,p_issuance) ON CONFLICT(user_id) DO NOTHING;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,p_user_id,v_inv.target_email,'credential_ready',pg_catalog.jsonb_build_object('issuance',p_issuance));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.record_tenant_member_password_readiness(uuid,integer,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_tenant_member_password_readiness(uuid,integer,uuid) TO service_role;

CREATE FUNCTION public.accept_tenant_member_invitation(p_invitation_id uuid,p_issuance integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_inv platform_core.tenant_member_invitations%ROWTYPE; v_tenant_state text; v_lock_tenant uuid;
  v_limit_mode text; v_limit integer; v_count integer; v_membership_state text; v_role uuid; v_email text; v_ready boolean;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'tenant_member_identity_required' USING ERRCODE='42501'; END IF;
  SELECT tenant_id INTO v_lock_tenant FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_lock_tenant::text,90427));
  SELECT * INTO v_inv FROM platform_core.tenant_member_invitations WHERE id=p_invitation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF v_inv.issuance<>p_issuance THEN RAISE EXCEPTION 'tenant_member_invite_stale_issuance' USING ERRCODE='P0001'; END IF;
  IF v_inv.lifecycle_state='accepted' AND v_inv.accepted_user_id=v_actor THEN RETURN pg_catalog.jsonb_build_object('state','accepted','tenant_id',v_inv.tenant_id); END IF;
  IF v_inv.lifecycle_state<>'pending' THEN RAISE EXCEPTION 'tenant_member_invite_unavailable' USING ERRCODE='P0001'; END IF;
  IF v_inv.expires_at<=pg_catalog.now() THEN
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='expired',updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
    INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,target_email,action,details)
      VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_inv.target_email,'expired',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
    RETURN pg_catalog.jsonb_build_object('state','expired');
  END IF;
  IF NOT platform_private.has_tenant_permission(v_inv.tenant_id,v_inv.created_by_user_id,'tenant.members.manage') THEN
    RAISE EXCEPTION 'tenant_member_invite_issuer_authority_lost' USING ERRCODE='42501';
  END IF;
  SELECT u.email,u.encrypted_password IS NOT NULL AND u.encrypted_password<>'' AND
    (u.invited_at IS NULL OR EXISTS(SELECT 1 FROM platform_private.platform_auth_password_readiness r WHERE r.user_id=u.id))
    INTO v_email,v_ready FROM auth.users u WHERE u.id=v_actor AND u.deleted_at IS NULL AND u.email_confirmed_at IS NOT NULL
      AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now());
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_member_identity_unverified' USING ERRCODE='42501'; END IF;
  IF pg_catalog.lower(v_email)<>v_inv.target_email THEN RAISE EXCEPTION 'tenant_member_identity_mismatch' USING ERRCODE='42501'; END IF;
  IF NOT v_ready THEN RAISE EXCEPTION 'tenant_member_password_required' USING ERRCODE='42501'; END IF;
  SELECT lifecycle_state INTO v_tenant_state FROM platform_core.tenants WHERE id=v_inv.tenant_id FOR UPDATE;
  IF v_tenant_state IS DISTINCT FROM 'active' THEN RAISE EXCEPTION 'tenant_member_tenant_unavailable' USING ERRCODE='42501'; END IF;
  SELECT access_state INTO v_membership_state FROM platform_core.tenant_memberships WHERE tenant_id=v_inv.tenant_id AND user_id=v_actor FOR UPDATE;
  IF v_membership_state='active' THEN
    UPDATE platform_core.tenant_member_invitations SET lifecycle_state='accepted',accepted_user_id=v_actor,accepted_at=pg_catalog.clock_timestamp(),updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
    INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,subject_user_id,target_email,action,details)
      VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_actor,v_inv.target_email,'already_member',pg_catalog.jsonb_build_object('issuance',v_inv.issuance));
    RETURN pg_catalog.jsonb_build_object('state','already_member','tenant_id',v_inv.tenant_id);
  END IF;
  IF v_membership_state='inactive' AND EXISTS (
    SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING(tenant_id,role_id)
    WHERE mr.tenant_id=v_inv.tenant_id AND mr.user_id=v_actor AND r.protects_tenant_admin
  ) THEN RAISE EXCEPTION 'tenant_member_admin_requires_governed_change' USING ERRCODE='42501'; END IF;
  SELECT limit_mode,limit_value INTO v_limit_mode,v_limit FROM platform_core.tenant_capability_limits
    WHERE tenant_id=v_inv.tenant_id AND capability_key='tenant.users' AND valid_from<=pg_catalog.transaction_timestamp()
      AND (valid_until IS NULL OR valid_until>pg_catalog.transaction_timestamp());
  IF NOT FOUND OR v_limit_mode NOT IN ('limited','unlimited') OR (v_limit_mode='limited' AND (v_limit IS NULL OR v_limit<=0)) THEN
    RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000';
  END IF;
  SELECT pg_catalog.count(*)::integer INTO v_count FROM platform_core.tenant_memberships WHERE tenant_id=v_inv.tenant_id AND access_state='active';
  IF v_limit_mode='limited' AND v_count>=v_limit AND v_membership_state IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'tenant_member_limit_full' USING ERRCODE='P0001';
  END IF;
  SELECT role_id INTO v_role FROM platform_core.tenant_roles WHERE tenant_id=v_inv.tenant_id AND role_key='tenant.member.v1' AND role_version=1;
  IF v_role IS NULL THEN RAISE EXCEPTION 'tenant_member_role_unavailable' USING ERRCODE='55000'; END IF;
  IF v_membership_state='inactive' THEN
    UPDATE platform_core.tenant_memberships SET access_state='active' WHERE tenant_id=v_inv.tenant_id AND user_id=v_actor;
    DELETE FROM platform_core.membership_roles WHERE tenant_id=v_inv.tenant_id AND user_id=v_actor;
  ELSE
    INSERT INTO platform_core.tenant_memberships(tenant_id,user_id,access_state,created_by_operator_id)
      VALUES(v_inv.tenant_id,v_actor,'active',v_inv.created_by_user_id);
  END IF;
  INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(v_inv.tenant_id,v_actor,v_role)
    ON CONFLICT DO NOTHING;
  UPDATE platform_core.tenant_member_invitations SET lifecycle_state='accepted',accepted_user_id=v_actor,accepted_at=pg_catalog.clock_timestamp(),updated_at=pg_catalog.clock_timestamp() WHERE id=v_inv.id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,invitation_id,actor_user_id,subject_user_id,target_email,action,details)
    VALUES(v_inv.tenant_id,v_inv.id,v_actor,v_actor,v_inv.target_email,CASE WHEN v_membership_state='inactive' THEN 'reactivated' ELSE 'accepted' END,
      pg_catalog.jsonb_build_object('issuance',v_inv.issuance,'role','tenant.member.v1'));
  RETURN pg_catalog.jsonb_build_object('state','accepted','tenant_id',v_inv.tenant_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.accept_tenant_member_invitation(uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.accept_tenant_member_invitation(uuid,integer) TO authenticated;

CREATE FUNCTION public.set_tenant_member_access(p_tenant_id uuid,p_user_id uuid,p_access_state text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_actor uuid := (SELECT auth.uid()); v_previous text; v_limit_mode text; v_limit integer; v_usage integer; v_role uuid;
BEGIN
  IF p_access_state NOT IN ('active','inactive') THEN RAISE EXCEPTION 'tenant_membership_state_invalid' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text,90427));
  IF NOT platform_private.has_tenant_permission(p_tenant_id,v_actor,'tenant.members.manage') THEN RAISE EXCEPTION 'tenant_members_manage_forbidden' USING ERRCODE='42501'; END IF;
  SELECT access_state INTO v_previous FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant_id AND user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant_membership_not_found' USING ERRCODE='P0002'; END IF;
  IF v_previous=p_access_state THEN RETURN true; END IF;
  IF EXISTS (
    SELECT 1 FROM platform_core.membership_roles mr JOIN platform_core.tenant_roles r USING (tenant_id,role_id)
    WHERE mr.tenant_id=p_tenant_id AND mr.user_id=p_user_id AND r.protects_tenant_admin
  ) THEN
    RAISE EXCEPTION 'tenant_member_admin_requires_governed_change' USING ERRCODE='42501';
  END IF;
  IF p_access_state='active' THEN
    IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=p_user_id AND u.deleted_at IS NULL
      AND u.email_confirmed_at IS NOT NULL AND (u.banned_until IS NULL OR u.banned_until<=pg_catalog.now())) THEN
      RAISE EXCEPTION 'tenant_member_target_unavailable' USING ERRCODE='42501';
    END IF;
    SELECT limit_mode,limit_value INTO v_limit_mode,v_limit FROM platform_core.tenant_capability_limits WHERE tenant_id=p_tenant_id AND capability_key='tenant.users'
      AND valid_from<=pg_catalog.transaction_timestamp() AND (valid_until IS NULL OR valid_until>pg_catalog.transaction_timestamp());
    IF NOT FOUND OR v_limit_mode NOT IN ('limited','unlimited') OR (v_limit_mode='limited' AND (v_limit IS NULL OR v_limit<=0)) THEN RAISE EXCEPTION 'tenant_member_limit_unavailable' USING ERRCODE='55000'; END IF;
    SELECT pg_catalog.count(*)::integer INTO v_usage FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant_id AND access_state='active';
    IF v_limit_mode='limited' AND v_usage>=v_limit THEN RAISE EXCEPTION 'tenant_member_limit_full' USING ERRCODE='P0001'; END IF;
    INSERT INTO platform_core.tenant_roles(tenant_id,role_key,role_version,permission_snapshot,protects_tenant_admin)
      VALUES(p_tenant_id,'tenant.member.v1',1,ARRAY[]::text[],false) ON CONFLICT(tenant_id,role_key,role_version) DO NOTHING;
    SELECT role_id INTO v_role FROM platform_core.tenant_roles WHERE tenant_id=p_tenant_id AND role_key='tenant.member.v1' AND role_version=1;
    IF v_role IS NULL THEN RAISE EXCEPTION 'tenant_member_role_unavailable' USING ERRCODE='55000'; END IF;
    DELETE FROM platform_core.membership_roles WHERE tenant_id=p_tenant_id AND user_id=p_user_id;
    INSERT INTO platform_core.membership_roles(tenant_id,user_id,role_id) VALUES(p_tenant_id,p_user_id,v_role);
  END IF;
  UPDATE platform_core.tenant_memberships SET access_state=p_access_state WHERE tenant_id=p_tenant_id AND user_id=p_user_id;
  INSERT INTO platform_core.tenant_membership_audit_events(tenant_id,actor_user_id,subject_user_id,action,details)
    VALUES(p_tenant_id,v_actor,p_user_id,CASE WHEN p_access_state='active' THEN 'reactivated' ELSE 'deactivated' END,
      pg_catalog.jsonb_build_object('from',v_previous,'to',p_access_state));
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.set_tenant_member_access(uuid,uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.set_tenant_member_access(uuid,uuid,text) TO authenticated;
