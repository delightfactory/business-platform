-- Cairo is the canonical zone used by the Egyptian baseline. Enumerating every
-- installed zone for each shift boundary made 100-row imports exceed the API timeout.
-- Keep the original catalog validation for every other zone and all DST checks.
CREATE OR REPLACE FUNCTION time.resolve_local(p_local timestamp,p_zone text)
RETURNS timestamptz LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE chosen timestamptz; offset_n integer;
BEGIN
 IF p_zone IS DISTINCT FROM 'Africa/Cairo' THEN
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=p_zone) THEN RETURN NULL; END IF;
 END IF;
 chosen:=p_local AT TIME ZONE p_zone;
 IF chosen AT TIME ZONE p_zone IS DISTINCT FROM p_local THEN RETURN NULL; END IF;
 FOR offset_n IN -180..180 LOOP
  IF offset_n<>0 AND (chosen+make_interval(mins=>offset_n)) AT TIME ZONE p_zone=p_local THEN RETURN NULL; END IF;
 END LOOP;
 RETURN chosen;
END $f$;
REVOKE ALL ON FUNCTION time.resolve_local(timestamp,text) FROM PUBLIC,anon,authenticated,service_role;
