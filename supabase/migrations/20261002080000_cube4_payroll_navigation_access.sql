-- Purpose-only navigation flags. No employee/financial records and no grants.
CREATE FUNCTION public.payroll_navigation_access(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid();finance boolean;reports boolean;BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 finance:=platform_private.has_tenant_permission(p_tenant,actor,'employee_finance.view') OR platform_private.has_tenant_permission(p_tenant,actor,'employee_finance.manage') OR platform_private.has_tenant_permission(p_tenant,actor,'employee_finance.approve');
 reports:=platform_private.has_tenant_permission(p_tenant,actor,'payroll.view');
 IF NOT finance AND NOT reports THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 RETURN jsonb_build_object('can_view_advances',finance,'can_view_reports',reports OR finance,'report_kind',CASE WHEN reports THEN 'sheet' ELSE 'advances' END);
END $f$;
REVOKE ALL ON FUNCTION public.payroll_navigation_access(uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_navigation_access(uuid) TO authenticated;
