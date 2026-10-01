-- Configuration commands share Employer -> parent-resource lock order. Calendar
-- revisions keep finite configurations extendable while preserving immutable content.
CREATE OR REPLACE FUNCTION leave.guard_effective_revision() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF TG_OP='DELETE' THEN
  RAISE EXCEPTION 'leave_snapshot_immutable' USING ERRCODE='55000';
 END IF;
 IF (to_jsonb(NEW)-'effective_until') IS DISTINCT FROM (to_jsonb(OLD)-'effective_until')
    OR NEW.effective_until IS NULL
    OR NEW.effective_until<=((now() AT TIME ZONE 'Africa/Cairo')::date)
    OR NEW.effective_until<=OLD.effective_from
    OR (OLD.effective_until IS NOT NULL
        AND OLD.effective_until<=((now() AT TIME ZONE 'Africa/Cairo')::date)) THEN
  RAISE EXCEPTION 'leave_snapshot_immutable' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION leave.guard_effective_revision() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.leave_revise_calendar(
 p_tenant uuid,p_calendar uuid,p_effective_from date,p_effective_until date,
 p_rest_days smallint[],p_holidays jsonb,p_source text,p_reason text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 a uuid:=leave.authorized(p_tenant,'leave.manage',true);
 old leave.calendar_versions%ROWTYPE;
 v uuid;
 employer uuid;
 entity_active boolean;
 calendar_active boolean;
 today date:=((now() AT TIME ZONE 'Africa/Cairo')::date);
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

 -- Nonlocking discovery only: serialize configuration beneath the Employer row.
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
 SELECT cv.* INTO old FROM leave.calendar_versions cv
 WHERE cv.tenant_id=p_tenant AND cv.calendar_id=p_calendar
   AND (cv.effective_until IS NULL OR cv.effective_until>today)
 ORDER BY cv.version DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR p_effective_from<=old.effective_from
    OR (old.effective_until IS NOT NULL AND p_effective_from>old.effective_until) THEN
  RAISE EXCEPTION 'leave_calendar_revision_invalid' USING ERRCODE='23P01';
 END IF;

 -- A finite latest version may be truncated prospectively or continued exactly
 -- at its exclusive end. It may never be silently extended across a gap.
 IF old.effective_until IS NULL OR p_effective_from<old.effective_until THEN
  UPDATE leave.calendar_versions SET effective_until=p_effective_from
  WHERE tenant_id=p_tenant AND id=old.id;
 END IF;
 INSERT INTO leave.calendar_versions(
   tenant_id,calendar_id,version,effective_from,effective_until,timezone,source,reason,created_by
 ) VALUES(p_tenant,p_calendar,old.version+1,p_effective_from,p_effective_until,
          old.timezone,btrim(p_source),btrim(p_reason),a)
 RETURNING id INTO v;
 INSERT INTO leave.calendar_rest_days(tenant_id,calendar_version_id,weekday)
 SELECT p_tenant,v,d FROM (SELECT DISTINCT unnest(p_rest_days) AS d) normalized;
 INSERT INTO leave.calendar_holidays(tenant_id,calendar_version_id,holiday_date,name,source)
 SELECT p_tenant,v,(x->>'date')::date,btrim(x->>'name'),btrim(p_source)
 FROM jsonb_array_elements(p_holidays) x;

 -- Reject any prospective revision that leaves an already configured year
 -- period without continuous calendar coverage. The exception rolls back closure.
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
 INSERT INTO leave.config_audit_events(
   tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,employer,'calendar_version',old.id,'superseded',a,btrim(p_reason),
          jsonb_build_object('superseded_by',v,'effective_from',p_effective_from));
 INSERT INTO leave.config_audit_events(
   tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,employer,'calendar_version',v,'created',a,btrim(p_reason),
          jsonb_build_object('calendar_id',p_calendar,'version',old.version+1,
                             'effective_from',p_effective_from,'effective_until',p_effective_until));
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
 old leave.type_versions%ROWTYPE;
 employer uuid;
 v uuid;
 entity_active boolean;
 today date:=((now() AT TIME ZONE 'Africa/Cairo')::date);
BEGIN
 IF p_effective_from IS NULL OR p_effective_from<=today
    OR p_pay_effect IS NULL OR p_pay_effect NOT IN('paid','unpaid')
    OR p_balance_mode IS NULL OR p_balance_mode NOT IN('tracked','untracked')
    OR p_day_count_basis IS NULL OR p_day_count_basis NOT IN('working_days','calendar_days')
    OR p_half IS NULL OR nullif(btrim(p_source),'') IS NULL OR length(btrim(p_source))>300
    OR nullif(btrim(p_reason),'') IS NULL OR length(btrim(p_reason))>500 THEN
  RAISE EXCEPTION 'leave_type_input_invalid' USING ERRCODE='22023';
 END IF;
 -- Discover the Employer without locking; then always acquire Employer before Type.
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
 SELECT tv.* INTO old FROM leave.type_versions tv
 WHERE tv.tenant_id=p_tenant AND tv.leave_type_id=p_type AND tv.effective_until IS NULL
 ORDER BY tv.version DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR p_effective_from<=old.effective_from THEN
  RAISE EXCEPTION 'leave_type_revision_invalid' USING ERRCODE='23P01';
 END IF;
 UPDATE leave.type_versions SET effective_until=p_effective_from
 WHERE tenant_id=p_tenant AND id=old.id;
 INSERT INTO leave.type_versions(
  tenant_id,leave_type_id,version,effective_from,pay_effect,balance_mode,
  day_count_basis,half_day_allowed,source,reason,created_by
 ) VALUES(p_tenant,p_type,old.version+1,p_effective_from,p_pay_effect,p_balance_mode,
          p_day_count_basis,p_half,btrim(p_source),btrim(p_reason),a)
 RETURNING id INTO v;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 INSERT INTO leave.config_audit_events(
  tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,employer,'leave_type_version',old.id,'superseded',a,btrim(p_reason),
          jsonb_build_object('superseded_by',v,'effective_from',p_effective_from));
 INSERT INTO leave.config_audit_events(
  tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,employer,'leave_type_version',v,'created',a,btrim(p_reason),
          jsonb_build_object('leave_type_id',p_type,'version',old.version+1,
                             'effective_from',p_effective_from,'pay_effect',p_pay_effect,
                             'balance_mode',p_balance_mode,'day_count_basis',p_day_count_basis));
 RETURN v;
END $f$;
REVOKE ALL ON FUNCTION public.leave_revise_type(uuid,uuid,date,text,text,text,boolean,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_revise_type(uuid,uuid,date,text,text,text,boolean,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.leave_create_year_period(
 p_tenant uuid,p_employer uuid,p_calendar uuid,p_starts date,p_ends date,
 p_label text,p_reason text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE
 a uuid:=leave.authorized(p_tenant,'leave.manage',true);
 out_id uuid;
 entity_active boolean;
 calendar_active boolean;
 calendar_employer uuid;
BEGIN
 IF p_starts IS NULL OR p_ends IS NULL OR p_ends<p_starts
    OR nullif(btrim(p_label),'') IS NULL OR length(btrim(p_label))>120
    OR nullif(btrim(p_reason),'') IS NULL OR length(btrim(p_reason))>500 THEN
  RAISE EXCEPTION 'leave_year_period_invalid' USING ERRCODE='22023';
 END IF;
 SELECT c.employer_entity_id INTO calendar_employer
 FROM leave.calendars c WHERE c.tenant_id=p_tenant AND c.id=p_calendar;
 IF calendar_employer IS NULL OR calendar_employer<>p_employer THEN
  RAISE EXCEPTION 'leave_year_period_invalid' USING ERRCODE='22023';
 END IF;
 -- Shared Employer -> Calendar order; validate coverage only after both locks.
 SELECT e.is_active INTO entity_active
 FROM platform_core.tenant_legal_entities e
 WHERE e.tenant_id=p_tenant AND e.id=p_employer FOR UPDATE;
 IF NOT coalesce(entity_active,false) THEN
  RAISE EXCEPTION 'leave_employer_or_calendar_unavailable' USING ERRCODE='23503';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 SELECT c.is_active INTO calendar_active
 FROM leave.calendars c
 WHERE c.tenant_id=p_tenant AND c.id=p_calendar AND c.employer_entity_id=p_employer
 FOR UPDATE;
 IF NOT coalesce(calendar_active,false) THEN
  RAISE EXCEPTION 'leave_employer_or_calendar_unavailable' USING ERRCODE='23503';
 END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 IF NOT coalesce((
   SELECT range_agg(daterange(v.effective_from,v.effective_until,'[)'))
             @> daterange(p_starts,p_ends+1,'[)')
   FROM leave.calendar_versions v
   WHERE v.tenant_id=p_tenant AND v.calendar_id=p_calendar
 ),false) THEN
  RAISE EXCEPTION 'leave_year_period_invalid' USING ERRCODE='22023';
 END IF;
 INSERT INTO leave.year_periods(
  tenant_id,employer_entity_id,calendar_id,starts_on,ends_on,label,created_by
 ) VALUES(p_tenant,p_employer,p_calendar,p_starts,p_ends,btrim(p_label),a)
 RETURNING id INTO out_id;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 INSERT INTO leave.config_audit_events(
  tenant_id,employer_entity_id,object_kind,object_id,action,actor_user_id,reason,details
 ) VALUES(p_tenant,p_employer,'year_period',out_id,'created',a,btrim(p_reason),
          jsonb_build_object('calendar_id',p_calendar,'starts_on',p_starts,
                             'ends_on',p_ends,'label',btrim(p_label)));
 RETURN out_id;
END $f$;
REVOKE ALL ON FUNCTION public.leave_create_year_period(uuid,uuid,uuid,date,date,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_create_year_period(uuid,uuid,uuid,date,date,text,text) TO authenticated;
