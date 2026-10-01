-- Employee pages must retain own-only scope even when the actor also has HR roles.
CREATE FUNCTION public.leave_my_request_detail(p_tenant uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); result jsonb;
BEGIN
  IF actor IS NULL OR p_tenant IS NULL OR p_request IS NULL
     OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  SELECT leave.request_json(p_tenant,r.id) INTO result
  FROM leave.requests r
  JOIN people.employee_user_links l ON l.tenant_id=r.tenant_id AND l.employee_id=r.employee_id
    AND l.user_id=actor AND l.unlinked_at IS NULL
  WHERE r.tenant_id=p_tenant AND r.id=p_request;
  IF result IS NULL THEN
    RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
  END IF;
  RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_request_detail(uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_request_detail(uuid,uuid) TO authenticated;
