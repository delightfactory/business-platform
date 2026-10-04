-- Restore an explicitly selected saved source without requiring discarded picker state.
-- Unselected lists still require the employee; selected rows retain tenant, Employer
-- and source-management authority. This does not alter proposal freshness or money.
DO $repair$
DECLARE definition text;
BEGIN
 SELECT pg_get_functiondef('public.payroll_correction_choices(uuid,uuid,uuid,text,text,text,text,uuid,integer,uuid)'::regprocedure) INTO definition;
 IF strpos(definition,$before$v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.work_assignments$before$)=0 THEN RAISE EXCEPTION 'saved source restoration anchor missing';END IF;
 definition:=replace(definition,$before$v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.work_assignments$before$,$after$v.tenant_id=p_tenant AND (v.employment_id=p_employee OR (p_employee IS NULL AND v.id=p_selected AND EXISTS(SELECT 1 FROM people.employments e WHERE e.tenant_id=v.tenant_id AND e.id=v.employment_id AND e.employer_entity_id=p_employer))) UNION ALL SELECT to_jsonb(v) FROM people.work_assignments$after$);
 IF strpos(definition,$before$v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.employments$before$)=0 THEN RAISE EXCEPTION 'saved source restoration anchor missing';END IF;
 definition:=replace(definition,$before$v.tenant_id=p_tenant AND v.employment_id=p_employee UNION ALL SELECT to_jsonb(v) FROM people.employments$before$,$after$v.tenant_id=p_tenant AND (v.employment_id=p_employee OR (p_employee IS NULL AND v.id=p_selected AND EXISTS(SELECT 1 FROM people.employments e WHERE e.tenant_id=v.tenant_id AND e.id=v.employment_id AND e.employer_entity_id=p_employer))) UNION ALL SELECT to_jsonb(v) FROM people.employments$after$);
 IF strpos(definition,$before$v.tenant_id=p_tenant AND v.id=p_employee) source_rows$before$)=0 THEN RAISE EXCEPTION 'saved source restoration anchor missing';END IF;
 definition:=replace(definition,$before$v.tenant_id=p_tenant AND v.id=p_employee) source_rows$before$,$after$v.tenant_id=p_tenant AND (v.id=p_employee OR (p_employee IS NULL AND v.id=p_selected AND v.employer_entity_id=p_employer))) source_rows$after$);
 IF strpos(definition,$before$(h.employment_id=p_employee OR h.employment_id IS NULL)$before$)=0 THEN RAISE EXCEPTION 'saved source restoration anchor missing';END IF;
 definition:=replace(definition,$before$(h.employment_id=p_employee OR h.employment_id IS NULL)$before$,$after$(h.employment_id=p_employee OR h.employment_id IS NULL OR (p_employee IS NULL AND h.id=p_selected))$after$);
 EXECUTE definition;
END $repair$;
