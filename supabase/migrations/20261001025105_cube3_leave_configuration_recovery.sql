-- Recover prospective effective-dated Leave configuration before an already planned version.
-- Employer is always locked before Calendar/Type; version rows and immutable snapshots remain append-only.
CREATE OR REPLACE FUNCTION public.leave_revise_calendar(
 p_tenant uuid,p_calendar uuid,p_effective_from date,p_effective_until date,
 p_rest_days smallint[],p_holidays jsonb,p_source text,p_reason text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 a uuid:=leave.authorized(p_tenant,'leave.manage',true);
 prior leave.calendar_versions%ROWTYPE;
 context_version leave.calendar_versions%ROWTYPE;
 v uuid;
 employer uuid;
 entity_active boolean;
 calendar_active boolean;
 today date:=((now() AT TIME ZONE 'Africa/Cairo')::date);
 next_start date;
 new_until date;
 next_version integer;
 prior_closed boolean:=false;
BEGIN
 IF p_effective_from IS NULL OR p_effective_from<=today
    OR (p_effective_until IS NOT NULL AND p_effective_until<=p_effective_from)
    OR p_rest_days IS NULL OR cardinality(p_rest_days)>7
    OR array_position(p_rest_days,NULL) IS NOT NULL
    OR EXISTS(SELECT 1 FROM unnest(p_rest_days) d WHERE d<0 OR d>6)
    OR p_holidays IS NULL OR jsonb_typeof(p_holidays)<>'array'
    OR jsonb_array_length(p_holidays)>400
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_holidays) h
              WHERE jsonb_typeof(h)<>'object'
                 OR nullif(btrim(h->>'date'),'') IS NULL
                 OR nullif(btrim(h->>'name'),'') IS NULL
                 OR (h->>'date')::date<p_effective_from
                 OR (p_effective_until IS NOT NULL AND (h->>'date')::date>=p_effective_until))
    OR nullif(btrim(p_source),'') IS NULL OR length(btrim(p_source))>300
    OR nullif(btrim(p_reason),'') IS NULL OR length(btrim(p_reason))>500 THEN
  RAISE EXCEPTION 'leave_calendar_input_invalid' USING ERRCODE='22023';
 END IF;

 -- Nonlocking discovery, then consistent Employer -> Calendar -> version lock order.
 SELECT c.employer_entity_id INTO employer
 FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.id=p_calendar;
 IF employer IS NULL THEN
  RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23503';
 END IF;
 SELECT e.is_active INTO entity_active
 FROM platform_core.tenant_legal_entities e
 WHERE e.tenant_id=p_tenant AND e.id=employer FOR UPDATE;
 IF NOT coalesce(entity_active,false) THEN
  RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 SELECT c.is_active INTO calendar_active
 FROM leave.calendars c
 WHERE c.tenant_id=p_tenant AND c.id=p_calendar AND c.employer_entity_id=employer
 FOR UPDATE;
 IF NOT coalesce(calendar_active,false) THEN
  RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23503';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);

 -- A same-start replacement is intentionally a conflict. Find the existing range
 -- immediately before/at the requested day, and the next scheduled boundary.
 SELECT cv.* INTO prior FROM leave.calendar_versions cv
 WHERE cv.tenant_id=p_tenant AND cv.calendar_id=p_calendar AND cv.effective_from<=p_effective_from
 ORDER BY cv.effective_from DESC,cv.version DESC LIMIT 1 FOR UPDATE;
 IF FOUND AND prior.effective_from=p_effective_from THEN
  RAISE EXCEPTION 'leave_calendar_revision_invalid' USING ERRCODE='23P01';
 END IF;
 SELECT min(cv.effective_from) INTO next_start FROM leave.calendar_versions cv
 WHERE cv.tenant_id=p_tenant AND cv.calendar_id=p_calendar AND cv.effective_from>p_effective_from;
 SELECT max(cv.version)+1 INTO next_version FROM leave.calendar_versions cv
 WHERE cv.tenant_id=p_tenant AND cv.calendar_id=p_calendar;
 IF next_version IS NULL THEN
  RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23503';
 END IF;

 -- If the requested date is inside a configured range, close only its prior
 -- boundary. If that prior snapshot expired earlier, preserve the intervening gap.
 IF prior.id IS NOT NULL AND (prior.effective_until IS NULL OR prior.effective_until>p_effective_from) THEN
  UPDATE leave.calendar_versions SET effective_until=p_effective_from
  WHERE tenant_id=p_tenant AND id=prior.id;
  prior_closed:=true;
 END IF;

 new_until:=p_effective_until;
 IF next_start IS NOT NULL THEN
  IF new_until IS NULL THEN new_until:=next_start; END IF;
  IF new_until>next_start THEN
   RAISE EXCEPTION 'leave_calendar_revision_invalid' USING ERRCODE='23P01';
  END IF;
 END IF;
 IF new_until IS NOT NULL AND new_until<=p_effective_from THEN
  RAISE EXCEPTION 'leave_calendar_input_invalid' USING ERRCODE='22023';
 END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_holidays) h
           WHERE new_until IS NOT NULL AND (h->>'date')::date>=new_until) THEN
  RAISE EXCEPTION 'leave_calendar_input_invalid' USING ERRCODE='22023';
 END IF;

 -- Use the nearest prior snapshot's timezone; if this is a calendar's first
 -- prospective version, inherit only timezone context from its next snapshot.
 IF prior.id IS NOT NULL THEN
  context_version:=prior;
 ELSE
  SELECT cv.* INTO context_version FROM leave.calendar_versions cv
  WHERE cv.tenant_id=p_tenant AND cv.calendar_id=p_calendar
  ORDER BY cv.effective_from,cv.version LIMIT 1 FOR UPDATE;
 END IF;
 IF context_version.id IS NULL THEN
  RAISE EXCEPTION 'leave_calendar_unavailable' USING ERRCODE='23503';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 INSERT INTO leave.calendar_versions(
  tenant_id,calendar_id,version,effective_from,effective_until,timezone,source,reason,created_by
 ) VALUES(p_tenant,p_calendar,next_version,p_effective_from,new_until,context_version.timezone,
          btrim(p_source),btrim(p_reason),a)
 RETURNING id INTO v;
 INSERT INTO leave.calendar_rest_days(tenant_id,calendar_version_id,weekday)
 SELECT p_tenant,v,d FROM (SELECT DISTINCT unnest(p_rest_days) AS d) normalized;
 INSERT INTO leave.calendar_holidays(tenant_id,calendar_version_id,holiday_date,name,source)
 SELECT p_tenant,v,(x->>'date')::date,btrim(x->>'name'),btrim(p_source)
 FROM jsonb_array_elements(p_holidays) x;

 -- Never permit an edit to make an existing configured Leave-Year uncovered.
 IF EXISTS(
   SELECT 1 FROM leave.year_periods yp
   WHERE yp.tenant_id=p_tenant AND yp.calendar_id=p_calendar
     AND NOT coalesce((
       SELECT range_agg(daterange(cv.effective_from,cv.effective_until,'[)'))
                @> daterange(yp.starts_on,yp.ends_on+1,'[)')
       FROM leave.calendar_versions cv
       WHERE cv.tenant_id=yp.tenant_id AND cv.calendar_id=yp.calendar_id
     ),false)
 ) THEN
  RAISE EXCEPTION 'leave_calendar_revision_breaks_year_period' USING ERRCODE='22023';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 IF prior_closed THEN
  INSERT INTO leave.config_audit_events(
   tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
  ) VALUES(p_tenant,employer,'calendar_version',prior.id,'superseded',a,btrim(p_reason),
           jsonb_build_object('superseded_by',v,'effective_from',p_effective_from));
 END IF;
 INSERT INTO leave.config_audit_events(
  tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,employer,'calendar_version',v,'created',a,btrim(p_reason),
          jsonb_build_object('calendar_id',p_calendar,'version',next_version,
                             'effective_from',p_effective_from,'effective_until',new_until));
 RETURN v;
