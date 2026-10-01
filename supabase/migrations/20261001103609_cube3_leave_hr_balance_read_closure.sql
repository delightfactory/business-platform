-- External draft against 6abdecb: additive narrow HR balance reads/selectors.
-- Root must generate a fresh migration filename before importing.
CREATE INDEX leave_ledger_balance_history_page ON leave.ledger_entries(tenant_id,account_id,created_at DESC,id DESC);
CREATE FUNCTION leave.authorized_balance_read(p_tenant uuid)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF platform_private.has_tenant_permission(p_tenant,auth.uid(),'leave.view') THEN
  RETURN leave.authorized(p_tenant,'leave.view',false);
 END IF;
 RETURN leave.authorized(p_tenant,'leave_balance.adjust',false);
END $f$;
REVOKE ALL ON FUNCTION leave.authorized_balance_read(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.balance_pair_snapshot(p_tenant uuid,p_employee uuid,p_employer uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE pair jsonb; enabled boolean; active_employment boolean; employer_active boolean; can_adjust boolean;
 today date:=(pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date; blocked text;
BEGIN
 SELECT pg_catalog.jsonb_build_object('employee_id',e.id,'employee_code',e.employee_code,
  'employee_name',e.full_name,'employer_entity_id',ent.id,'employer_name',ent.display_name,
  'employer_is_active',ent.is_active),ent.is_active INTO pair,employer_active
 FROM people.employees e JOIN platform_core.tenant_legal_entities ent ON ent.tenant_id=e.tenant_id AND ent.id=p_employer
 WHERE e.tenant_id=p_tenant AND e.id=p_employee
  AND (EXISTS(SELECT 1 FROM people.employments em WHERE em.tenant_id=e.tenant_id AND em.employee_id=e.id AND em.employer_entity_id=ent.id)
   OR EXISTS(SELECT 1 FROM leave.accounts ac WHERE ac.tenant_id=e.tenant_id AND ac.employee_id=e.id AND ac.employer_entity_id=ent.id));
 IF pair IS NULL THEN RAISE EXCEPTION 'leave_balance_scope_unavailable' USING ERRCODE='P0002'; END IF;
 SELECT EXISTS(SELECT 1 FROM people.employments em WHERE em.tenant_id=p_tenant AND em.employee_id=p_employee
  AND em.employer_entity_id=p_employer AND em.employment_status='active' AND em.start_date<=today
  AND (em.end_date IS NULL OR em.end_date>=today)) INTO active_employment;
 enabled:=platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
  AND platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now());
 can_adjust:=platform_private.has_tenant_permission(p_tenant,auth.uid(),'leave_balance.adjust');
 blocked:=CASE WHEN NOT can_adjust THEN 'adjust_permission_required' WHEN NOT enabled THEN 'new_work_disabled'
  WHEN NOT employer_active THEN 'employer_inactive' WHEN NOT active_employment THEN 'active_employment_required' ELSE NULL END;
 RETURN pair||pg_catalog.jsonb_build_object('has_active_employment',active_employment,'new_work_enabled',enabled,
  'can_adjust',can_adjust,'can_post',blocked IS NULL,'posting_blocked_reason',blocked);
END $f$;
REVOKE ALL ON FUNCTION leave.balance_pair_snapshot(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_balance_employee_options(
 p_tenant uuid,p_query text,p_employer uuid DEFAULT NULL,p_after_code text DEFAULT NULL,
 p_after_employee uuid DEFAULT NULL,p_after_employer uuid DEFAULT NULL,p_limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE q text:=pg_catalog.btrim(p_query); items jsonb; more boolean; next_code text; next_employee uuid; next_employer uuid;
BEGIN
 PERFORM leave.authorized_balance_read(p_tenant);
 IF q IS NULL OR pg_catalog.length(q) NOT BETWEEN 2 AND 80 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50
  OR ((p_after_code IS NULL)::int+(p_after_employee IS NULL)::int+(p_after_employer IS NULL)::int) NOT IN(0,3)
  OR (p_after_code IS NOT NULL AND (p_after_code='' OR pg_catalog.length(p_after_code)>120)) THEN
  RAISE EXCEPTION 'leave_balance_search_input_invalid' USING ERRCODE='22023'; END IF;
 IF p_employer IS NOT NULL AND NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer) THEN
  RAISE EXCEPTION 'leave_balance_scope_unavailable' USING ERRCODE='P0002'; END IF;
 WITH pairs AS MATERIALIZED (
  SELECT em.employee_id,em.employer_entity_id FROM people.employments em WHERE em.tenant_id=p_tenant
  UNION SELECT ac.employee_id,ac.employer_entity_id FROM leave.accounts ac WHERE ac.tenant_id=p_tenant
 ), page AS MATERIALIZED (
  SELECT e.id employee_id,e.employee_code,p.employer_entity_id,
   leave.balance_pair_snapshot(p_tenant,e.id,p.employer_entity_id) item
  FROM pairs p JOIN people.employees e ON e.tenant_id=p_tenant AND e.id=p.employee_id
  WHERE (p_employer IS NULL OR p.employer_entity_id=p_employer)
   AND (pg_catalog.strpos(pg_catalog.lower(e.employee_code),pg_catalog.lower(q))>0
    OR pg_catalog.strpos(pg_catalog.lower(e.full_name),pg_catalog.lower(q))>0)
   AND (p_after_code IS NULL OR (e.employee_code,e.id,p.employer_entity_id)>(p_after_code,p_after_employee,p_after_employer))
  ORDER BY e.employee_code,e.id,p.employer_entity_id LIMIT p_limit+1
 ), numbered AS (SELECT p.*,pg_catalog.row_number() OVER(ORDER BY employee_code,employee_id,employer_entity_id) rn FROM page p)
 SELECT coalesce(pg_catalog.jsonb_agg(item ORDER BY rn) FILTER(WHERE rn<=p_limit),'[]'::jsonb),
  EXISTS(SELECT 1 FROM numbered WHERE rn>p_limit),(SELECT employee_code FROM numbered WHERE rn=p_limit),
  (SELECT employee_id FROM numbered WHERE rn=p_limit),(SELECT employer_entity_id FROM numbered WHERE rn=p_limit)
 INTO items,more,next_code,next_employee,next_employer FROM numbered;
 RETURN pg_catalog.jsonb_build_object('items',items,'limit',p_limit,'has_more',more,
  'next_after_code',CASE WHEN more THEN next_code END,'next_after_employee',CASE WHEN more THEN next_employee END,
  'next_after_employer',CASE WHEN more THEN next_employer END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_balance_employee_options(uuid,text,uuid,text,uuid,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_balance_employee_options(uuid,text,uuid,text,uuid,uuid,integer) TO authenticated;

CREATE FUNCTION public.leave_balance_accounts(p_tenant uuid,p_employee uuid,p_employer uuid,
 p_after_period_start date DEFAULT NULL,p_after_account uuid DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE pair jsonb; items jsonb; more boolean; next_start date; next_account uuid;
BEGIN
 PERFORM leave.authorized_balance_read(p_tenant);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR ((p_after_period_start IS NULL)<>(p_after_account IS NULL)) THEN
  RAISE EXCEPTION 'leave_balance_accounts_input_invalid' USING ERRCODE='22023'; END IF;
 pair:=leave.balance_pair_snapshot(p_tenant,p_employee,p_employer);
 WITH page AS MATERIALIZED (
  SELECT ac.id,yp.starts_on,pg_catalog.jsonb_build_object('account_id',ac.id,'employee_id',ac.employee_id,
   'employer_entity_id',ac.employer_entity_id,'leave_type_id',ac.leave_type_id,'type_code',t.code,'type_name',t.name,
   'type_is_active',t.is_active,'period_id',yp.id,'period_label',yp.label,'starts_on',yp.starts_on,'ends_on',yp.ends_on,
   'balance_days',(SELECT coalesce(sum(l.delta_days),0) FROM leave.ledger_entries l WHERE l.tenant_id=ac.tenant_id AND l.account_id=ac.id),
   'has_opening',EXISTS(SELECT 1 FROM leave.ledger_entries l WHERE l.tenant_id=ac.tenant_id AND l.account_id=ac.id AND l.entry_kind='opening'),
   'has_annual_grant',EXISTS(SELECT 1 FROM leave.ledger_entries l WHERE l.tenant_id=ac.tenant_id AND l.account_id=ac.id AND l.entry_kind='annual_grant')) item
  FROM leave.accounts ac JOIN leave.types t ON t.tenant_id=ac.tenant_id AND t.id=ac.leave_type_id AND t.employer_entity_id=ac.employer_entity_id
  JOIN leave.year_periods yp ON yp.tenant_id=ac.tenant_id AND yp.id=ac.year_period_id AND yp.employer_entity_id=ac.employer_entity_id
  WHERE ac.tenant_id=p_tenant AND ac.employee_id=p_employee AND ac.employer_entity_id=p_employer
   AND (p_after_period_start IS NULL OR (yp.starts_on,ac.id)>(p_after_period_start,p_after_account))
  ORDER BY yp.starts_on,ac.id LIMIT p_limit+1
 ), numbered AS (SELECT p.*,pg_catalog.row_number() OVER(ORDER BY starts_on,id) rn FROM page p)
 SELECT coalesce(pg_catalog.jsonb_agg(item ORDER BY rn) FILTER(WHERE rn<=p_limit),'[]'::jsonb),
  EXISTS(SELECT 1 FROM numbered WHERE rn>p_limit),(SELECT starts_on FROM numbered WHERE rn=p_limit),
  (SELECT id FROM numbered WHERE rn=p_limit) INTO items,more,next_start,next_account FROM numbered;
 RETURN pg_catalog.jsonb_build_object('employee',pair,'items',items,'limit',p_limit,'has_more',more,
  'next_after_period_start',CASE WHEN more THEN next_start END,'next_after_account',CASE WHEN more THEN next_account END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_balance_accounts(uuid,uuid,uuid,date,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_balance_accounts(uuid,uuid,uuid,date,uuid,integer) TO authenticated;

CREATE FUNCTION public.leave_balance_ledger(p_tenant uuid,p_employee uuid,p_employer uuid,p_account uuid,
 p_before_created_at timestamptz DEFAULT NULL,p_before_entry uuid DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE pair jsonb; account jsonb; items jsonb; more boolean; next_at timestamptz; next_entry uuid;
BEGIN
 PERFORM leave.authorized_balance_read(p_tenant);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR ((p_before_created_at IS NULL)<>(p_before_entry IS NULL)) THEN
  RAISE EXCEPTION 'leave_balance_ledger_input_invalid' USING ERRCODE='22023'; END IF;
 pair:=leave.balance_pair_snapshot(p_tenant,p_employee,p_employer);
 SELECT pg_catalog.jsonb_build_object('account_id',ac.id,'leave_type_id',ac.leave_type_id,'type_name',t.name,
  'period_id',yp.id,'period_label',yp.label,'starts_on',yp.starts_on,'ends_on',yp.ends_on,
  'balance_days',(SELECT coalesce(sum(l.delta_days),0) FROM leave.ledger_entries l WHERE l.tenant_id=ac.tenant_id AND l.account_id=ac.id))
 INTO account FROM leave.accounts ac JOIN leave.types t ON t.tenant_id=ac.tenant_id AND t.id=ac.leave_type_id AND t.employer_entity_id=ac.employer_entity_id
 JOIN leave.year_periods yp ON yp.tenant_id=ac.tenant_id AND yp.id=ac.year_period_id AND yp.employer_entity_id=ac.employer_entity_id
 WHERE ac.tenant_id=p_tenant AND ac.id=p_account AND ac.employee_id=p_employee AND ac.employer_entity_id=p_employer;
 IF account IS NULL THEN RAISE EXCEPTION 'leave_balance_scope_unavailable' USING ERRCODE='P0002'; END IF;
 WITH page AS MATERIALIZED (
  SELECT l.* FROM leave.ledger_entries l WHERE l.tenant_id=p_tenant AND l.account_id=p_account
   AND (p_before_created_at IS NULL OR (l.created_at,l.id)<(p_before_created_at,p_before_entry))
  ORDER BY l.created_at DESC,l.id DESC LIMIT p_limit+1
 ), enriched AS (
  SELECT l.created_at,l.id,pg_catalog.jsonb_build_object('entry_id',l.id,'account_id',l.account_id,'entry_kind',l.entry_kind,
   'delta_days',l.delta_days,'created_at',l.created_at,'actor_user_id',l.actor_user_id,'reason',l.reason,'source_reference',l.source_reference,
   'source_version_id',l.source_version_id,'type_version',CASE WHEN tv.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object(
     'id',tv.id,'leave_type_id',tv.leave_type_id,'version',tv.version,'effective_from',tv.effective_from,
     'effective_until',tv.effective_until,'balance_mode',tv.balance_mode,'pay_effect',tv.pay_effect,'source',tv.source) END,
   'reversal_of_entry_id',l.reversal_of_entry_id,'reversed_source_delta_days',src.delta_days,'correction_id',l.correction_id,
   'request_consumption',CASE WHEN r.id IS NULL THEN NULL ELSE pg_catalog.jsonb_build_object('request_id',r.id,
     'request_state',r.state,'request_version',r.version,'employment_id',r.employment_id,'preview_version',rc.preview_version,
     'leave_date',rc.leave_date,'units',rc.units,'ledger_entry_id',rc.ledger_entry_id,'type_version_id',d.type_version_id,
     'calendar_version_id',d.calendar_version_id,'year_period_id',d.year_period_id) END,
   'reversal_entries',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('entry_id',rv.id,
     'entry_kind',rv.entry_kind,'delta_days',rv.delta_days,'correction_id',rv.correction_id) ORDER BY rv.created_at,rv.id)
     FROM leave.ledger_entries rv WHERE rv.tenant_id=l.tenant_id AND rv.account_id=l.account_id
      AND rv.leave_type_id=l.leave_type_id AND rv.reversal_of_entry_id=l.id),'[]'::jsonb),
   'correction_links',coalesce((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('correction_id',c.id,
      'original_request_id',c.original_request_id,'replacement_request_id',c.replacement_request_id,
      'original_approved_preview_version',c.original_approved_preview_version,'replacement_preview_version',c.replacement_preview_version,
      'reason',c.reason,'actor_user_id',c.created_by,'created_at',c.created_at) ORDER BY c.created_at,c.id)
     FROM leave.request_corrections c WHERE c.tenant_id=l.tenant_id AND c.employee_id=p_employee
      AND c.employer_entity_id=p_employer AND (c.original_request_id=r.id OR c.replacement_request_id=r.id)),'[]'::jsonb)) item
  FROM page l LEFT JOIN leave.type_versions tv ON tv.tenant_id=l.tenant_id AND tv.id=l.source_version_id AND tv.leave_type_id=l.leave_type_id
  LEFT JOIN leave.ledger_entries src ON src.tenant_id=l.tenant_id AND src.id=l.reversal_of_entry_id AND src.account_id=l.account_id AND src.leave_type_id=l.leave_type_id
  LEFT JOIN leave.request_consumptions rc ON rc.tenant_id=l.tenant_id AND rc.ledger_entry_id=coalesce(src.id,l.id)
   AND rc.account_id=l.account_id AND rc.leave_type_id=l.leave_type_id
  LEFT JOIN leave.requests r ON r.tenant_id=rc.tenant_id AND r.id=rc.request_id AND r.employee_id=p_employee AND r.employer_entity_id=p_employer
  LEFT JOIN leave.request_days d ON d.tenant_id=rc.tenant_id AND d.request_id=r.id AND d.preview_version=rc.preview_version AND d.leave_date=rc.leave_date
 ), numbered AS (SELECT e.*,pg_catalog.row_number() OVER(ORDER BY created_at DESC,id DESC) rn FROM enriched e)
 SELECT coalesce(pg_catalog.jsonb_agg(item ORDER BY rn) FILTER(WHERE rn<=p_limit),'[]'::jsonb),
  EXISTS(SELECT 1 FROM numbered WHERE rn>p_limit),(SELECT created_at FROM numbered WHERE rn=p_limit),
  (SELECT id FROM numbered WHERE rn=p_limit) INTO items,more,next_at,next_entry FROM numbered;
 RETURN pg_catalog.jsonb_build_object('employee',pair,'account',account,'items',items,'limit',p_limit,'has_more',more,
  'next_before_created_at',CASE WHEN more THEN next_at END,'next_before_entry',CASE WHEN more THEN next_entry END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_balance_ledger(uuid,uuid,uuid,uuid,timestamptz,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_balance_ledger(uuid,uuid,uuid,uuid,timestamptz,uuid,integer) TO authenticated;

CREATE FUNCTION public.leave_balance_posting_periods(p_tenant uuid,p_employee uuid,p_employer uuid,
 p_after_start date DEFAULT NULL,p_after_period uuid DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE pair jsonb; items jsonb; more boolean; next_start date; next_period uuid;
BEGIN
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',false);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 OR ((p_after_start IS NULL)<>(p_after_period IS NULL)) THEN
  RAISE EXCEPTION 'leave_balance_periods_input_invalid' USING ERRCODE='22023'; END IF;
 pair:=leave.balance_pair_snapshot(p_tenant,p_employee,p_employer);
 WITH page AS MATERIALIZED (
  SELECT yp.id,yp.starts_on,pg_catalog.jsonb_build_object('period_id',yp.id,'label',yp.label,'starts_on',yp.starts_on,
   'ends_on',yp.ends_on,'calendar_id',yp.calendar_id) item FROM leave.year_periods yp
  WHERE yp.tenant_id=p_tenant AND yp.employer_entity_id=p_employer
   AND (p_after_start IS NULL OR (yp.starts_on,yp.id)>(p_after_start,p_after_period)) ORDER BY yp.starts_on,yp.id LIMIT p_limit+1
 ), numbered AS (SELECT p.*,pg_catalog.row_number() OVER(ORDER BY starts_on,id) rn FROM page p)
 SELECT coalesce(pg_catalog.jsonb_agg(item ORDER BY rn) FILTER(WHERE rn<=p_limit),'[]'::jsonb),
  EXISTS(SELECT 1 FROM numbered WHERE rn>p_limit),(SELECT starts_on FROM numbered WHERE rn=p_limit),
  (SELECT id FROM numbered WHERE rn=p_limit) INTO items,more,next_start,next_period FROM numbered;
 RETURN pg_catalog.jsonb_build_object('employee',pair,'items',items,'limit',p_limit,'has_more',more,
  'next_after_start',CASE WHEN more THEN next_start END,'next_after_period',CASE WHEN more THEN next_period END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_balance_posting_periods(uuid,uuid,uuid,date,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_balance_posting_periods(uuid,uuid,uuid,date,uuid,integer) TO authenticated;

CREATE FUNCTION public.leave_balance_posting_types(p_tenant uuid,p_employee uuid,p_employer uuid,p_period uuid,p_kind text,
 p_after_code text DEFAULT NULL,p_after_type uuid DEFAULT NULL,p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE pair jsonb; policy_date date; period_start date; items jsonb; more boolean; next_code text; next_type uuid;
BEGIN
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',false);
 IF p_kind IS NULL OR p_kind NOT IN('opening','annual_grant','adjustment') OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
  OR ((p_after_code IS NULL)<>(p_after_type IS NULL))
  OR (p_after_code IS NOT NULL AND (p_after_code='' OR pg_catalog.length(p_after_code)>120)) THEN
  RAISE EXCEPTION 'leave_balance_types_input_invalid' USING ERRCODE='22023'; END IF;
 pair:=leave.balance_pair_snapshot(p_tenant,p_employee,p_employer);
 SELECT starts_on INTO period_start FROM leave.year_periods WHERE tenant_id=p_tenant AND id=p_period AND employer_entity_id=p_employer;
 IF period_start IS NULL THEN RAISE EXCEPTION 'leave_balance_scope_unavailable' USING ERRCODE='P0002'; END IF;
 policy_date:=CASE WHEN p_kind='opening' THEN period_start ELSE (pg_catalog.now() AT TIME ZONE 'Africa/Cairo')::date END;
 WITH page AS MATERIALIZED (
  SELECT t.id,t.code,t.name,t.is_active,tv.id version_id,tv.version,tv.effective_from,tv.effective_until,tv.source,
   ac.id account_id,EXISTS(SELECT 1 FROM leave.ledger_entries l WHERE l.tenant_id=t.tenant_id AND l.account_id=ac.id
    AND l.entry_kind=p_kind AND p_kind IN('opening','annual_grant')) already_posted,
   (SELECT coalesce(sum(l.delta_days),0) FROM leave.ledger_entries l WHERE l.tenant_id=t.tenant_id AND l.account_id=ac.id) balance
  FROM leave.types t JOIN leave.type_versions tv ON tv.tenant_id=t.tenant_id AND tv.leave_type_id=t.id
   AND tv.effective_from<=policy_date AND (tv.effective_until IS NULL OR tv.effective_until>policy_date) AND tv.balance_mode='tracked'
  LEFT JOIN leave.accounts ac ON ac.tenant_id=t.tenant_id AND ac.employee_id=p_employee AND ac.employer_entity_id=t.employer_entity_id
   AND ac.leave_type_id=t.id AND ac.year_period_id=p_period
  WHERE t.tenant_id=p_tenant AND t.employer_entity_id=p_employer
   AND (p_after_code IS NULL OR (t.code,t.id)>(p_after_code,p_after_type)) ORDER BY t.code,t.id LIMIT p_limit+1
 ), numbered AS (SELECT p.*,pg_catalog.row_number() OVER(ORDER BY code,id) rn FROM page p)
 SELECT coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('leave_type_id',id,'code',code,'name',name,
   'is_active',is_active,'type_version_id',version_id,'type_version',version,'effective_from',effective_from,
   'effective_until',effective_until,'policy_source',source,'policy_date',policy_date,'account_id',account_id,
   'balance_days',balance,'already_posted',already_posted,'can_post',(pair->>'can_post')::boolean AND NOT already_posted,
   'posting_blocked_reason',CASE WHEN already_posted THEN p_kind||'_already_posted' ELSE pair->>'posting_blocked_reason' END)
   ORDER BY rn) FILTER(WHERE rn<=p_limit),'[]'::jsonb),EXISTS(SELECT 1 FROM numbered WHERE rn>p_limit),
  (SELECT code FROM numbered WHERE rn=p_limit),(SELECT id FROM numbered WHERE rn=p_limit)
 INTO items,more,next_code,next_type FROM numbered;
 RETURN pg_catalog.jsonb_build_object('employee',pair,'period_id',p_period,'kind',p_kind,'policy_date',policy_date,
  'items',items,'limit',p_limit,'has_more',more,'next_after_code',CASE WHEN more THEN next_code END,'next_after_type',CASE WHEN more THEN next_type END);
END $f$;
REVOKE ALL ON FUNCTION public.leave_balance_posting_types(uuid,uuid,uuid,uuid,text,text,uuid,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_balance_posting_types(uuid,uuid,uuid,uuid,text,text,uuid,integer) TO authenticated;
