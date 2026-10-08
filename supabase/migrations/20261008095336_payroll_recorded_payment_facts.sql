-- Original UX plan7.5: aggregate recorded-payment evidence, preserving read audit.
CREATE FUNCTION public.payroll_payment_facts(p_tenant uuid,p_employer uuid,p_output uuid)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $function$
DECLARE actor uuid;context payroll.final_contexts%ROWTYPE;result jsonb;
BEGIN
 actor:=payroll.payment_authorized(p_tenant,false);
 SELECT * INTO context FROM payroll.final_contexts WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_output;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 -- Balance, revision and succession facts share one statement snapshot.
 WITH totals AS (
  SELECT count(*) employee_count,count(*) FILTER(WHERE remaining>0) remaining_count,
   coalesce(sum(payable),0) payable,coalesce(sum(paid),0) paid,coalesce(sum(remaining),0) remaining
  FROM payroll.payment_balances(p_tenant,p_output)
 )
 SELECT jsonb_build_object('contract_version',1,'output_id',p_output,
  'period',jsonb_build_object('id',context.period_id,'starts_on',context.period_snapshot->>'starts_on','ends_on',context.period_snapshot->>'ends_on'),
  'revision',coalesce((SELECT revision FROM payroll.payment_heads WHERE tenant_id=p_tenant AND output_id=p_output),0),
  'employee_count',employee_count,'remaining_count',remaining_count,
  'status',CASE WHEN paid=0 THEN 'unpaid' WHEN remaining=0 THEN 'paid' ELSE 'partially_paid' END,
  'ever_paid',payroll.output_has_ever_paid(p_tenant,p_output),
  'payable_sign',CASE WHEN payable>0 THEN 'positive' WHEN payable=0 THEN 'zero' ELSE 'negative' END,
  'superseded',EXISTS(SELECT 1 FROM payroll.output_successions WHERE tenant_id=p_tenant AND original_output=p_output)
 ) INTO result FROM totals;
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details)
 VALUES(p_tenant,p_employer,actor,'payment_workspace_access',jsonb_build_object('output',p_output,'event',NULL,'employee_count',0,'history_count',0,'aggregate_only',true));
 PERFORM payroll.payment_authorized(p_tenant,false);
 RETURN result;
END
$function$;
REVOKE ALL ON FUNCTION public.payroll_payment_facts(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_payment_facts(uuid,uuid,uuid) TO authenticated;
