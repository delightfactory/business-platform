-- Close repeated changes through the existing exact source-binding lineage.
-- Preserve observations and case links; never resolve a deselected dependency.
CREATE FUNCTION payroll.correction_observation_covers_requirement(
 p_tenant uuid,p_observation uuid,p_requirement uuid
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT EXISTS(
  SELECT 1 FROM payroll.bound_source_correction_observations current_observation
  JOIN payroll.bound_source_correction_observations previous_observation
   ON previous_observation.tenant_id=current_observation.tenant_id
   AND previous_observation.employer_id=current_observation.employer_id
   AND previous_observation.output_id=current_observation.output_id
   AND previous_observation.employment_id=current_observation.employment_id
   AND previous_observation.source_domain=current_observation.source_domain
   AND previous_observation.source_date=current_observation.source_date
   AND previous_observation.source_key=current_observation.source_key
   AND previous_observation.original_binding_digest=current_observation.original_binding_digest
   AND previous_observation.original_binding_identity=current_observation.original_binding_identity
   AND previous_observation.original_binding_version=current_observation.original_binding_version
  WHERE current_observation.tenant_id=p_tenant AND current_observation.id=p_observation
   AND previous_observation.requirement_id=p_requirement
   AND payroll.bound_source_envelope(current_observation.tenant_id,current_observation.source_domain,
    current_observation.source_date,(current_observation.current_source_identity->>
     CASE current_observation.source_domain WHEN 'time' THEN 'work_instance_id' ELSE 'request_id' END)::uuid)
     ->>'fingerprint'=current_observation.current_lineage_fingerprint
 )
$f$;
REVOKE ALL ON FUNCTION payroll.correction_observation_covers_requirement(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION payroll.correction_requirement_is_current(
 p_tenant uuid,p_case uuid,p_requirement uuid
) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
 SELECT NOT EXISTS(SELECT 1 FROM payroll.bound_source_correction_observations observation
  WHERE observation.tenant_id=p_tenant AND observation.requirement_id=p_requirement)
 OR EXISTS(
  SELECT 1 FROM payroll.correction_cases correction
  JOIN payroll.correction_proposals proposal ON proposal.tenant_id=correction.tenant_id
   AND proposal.id=correction.proposal_id AND proposal.case_id=correction.id
  CROSS JOIN LATERAL jsonb_array_elements(proposal.source_changes) change
  JOIN payroll.bound_source_correction_observations observation
   ON observation.tenant_id=correction.tenant_id
   AND observation.id::text=change->'new_row'->>'observation_id'
  WHERE correction.tenant_id=p_tenant AND correction.id=p_case
   AND change->>'source_table'='bound_source_correction_observations'
   AND change->>'operation'='OBSERVE'
   AND change->'new_row'->>'requirement_id'=observation.requirement_id::text
   AND change->'new_row'->>'expected_fingerprint'=observation.current_lineage_fingerprint
   AND payroll.correction_observation_covers_requirement(p_tenant,observation.id,p_requirement)
 )
$f$;
REVOKE ALL ON FUNCTION payroll.correction_requirement_is_current(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

DO $patch$ DECLARE definition text;old text;replacement text;BEGIN
 definition:=pg_get_functiondef('public.payroll_correction_proposal(uuid,uuid,uuid,uuid,integer,jsonb,jsonb,uuid,text,text,text,text,uuid)'::regprocedure);
 old:='x->''new_row''->>''requirement_id''=r.id::text';
 replacement:='payroll.correction_observation_covers_requirement(p_tenant,(x->''new_row''->>''observation_id'')::uuid,r.id)';
 IF (length(definition)-length(replace(definition,old,'')))/length(old)<>1
  THEN RAISE EXCEPTION 'unexpected_correction_lineage_link_anchor';END IF;
 EXECUTE replace(definition,old,replacement);
END $patch$;

-- Newly approved Leave on an unbound day cannot silently amend a final output.
-- Use its original optional-source scope and employee dates, not current flags.
-- Public Leave approval already fences Employment before this deferred tail;
-- finalization takes that same parent fence. No reverse Payroll lock is added.
-- This is an explained refusal of an unsupported historical addition, not a
-- new absence binding, monetary adjustment, or claim of financial qualification.
CREATE FUNCTION payroll.guard_unbound_leave_approval() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM leave.requests request WHERE request.tenant_id=NEW.tenant_id
  AND request.id=NEW.id AND request.state='approved') THEN RETURN NEW;END IF;
 IF EXISTS(
  SELECT 1 FROM leave.request_days day_row
  JOIN payroll.final_employees final_employee ON final_employee.tenant_id=NEW.tenant_id
   AND final_employee.employer_id=NEW.employer_entity_id AND final_employee.employment_id=NEW.employment_id
  JOIN payroll.final_contexts context ON context.tenant_id=final_employee.tenant_id
   AND context.id=final_employee.output_id AND context.employer_id=final_employee.employer_id
  CROSS JOIN LATERAL jsonb_array_elements(context.manifest->'employees') employee
  WHERE day_row.tenant_id=NEW.tenant_id AND day_row.request_id=NEW.id
   AND day_row.preview_version=NEW.approved_preview_version
   AND context.manifest->'optional'->>'leave'='true'
   AND employee->'employment'->>'id'=NEW.employment_id::text
   AND day_row.leave_date BETWEEN
    greatest((context.manifest->'period'->>'starts_on')::date,(employee->'employment'->>'start_date')::date)
    AND least((context.manifest->'period'->>'ends_on')::date,
     COALESCE((employee->'employment'->>'end_date')::date,(context.manifest->'period'->>'ends_on')::date))
   AND NOT EXISTS(SELECT 1 FROM payroll.output_successions succession
    WHERE succession.tenant_id=context.tenant_id AND succession.original_output=context.id)
   AND NOT EXISTS(SELECT 1 FROM payroll.final_source_bindings binding
    WHERE binding.tenant_id=context.tenant_id AND binding.output_id=context.id
     AND binding.employment_id=NEW.employment_id AND binding.source_domain='leave'
     AND binding.source_date=day_row.leave_date AND binding.source_identity->>'request_id' IS NOT NULL)
 ) THEN RAISE EXCEPTION 'payroll_locked_leave_addition_requires_correction' USING ERRCODE='23514';END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION payroll.guard_unbound_leave_approval() FROM PUBLIC,anon,authenticated,service_role;
CREATE CONSTRAINT TRIGGER payroll_guard_unbound_leave_approval_update
 AFTER UPDATE OF state,approved_preview_version ON leave.requests
 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
 WHEN(NEW.state='approved' AND OLD.state IS DISTINCT FROM NEW.state)
 EXECUTE FUNCTION payroll.guard_unbound_leave_approval();
CREATE CONSTRAINT TRIGGER payroll_guard_unbound_leave_approval_insert
 AFTER INSERT ON leave.requests DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
 WHEN(NEW.state='approved') EXECUTE FUNCTION payroll.guard_unbound_leave_approval();