END $f$;
REVOKE ALL ON FUNCTION public.leave_revise_calendar(uuid,uuid,date,date,smallint[],jsonb,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_revise_calendar(uuid,uuid,date,date,smallint[],jsonb,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.leave_revise_type(
 p_tenant uuid,p_type uuid,p_effective_from date,p_pay_effect text,p_balance_mode text,
 p_day_count_basis text,p_half boolean,p_source text,p_reason text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 a uuid:=leave.authorized(p_tenant,'leave.manage',true);
 prior leave.type_versions%ROWTYPE;
 employer uuid;
 v uuid;
 entity_active boolean;
 today date:=((now() AT TIME ZONE 'Africa/Cairo')::date);
 next_start date;
 next_version integer;
 prior_closed boolean:=false;
BEGIN
 IF p_effective_from IS NULL OR p_effective_from<=today
    OR p_pay_effect IS NULL OR p_pay_effect NOT IN('paid','unpaid')
    OR p_balance_mode IS NULL OR p_balance_mode NOT IN('tracked','untracked')
    OR p_day_count_basis IS NULL OR p_day_count_basis NOT IN('working_days','calendar_days')
    OR p_half IS NULL OR nullif(btrim(p_source),'') IS NULL OR length(btrim(p_source))>300
    OR nullif(btrim(p_reason),'') IS NULL OR length(btrim(p_reason))>500 THEN
  RAISE EXCEPTION 'leave_type_input_invalid' USING ERRCODE='22023';
 END IF;

 -- Nonlocking discovery, then consistent Employer -> Type -> version lock order.
 SELECT t.employer_entity_id INTO employer
 FROM leave.types t WHERE t.tenant_id=p_tenant AND t.id=p_type;
 IF employer IS NULL THEN
  RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503';
 END IF;
 SELECT e.is_active INTO entity_active
 FROM platform_core.tenant_legal_entities e
 WHERE e.tenant_id=p_tenant AND e.id=employer FOR UPDATE;
 IF NOT coalesce(entity_active,false) THEN
  RAISE EXCEPTION 'leave_employer_unavailable' USING ERRCODE='23503';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 PERFORM 1 FROM leave.types t
 WHERE t.tenant_id=p_tenant AND t.id=p_type AND t.employer_entity_id=employer
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503'; END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);

 SELECT tv.* INTO prior FROM leave.type_versions tv
 WHERE tv.tenant_id=p_tenant AND tv.leave_type_id=p_type AND tv.effective_from<=p_effective_from
 ORDER BY tv.effective_from DESC,tv.version DESC LIMIT 1 FOR UPDATE;
 IF FOUND AND prior.effective_from=p_effective_from THEN
  RAISE EXCEPTION 'leave_type_revision_invalid' USING ERRCODE='23P01';
 END IF;
 SELECT min(tv.effective_from) INTO next_start FROM leave.type_versions tv
 WHERE tv.tenant_id=p_tenant AND tv.leave_type_id=p_type AND tv.effective_from>p_effective_from;
 SELECT max(tv.version)+1 INTO next_version FROM leave.type_versions tv
 WHERE tv.tenant_id=p_tenant AND tv.leave_type_id=p_type;
 IF next_version IS NULL THEN
  RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='23503';
 END IF;
 IF prior.id IS NOT NULL AND (prior.effective_until IS NULL OR prior.effective_until>p_effective_from) THEN
  UPDATE leave.type_versions SET effective_until=p_effective_from
  WHERE tenant_id=p_tenant AND id=prior.id;
  prior_closed:=true;
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 INSERT INTO leave.type_versions(
  tenant_id,leave_type_id,version,effective_from,effective_until,pay_effect,balance_mode,
  day_count_basis,half_day_allowed,source,reason,created_by
 ) VALUES(p_tenant,p_type,next_version,p_effective_from,next_start,p_pay_effect,p_balance_mode,
          p_day_count_basis,p_half,btrim(p_source),btrim(p_reason),a)
 RETURNING id INTO v;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 IF prior_closed THEN
  INSERT INTO leave.config_audit_events(
   tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
  ) VALUES(p_tenant,employer,'leave_type_version',prior.id,'superseded',a,btrim(p_reason),
           jsonb_build_object('superseded_by',v,'effective_from',p_effective_from));
 END IF;
 INSERT INTO leave.config_audit_events(
  tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,employer,'leave_type_version',v,'created',a,btrim(p_reason),
          jsonb_build_object('leave_type_id',p_type,'version',next_version,
                             'effective_from',p_effective_from,'effective_until',next_start,
                             'pay_effect',p_pay_effect,'balance_mode',p_balance_mode,
                             'day_count_basis',p_day_count_basis));
 RETURN v;
END $f$;
REVOKE ALL ON FUNCTION public.leave_revise_type(uuid,uuid,date,text,text,text,boolean,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_revise_type(uuid,uuid,date,text,text,text,boolean,text,text) TO authenticated;
