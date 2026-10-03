-- The existing explicit HR replacement command carries an admitted historical
-- request's correction duty to its exact replacement. Ordinary approval stays
-- closed; no new financial amount, binding, grant or release switch is created.
ALTER TABLE payroll.historical_leave_admissions ADD COLUMN replacement_of uuid;
ALTER TABLE payroll.historical_leave_admissions ADD CONSTRAINT historical_leave_admission_parent_fk
 FOREIGN KEY(tenant_id,replacement_of) REFERENCES payroll.historical_leave_admissions(tenant_id,request_id);

DO $patch$ DECLARE definition text;anchor text;BEGIN
 definition:=pg_get_functiondef('public.leave_correct_approved_request(uuid,uuid,integer,integer,uuid,integer,integer,text,text)'::regprocedure);
 anchor:='UPDATE leave.requests SET state=''approved'',version=version+1,approved_at=pg_catalog.transaction_timestamp(),';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_historical_replacement_admission_anchor';END IF;
 EXECUTE replace(definition,anchor,
  'INSERT INTO payroll.historical_leave_admissions(tenant_id,request_id,approved_preview_version,approved_request_version,actor_id,reason,operation_key,replacement_of)
   SELECT p_tenant,newr.id,newr.current_preview_version,newr.version+1,actor,btrim(p_reason),btrim(p_idempotency_key),oldr.id
   FROM payroll.historical_leave_admissions original_admission WHERE original_admission.tenant_id=p_tenant AND original_admission.request_id=oldr.id; '||anchor);
END $patch$;
