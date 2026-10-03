-- Narrow Source7 runtime namespace fixes; preserves receipts, locks, money, guards and ACLs.
DO $namespace_fix$
DECLARE d text; changed text;
BEGIN
  d:=pg_get_functiondef('public.payroll_advance_workspace(uuid,uuid,uuid,text,uuid,integer,uuid)'::regprocedure);
  IF md5(d)<>'75935e9379b07961e0333883c0db39bc' THEN RAISE EXCEPTION 'unexpected_advance_namespace_fix_baseline'; END IF;
  changed:=replace(d,' SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),''[]'') INTO items FROM(SELECT h.id,h.employment_id,h.revision,e.full_name AS name,e.employee_code AS code,v.principal::text,
 payroll.advance_status(p_tenant,h.id) AS status,payroll.advance_balance(p_tenant,h.id)::text AS outstanding,
 (SELECT jsonb_build_object(''id'',i.id,''amount'',payroll.installment_remaining(p_tenant,i.id)::text,''starts_on'',p.starts_on) FROM payroll.advance_installments i JOIN payroll.periods p ON p.tenant_id=i.tenant_id AND p.id=COALESCE((SELECT x.target_period FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id ORDER BY revision DESC LIMIT 1),i.period_id) WHERE i.tenant_id=h.tenant_id AND i.version_id=h.version_id AND payroll.advance_balance(p_tenant,h.id)>0 AND payroll.installment_remaining(p_tenant,i.id)>0 ORDER BY p.starts_on,i.ordinal LIMIT 1) AS next_installment
 FROM payroll.advance_heads h JOIN payroll.advance_versions v ON v.tenant_id=h.tenant_id AND v.id=h.version_id JOIN people.employments emp ON emp.tenant_id=h.tenant_id AND emp.id=h.employment_id JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id WHERE h.tenant_id=p_tenant AND h.employer_id=p_employer AND(p_after IS NULL OR h.id>p_after) AND(e.full_name ILIKE ''%''||p_query||''%'' OR e.employee_code ILIKE ''%''||p_query||''%'') ORDER BY h.id LIMIT 30)x;
',' SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY id),''[]'') INTO items FROM(SELECT listed_head.id,listed_head.employment_id,listed_head.revision,e.full_name AS name,e.employee_code AS code,listed_version.principal::text,
 payroll.advance_status(p_tenant,listed_head.id) AS status,payroll.advance_balance(p_tenant,listed_head.id)::text AS outstanding,
 (SELECT jsonb_build_object(''id'',i.id,''amount'',payroll.installment_remaining(p_tenant,i.id)::text,''starts_on'',p.starts_on) FROM payroll.advance_installments i JOIN payroll.periods p ON p.tenant_id=i.tenant_id AND p.id=COALESCE((SELECT x.target_period FROM payroll.advance_deferrals x WHERE x.tenant_id=i.tenant_id AND x.installment_id=i.id ORDER BY revision DESC LIMIT 1),i.period_id) WHERE i.tenant_id=listed_head.tenant_id AND i.version_id=listed_head.version_id AND payroll.advance_balance(p_tenant,listed_head.id)>0 AND payroll.installment_remaining(p_tenant,i.id)>0 ORDER BY p.starts_on,i.ordinal LIMIT 1) AS next_installment
 FROM payroll.advance_heads listed_head JOIN payroll.advance_versions listed_version ON listed_version.tenant_id=listed_head.tenant_id AND listed_version.id=listed_head.version_id JOIN people.employments emp ON emp.tenant_id=listed_head.tenant_id AND emp.id=listed_head.employment_id JOIN people.employees e ON e.tenant_id=emp.tenant_id AND e.id=emp.employee_id WHERE listed_head.tenant_id=p_tenant AND listed_head.employer_id=p_employer AND(p_after IS NULL OR listed_head.id>p_after) AND(e.full_name ILIKE ''%''||p_query||''%'' OR e.employee_code ILIKE ''%''||p_query||''%'') ORDER BY listed_head.id LIMIT 30)x;
');
  IF changed=d THEN RAISE EXCEPTION 'unexpected_advance_namespace_fix_anchor'; END IF;
  EXECUTE changed;
  d:=pg_get_functiondef('payroll.append_final_output_single(uuid,uuid,uuid,uuid,integer,uuid)'::regprocedure);
  IF md5(d)<>'269d00b2b00ed93e9bd7d3b79efcc96e' THEN RAISE EXCEPTION 'unexpected_advance_namespace_fix_baseline'; END IF;
  changed:=replace(d,'EXISTS(SELECT 1 FROM payroll.advance_heads h WHERE h.tenant_id=p_tenant AND h.employer_id=r.employer_id AND payroll.advance_balance(p_tenant,h.id)<0)','EXISTS(SELECT 1 FROM payroll.advance_heads balance_head WHERE balance_head.tenant_id=p_tenant AND balance_head.employer_id=r.employer_id AND payroll.advance_balance(p_tenant,balance_head.id)<0)');
  IF changed=d THEN RAISE EXCEPTION 'unexpected_advance_namespace_fix_anchor'; END IF;
  EXECUTE changed;
END
$namespace_fix$;
