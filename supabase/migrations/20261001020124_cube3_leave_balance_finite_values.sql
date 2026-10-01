-- numeric accepts special values. Keep them out at both the RPC and ledger boundary.
ALTER TABLE leave.ledger_entries
 ADD CONSTRAINT leave_ledger_delta_finite
 CHECK(delta_days::text NOT IN('NaN','Infinity','-Infinity'));
CREATE OR REPLACE FUNCTION public.leave_post_balance(p_tenant uuid,p_employee uuid,p_employer uuid,p_type uuid,p_period uuid,p_kind text,p_delta numeric,p_type_version uuid,p_key text,p_source text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=leave.authorized(p_tenant,'leave_balance.adjust',true); account uuid; old leave.ledger_entries%ROWTYPE; active_version leave.type_versions%ROWTYPE; employment uuid; balance_now numeric; period_start date; policy_date date; entity_active boolean; ky text:=btrim(coalesce(p_key,'')); src text:=btrim(coalesce(p_source,'')); why text:=btrim(coalesce(p_reason,'')); cairo_today date:=((now() AT TIME ZONE 'Africa/Cairo')::date); BEGIN
 IF p_type IS NULL OR p_period IS NULL OR p_kind IS NULL OR p_kind NOT IN('opening','annual_grant','adjustment') OR p_delta IS NULL OR p_delta::text IN('NaN','Infinity','-Infinity') OR p_delta=0 OR p_delta<>round(p_delta,2) OR p_type_version IS NULL OR ky='' OR length(ky)>120 OR src='' OR length(src)>300 OR why='' OR length(why)>500 OR (p_kind IN('opening','annual_grant') AND p_delta<=0) THEN RAISE EXCEPTION 'leave_balance_input_invalid' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_employee_unavailable' USING ERRCODE='23503'; END IF;
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',true);
 SELECT id INTO employment FROM people.employments WHERE tenant_id=p_tenant AND employee_id=p_employee AND employer_entity_id=p_employer AND employment_status='active' AND start_date<=cairo_today AND (end_date IS NULL OR end_date>=cairo_today) FOR UPDATE;
 IF employment IS NULL THEN RAISE EXCEPTION 'leave_active_employment_required' USING ERRCODE='23514'; END IF;
 SELECT is_active INTO entity_active FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer FOR UPDATE;
 IF NOT coalesce(entity_active,false) THEN RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503'; END IF;
 SELECT starts_on INTO period_start FROM leave.year_periods WHERE tenant_id=p_tenant AND id=p_period AND employer_entity_id=p_employer;
 IF period_start IS NULL THEN RAISE EXCEPTION 'leave_account_scope_invalid' USING ERRCODE='23503'; END IF;
 IF NOT EXISTS(SELECT 1 FROM leave.types WHERE tenant_id=p_tenant AND id=p_type AND employer_entity_id=p_employer) THEN RAISE EXCEPTION 'leave_account_scope_invalid' USING ERRCODE='23503'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||p_employee::text,90429)); PERFORM leave.authorized(p_tenant,'leave_balance.adjust',true);
 INSERT INTO leave.accounts(tenant_id,employer_entity_id,employee_id,leave_type_id,year_period_id,created_by) VALUES(p_tenant,p_employer,p_employee,p_type,p_period,a) ON CONFLICT(tenant_id,employer_entity_id,employee_id,leave_type_id,year_period_id) DO NOTHING;
 SELECT id INTO account FROM leave.accounts WHERE tenant_id=p_tenant AND employer_entity_id=p_employer AND employee_id=p_employee AND leave_type_id=p_type AND year_period_id=p_period FOR UPDATE;
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',true);
 SELECT * INTO old FROM leave.ledger_entries WHERE tenant_id=p_tenant AND account_id=account AND idempotency_key=ky;
 IF FOUND THEN IF old.entry_kind=p_kind AND old.delta_days=p_delta AND old.source_version_id=p_type_version AND old.source_reference=src AND old.reason=why THEN RETURN jsonb_build_object('state','replay','account_id',account,'entry_id',old.id); ELSE RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF; END IF;
 IF p_kind='annual_grant' AND EXISTS(SELECT 1 FROM leave.ledger_entries WHERE tenant_id=p_tenant AND account_id=account AND entry_kind='annual_grant') THEN RAISE EXCEPTION 'leave_annual_grant_exists' USING ERRCODE='23505'; END IF;
 policy_date:=CASE WHEN p_kind='opening' THEN period_start ELSE cairo_today END;
 SELECT * INTO active_version FROM leave.type_versions WHERE tenant_id=p_tenant AND leave_type_id=p_type AND id=p_type_version AND effective_from<=policy_date AND (effective_until IS NULL OR effective_until>policy_date);
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_version_unavailable' USING ERRCODE='23503'; END IF;
 IF active_version.balance_mode<>'tracked' THEN RAISE EXCEPTION 'leave_untracked_has_no_balance' USING ERRCODE='23514'; END IF;
 IF p_delta>0 AND (NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',now()) OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',now())) THEN RAISE EXCEPTION 'leave_positive_growth_disabled' USING ERRCODE='55000'; END IF;
 SELECT coalesce(sum(delta_days),0) INTO balance_now FROM leave.ledger_entries WHERE tenant_id=p_tenant AND account_id=account;
 IF p_kind='adjustment' AND balance_now+p_delta<0 THEN RAISE EXCEPTION 'leave_balance_insufficient' USING ERRCODE='23514'; END IF;
 INSERT INTO leave.ledger_entries(tenant_id,account_id,leave_type_id,entry_kind,delta_days,source_version_id,source_reference,idempotency_key,reason,actor_user_id) VALUES(p_tenant,account,p_type,p_kind,p_delta,p_type_version,src,ky,why,a) RETURNING id INTO employment;
 RETURN jsonb_build_object('state','created','account_id',account,'entry_id',employment); END $f$;
REVOKE ALL ON FUNCTION public.leave_post_balance(uuid,uuid,uuid,uuid,uuid,text,numeric,uuid,text,text,text) FROM PUBLIC,anon,service_role; GRANT EXECUTE ON FUNCTION public.leave_post_balance(uuid,uuid,uuid,uuid,uuid,text,numeric,uuid,text,text,text) TO authenticated;