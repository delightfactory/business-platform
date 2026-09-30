-- An Employment has one operational day, regardless of how its Assignment changes.
-- Keep this key on Employment, not Employee: a later, separate Employment is distinct.
DO $guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM time.work_instances
    GROUP BY tenant_id, employment_id, operational_date
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'attendance_duplicate_employment_day_requires_reconciliation'
      USING ERRCODE = '23505';
  END IF;
END $guard$;

CREATE UNIQUE INDEX work_instances_employment_day_key
  ON time.work_instances (tenant_id, employment_id, operational_date);

-- All supported People RPCs lock the Employment before touching Assignments.
-- attendance_open_day locks the same Employment before inserting Work Instances,
-- so the checks below run after any concurrent day open has committed.
CREATE FUNCTION people.guard_materialized_work_assignment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $guard$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF EXISTS (
      SELECT 1 FROM time.work_instances i
      WHERE i.tenant_id = NEW.tenant_id AND i.employment_id = NEW.employment_id
        AND i.operational_date >= NEW.valid_from
        AND (NEW.valid_until IS NULL OR i.operational_date < NEW.valid_until)
    ) THEN
      RAISE EXCEPTION 'people_assignment_materialized_day'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;

  IF ROW(NEW.site_id, NEW.department_id, NEW.job_id, NEW.manager_employee_id,
         NEW.work_policy_template_id, NEW.work_policy_version)
       IS DISTINCT FROM
     ROW(OLD.site_id, OLD.department_id, OLD.job_id, OLD.manager_employee_id,
         OLD.work_policy_template_id, OLD.work_policy_version)
     AND EXISTS (
       SELECT 1 FROM time.work_instances i
       WHERE i.tenant_id = OLD.tenant_id AND i.assignment_id = OLD.id
     ) THEN
    RAISE EXCEPTION 'people_assignment_materialized_day'
      USING ERRCODE = '23514';
  END IF;

  IF (NEW.valid_from IS DISTINCT FROM OLD.valid_from
      OR NEW.valid_until IS DISTINCT FROM OLD.valid_until)
     AND (
       EXISTS (
         SELECT 1 FROM time.work_instances i
         WHERE i.tenant_id = OLD.tenant_id AND i.assignment_id = OLD.id
           AND (i.operational_date < NEW.valid_from
                OR (NEW.valid_until IS NOT NULL AND i.operational_date >= NEW.valid_until))
       )
       OR EXISTS (
         SELECT 1 FROM time.work_instances i
         WHERE i.tenant_id = NEW.tenant_id AND i.employment_id = NEW.employment_id
           AND i.assignment_id <> NEW.id AND i.operational_date >= NEW.valid_from
           AND (NEW.valid_until IS NULL OR i.operational_date < NEW.valid_until)
       )
     ) THEN
    RAISE EXCEPTION 'people_assignment_materialized_day'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $guard$;

CREATE TRIGGER work_assignment_materialized_day_guard
  BEFORE INSERT OR UPDATE ON people.work_assignments
  FOR EACH ROW EXECUTE FUNCTION people.guard_materialized_work_assignment();
REVOKE ALL ON FUNCTION people.guard_materialized_work_assignment()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION people.guard_materialized_employment_end()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $guard$
BEGIN
  IF NEW.end_date IS NOT NULL AND
     (NEW.end_date IS DISTINCT FROM OLD.end_date
      OR NEW.employment_status IS DISTINCT FROM OLD.employment_status)
     AND EXISTS (
       SELECT 1 FROM time.work_instances i
       WHERE i.tenant_id = NEW.tenant_id AND i.employment_id = NEW.id
         AND i.operational_date > NEW.end_date
     ) THEN
    RAISE EXCEPTION 'people_employment_end_before_materialized_day'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $guard$;

CREATE TRIGGER employment_materialized_day_guard
  BEFORE UPDATE OF end_date, employment_status ON people.employments
  FOR EACH ROW EXECUTE FUNCTION people.guard_materialized_employment_end();
REVOKE ALL ON FUNCTION people.guard_materialized_employment_end()
  FROM PUBLIC, anon, authenticated, service_role;
