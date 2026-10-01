-- Add an unpaged latest event to the existing scoped cancellation-history response.
-- Keep row authorization, paging, payload and wrapper semantics unchanged.
CREATE OR REPLACE FUNCTION public.leave_cancellation_history(p_tenant uuid,p_request uuid,p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); r leave.requests%ROWTYPE; employee uuid; hr_read boolean;
  lim integer:=least(100,greatest(1,coalesce(p_limit,50))); off integer:=coalesce(p_offset,0);
  items jsonb; more boolean; latest_event jsonb;
BEGIN
  IF actor IS NULL OR p_request IS NULL OR off<0 THEN RAISE EXCEPTION 'leave_page_invalid' USING ERRCODE='22023'; END IF;
  SELECT * INTO r FROM leave.requests x WHERE x.tenant_id=p_tenant AND x.id=p_request;
  IF NOT FOUND THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  hr_read:=leave.request_hr_can_read(p_tenant,actor);
  IF hr_read THEN
    actor:=leave.authorized(p_tenant,CASE WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.view') THEN 'leave.view'
      WHEN platform_private.has_tenant_permission(p_tenant,actor,'leave.manage') THEN 'leave.manage' ELSE 'leave.approve' END,false);
  ELSE
    IF NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.view') THEN
      RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002';
    END IF;
    SELECT l.employee_id INTO employee FROM people.employee_user_links l
      WHERE l.tenant_id=p_tenant AND l.user_id=actor AND l.unlinked_at IS NULL;
    IF employee IS DISTINCT FROM r.employee_id THEN RAISE EXCEPTION 'leave_request_unavailable' USING ERRCODE='P0002'; END IF;
  END IF;

  SELECT pg_catalog.jsonb_build_object(
      'id',ev.id,'cancellation_id',ev.cancellation_id,'actor_user_id',ev.actor_user_id,'event_key',ev.event_key,
      'from_state',ev.from_state,'to_state',ev.to_state,'from_version',ev.from_version,'to_version',ev.to_version,
      'reason',ev.reason,'result',ev.result,'time_reconciliation_required',ev.time_reconciliation_required,
      'time_fact_refs',ev.time_fact_refs,'created_at',ev.created_at)
    INTO latest_event
    FROM leave.cancellation_events ev
    WHERE ev.tenant_id=p_tenant AND ev.request_id=p_request
    ORDER BY ev.id DESC LIMIT 1;

  WITH page AS MATERIALIZED (
    SELECT ev.* FROM leave.cancellation_events ev WHERE ev.tenant_id=p_tenant AND ev.request_id=p_request
    ORDER BY ev.id OFFSET off LIMIT lim+1
  ), numbered AS MATERIALIZED (
    SELECT page.*,pg_catalog.row_number() OVER(ORDER BY id) rn FROM page
  )
  SELECT coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',id,'cancellation_id',cancellation_id,'actor_user_id',actor_user_id,'event_key',event_key,
      'from_state',from_state,'to_state',to_state,'from_version',from_version,'to_version',to_version,
      'reason',reason,'result',result,'time_reconciliation_required',time_reconciliation_required,
      'time_fact_refs',time_fact_refs,'created_at',created_at) ORDER BY id)
      FROM numbered WHERE rn<=lim),'[]'::jsonb),EXISTS(SELECT 1 FROM numbered WHERE rn>lim)
    INTO items,more;
  RETURN pg_catalog.jsonb_build_object('request_id',p_request,'items',items,'limit',lim,
    'offset',off,'has_more',more,'latest_event',latest_event);
END $f$;
REVOKE ALL ON FUNCTION public.leave_cancellation_history(uuid,uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_cancellation_history(uuid,uuid,integer,integer) TO authenticated;
