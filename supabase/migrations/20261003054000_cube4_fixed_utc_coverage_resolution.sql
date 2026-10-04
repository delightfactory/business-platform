-- Coverage-only optimization for fixed zero-offset civil zones.
-- Preserve the existing ambiguity resolver for all other zones and nonfinite
-- inputs. No request fence, source identity, financial gate or lock changes.
CREATE FUNCTION payroll.coverage_local_instant(p_local timestamp without time zone,p_zone text)
RETURNS timestamp with time zone LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
BEGIN
 IF isfinite(p_local) AND p_zone IN('UTC','Etc/UTC') THEN RETURN p_local AT TIME ZONE 'UTC';END IF;
 RETURN time.resolve_local(p_local,p_zone);
END $f$;
REVOKE ALL ON FUNCTION payroll.coverage_local_instant(timestamp without time zone,text) FROM PUBLIC,anon,authenticated,service_role;
DO $patch$DECLARE definition text;BEGIN
 definition:=pg_get_functiondef('payroll.time_expected_bounds(date,jsonb)'::regprocedure);
 IF (length(definition)-length(replace(definition,'time.resolve_local(','')))/length('time.resolve_local(')<>4 THEN
  RAISE EXCEPTION 'unexpected_coverage_local_resolver';END IF;
 EXECUTE replace(definition,'time.resolve_local(','payroll.coverage_local_instant(');
END$patch$;
