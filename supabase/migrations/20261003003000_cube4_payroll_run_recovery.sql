-- Reconcile a lost run response under the writer's scope lock. Recovery never
-- calculates. An absent receipt is durably fenced before a new attempt opens.
CREATE TABLE payroll.run_attempt_closures(
 tenant_id uuid NOT NULL,actor_id uuid NOT NULL,attempt_key uuid NOT NULL,
 employer_id uuid NOT NULL,period_id uuid NOT NULL,intent jsonb NOT NULL,
 closed_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(tenant_id,actor_id,attempt_key),
 FOREIGN KEY(tenant_id,period_id) REFERENCES payroll.periods(tenant_id,id));
ALTER TABLE payroll.run_attempt_closures ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.run_attempt_closures FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER immutable BEFORE UPDATE OR DELETE ON payroll.run_attempt_closures FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
CREATE FUNCTION payroll.assert_run_attempt_open(p_tenant uuid,p_actor uuid,p_attempt uuid,p_intent jsonb)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE closed payroll.run_attempt_closures;BEGIN
 SELECT * INTO closed FROM payroll.run_attempt_closures WHERE tenant_id=p_tenant AND actor_id=p_actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF closed.intent IS DISTINCT FROM p_intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  RAISE EXCEPTION 'payroll_attempt_closed' USING ERRCODE='PT409';
 END IF;
END $f$;
REVOKE ALL ON FUNCTION payroll.assert_run_attempt_open(uuid,uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;
DO $f$ DECLARE definition text;anchor text:='IF p_run IS NULL THEN';BEGIN
 definition:=pg_get_functiondef('public.payroll_run_command(uuid,uuid,uuid,uuid,integer,text,text,uuid)'::regprocedure);
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'unexpected_run_recovery_writer';END IF;
 EXECUTE replace(definition,anchor,'PERFORM payroll.assert_run_attempt_open(p_tenant,a,p_attempt,intent); '||anchor);
END $f$;
CREATE FUNCTION public.payroll_run_reconcile(p_tenant uuid,p_employer uuid,p_period uuid,p_run uuid,p_expected integer,p_operation text,p_reason text,p_attempt uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;intent jsonb;receipt payroll.command_receipts;closed payroll.run_attempt_closures;BEGIN
 actor:=payroll.authorized(p_tenant,'payroll.prepare',false);
 IF p_operation IS NULL OR p_operation NOT IN('calculate','cancel') OR p_expected IS NULL OR p_expected<0 OR p_attempt IS NULL OR p_period IS NULL
  OR p_run IS NULL AND(p_expected<>0 OR p_operation<>'calculate') OR length(coalesce(btrim(p_reason),''))>500
  OR p_operation='cancel' AND length(coalesce(btrim(p_reason),''))<3 THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023';END IF;
 PERFORM set_config('lock_timeout','5s',true);
 PERFORM payroll.lock_run_scope(p_tenant,p_employer,p_period);
 actor:=payroll.authorized(p_tenant,'payroll.prepare',false);
 IF NOT EXISTS(SELECT 1 FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND id=p_period)
  OR p_run IS NOT NULL AND NOT EXISTS(SELECT 1 FROM payroll.runs WHERE tenant_id=p_tenant AND employer_id=p_employer AND period_id=p_period AND id=p_run)
 THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501';END IF;
 intent:=jsonb_build_object('operation','run_'||p_operation,'employer',p_employer,'period',p_period,'run',p_run,'expected',p_expected,'reason',coalesce(btrim(p_reason),''));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF receipt.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN jsonb_build_object('outcome','committed','result',receipt.result);
 END IF;
 SELECT * INTO closed FROM payroll.run_attempt_closures WHERE tenant_id=p_tenant AND actor_id=actor AND attempt_key=p_attempt;
 IF FOUND THEN
  IF closed.intent IS DISTINCT FROM intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409';END IF;
 ELSE
  INSERT INTO payroll.run_attempt_closures(tenant_id,actor_id,attempt_key,employer_id,period_id,intent) VALUES(p_tenant,actor,p_attempt,p_employer,p_period,intent);
  INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,actor,'run_attempt_closed',jsonb_build_object('attempt',p_attempt,'period',p_period,'operation',intent->>'operation'));
 END IF;
 RETURN jsonb_build_object('outcome','closed_uncommitted');
END $f$;
REVOKE ALL ON FUNCTION public.payroll_run_reconcile(uuid,uuid,uuid,uuid,integer,text,text,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_run_reconcile(uuid,uuid,uuid,uuid,integer,text,text,uuid) TO authenticated;
