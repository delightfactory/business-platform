DROP TRIGGER work_assignment_catalog_active ON people.work_assignments;
CREATE TRIGGER work_assignment_catalog_active
BEFORE INSERT OR UPDATE OF tenant_id,department_id,job_id ON people.work_assignments
FOR EACH ROW EXECUTE FUNCTION people.validate_work_assignment_catalog();
