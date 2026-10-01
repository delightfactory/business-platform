-- Slice A1: immutable mapping evidence on Leave previews; locally qualified.
-- Time-fact conflict and all-date overlap remain conservative until A2.

ALTER TABLE leave.requests ADD COLUMN half_day_part text,
 ADD CONSTRAINT leave_request_half_day_part_check CHECK ((is_half_day OR half_day_part IS NULL) AND (half_day_part IS NULL OR half_day_part IN ('first','second')));
ALTER TABLE leave.request_days
 ADD COLUMN half_day_part text,
 ADD COLUMN halfday_mapping_state text,
 ADD COLUMN halfday_mapping_snapshot jsonb,
 ADD COLUMN halfday_policy_template_id uuid,
 ADD COLUMN halfday_policy_version integer,
 ADD COLUMN halfday_algorithm_version text,
 ADD CONSTRAINT leave_request_day_halfday_state_check CHECK (halfday_mapping_state IS NULL OR halfday_mapping_state IN ('leave_only','mapped','review_required')),
 ADD CONSTRAINT leave_request_day_halfday_part_check CHECK ((is_half_day OR half_day_part IS NULL) AND (half_day_part IS NULL OR half_day_part IN ('first','second'))),
 ADD CONSTRAINT leave_request_day_halfday_provenance_check CHECK (halfday_mapping_state IS DISTINCT FROM 'mapped' OR
  (halfday_mapping_snapshot IS NOT NULL AND halfday_policy_template_id IS NOT NULL AND halfday_policy_version IS NOT NULL AND halfday_algorithm_version IS NOT NULL));

CREATE FUNCTION leave.guard_submitted_halfday_part_immutable() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$
BEGIN
 IF NEW.half_day_part IS DISTINCT FROM OLD.half_day_part THEN RAISE EXCEPTION 'leave_halfday_original_part_immutable' USING ERRCODE='55000'; END IF;
 RETURN NEW;
END $f$;

REVOKE ALL ON FUNCTION leave.guard_submitted_halfday_part_immutable() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_request_halfday_part_immutable BEFORE UPDATE ON leave.requests FOR EACH ROW EXECUTE FUNCTION leave.guard_submitted_halfday_part_immutable();

CREATE FUNCTION leave.halfday_policy_snapshot(p_tenant uuid,p_employment uuid,p_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE policy jsonb;
BEGIN
 SELECT jsonb_build_object('policy_template_id',i.policy_template_id,'policy_version',i.policy_version,
  'schedule_kind',i.schedule_kind,'timezone_name',i.timezone_name,'shift_start',v.shift_start,'shift_end',v.shift_end,
  'ends_next_day',v.ends_next_day,'break_minutes',i.break_minutes,'fixed_break_start',v.fixed_break_start,
  'fixed_break_end',v.fixed_break_end,'required_minutes',i.required_minutes,
  'flexible_halfday_break_minutes',v.flexible_halfday_break_minutes,'work_days',v.work_days)
 INTO policy FROM time.work_instances i JOIN time.work_policy_versions v
  ON v.tenant_id=i.tenant_id AND v.template_id=i.policy_template_id AND v.version=i.policy_version
 WHERE i.tenant_id=p_tenant AND i.employment_id=p_employment AND i.operational_date=p_date ORDER BY i.id LIMIT 1;
 IF policy IS NOT NULL THEN RETURN policy; END IF;
 SELECT jsonb_build_object('policy_template_id',coalesce(o.policy_template_id,a.work_policy_template_id),
  'policy_version',coalesce(o.policy_version,a.work_policy_version),'schedule_kind',v.schedule_kind,
  'timezone_name',v.timezone_name,'shift_start',v.shift_start,'shift_end',v.shift_end,
  'ends_next_day',v.ends_next_day,'break_minutes',v.break_minutes,'fixed_break_start',v.fixed_break_start,
  'fixed_break_end',v.fixed_break_end,'required_minutes',v.required_minutes,
  'flexible_halfday_break_minutes',v.flexible_halfday_break_minutes,'work_days',v.work_days)
 INTO policy FROM people.work_assignments a
 LEFT JOIN LATERAL (SELECT x.policy_template_id,x.policy_version FROM time.work_policy_overrides x
  WHERE x.tenant_id=a.tenant_id AND x.employment_id=a.employment_id AND x.cancelled_at IS NULL
   AND x.valid_from<=p_date AND x.valid_until>p_date ORDER BY x.valid_from DESC LIMIT 1)o ON true
 JOIN time.work_policy_versions v ON v.tenant_id=a.tenant_id
  AND v.template_id=coalesce(o.policy_template_id,a.work_policy_template_id)
  AND v.version=coalesce(o.policy_version,a.work_policy_version)
 WHERE a.tenant_id=p_tenant AND a.employment_id=p_employment AND a.valid_from<=p_date
  AND (a.valid_until IS NULL OR a.valid_until>p_date) ORDER BY a.valid_from DESC,a.id LIMIT 1;
 RETURN policy;
END $f$;
REVOKE ALL ON FUNCTION leave.halfday_policy_snapshot(uuid,uuid,date) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.halfday_preview_evidence(p_tenant uuid,p_employment uuid,p_date date,p_part text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE policy jsonb; mapped jsonb;
BEGIN
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',pg_catalog.now()) THEN
  RETURN jsonb_build_object('state','leave_only','part',p_part,'policy_template_id',NULL,'policy_version',NULL,'algorithm_version',NULL,'mapping',NULL);
 END IF;
 policy:=leave.halfday_policy_snapshot(p_tenant,p_employment,p_date);
 IF policy IS NULL OR policy->'work_days' IS NULL OR NOT (extract(dow FROM p_date)::int+1=ANY(ARRAY(SELECT jsonb_array_elements_text(policy->'work_days')::smallint))) THEN
  RETURN jsonb_build_object('state','review_required','reason','effective_policy_unavailable','part',p_part,
   'policy_template_id',policy->'policy_template_id','policy_version',policy->'policy_version','algorithm_version','leave-halfday-v1');
 END IF;
 mapped:=time.leave_halfday_mapping(policy,p_date,p_part);
 RETURN mapped||jsonb_build_object('state',mapped->>'state','part',p_part,'policy_template_id',policy->'policy_template_id',
  'policy_version',policy->'policy_version','mapping',mapped);
END $f$;
REVOKE ALL ON FUNCTION leave.halfday_preview_evidence(uuid,uuid,date,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.request_preview_with_mapping(p_tenant uuid,p_employer uuid,p_employment uuid,p_type uuid,p_start date,p_end date,p_half_day boolean,p_part text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE base jsonb; out_days jsonb:='[]'::jsonb; day jsonb; ev jsonb; total numeric:=0;
BEGIN
 base:=leave.request_preview(p_tenant,p_employer,p_type,p_start,p_end,p_half_day);
 FOR day IN SELECT value FROM jsonb_array_elements(base->'days') LOOP
  IF (day->>'is_half_day')::boolean THEN
   ev:=leave.halfday_preview_evidence(p_tenant,p_employment,(day->>'leave_date')::date,p_part);
   day:=day||jsonb_build_object('half_day_part',p_part,'halfday_mapping_state',ev->>'state',
    'halfday_mapping_snapshot',ev,'halfday_policy_template_id',nullif(ev->>'policy_template_id','')::uuid,
    'halfday_policy_version',nullif(ev->>'policy_version','')::int,'halfday_algorithm_version',ev->>'algorithm_version');
  ELSE
   day:=day||jsonb_build_object('half_day_part',NULL,'halfday_mapping_state',NULL,'halfday_mapping_snapshot',NULL,
    'halfday_policy_template_id',NULL,'halfday_policy_version',NULL,'halfday_algorithm_version',NULL);
  END IF;
  total:=total+(day->>'units')::numeric; out_days:=out_days||jsonb_build_array(day);
 END LOOP;
 RETURN base||jsonb_build_object('days',out_days,'total_units',total);
END $f$;
REVOKE ALL ON FUNCTION leave.request_preview_with_mapping(uuid,uuid,uuid,uuid,date,date,boolean,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION leave.a1_replace_once(src text,old_text text,new_text text,label text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE n int;
BEGIN
 n:=(length(src)-length(replace(src,old_text,'')))/NULLIF(length(old_text),0);
 IF n IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'halfday_a1_anchor_count_%: %',label,n USING ERRCODE='55000'; END IF;
 RETURN replace(src,old_text,new_text);
END $f$;
REVOKE ALL ON FUNCTION leave.a1_replace_once(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

-- Create a private submit-helper variant with the original selected part. Existing public own/HR signatures stay intact.
DO $f$
DECLARE def text;
BEGIN
 def:=pg_get_functiondef('leave.create_submitted_request(uuid,uuid,people.employments,uuid,date,date,boolean,text,uuid,text,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'CREATE OR REPLACE FUNCTION leave.create_submitted_request(','CREATE FUNCTION leave.create_submitted_request_halfday(','submit helper name');
 def:=leave.a1_replace_once(def,'p_half_day boolean, p_reason text','p_half_day boolean, p_part text, p_reason text','submit helper signature');
 def:=leave.a1_replace_once(def,'preview:=leave.request_preview(p_tenant,p_employment.employer_entity_id,p_type,p_start,p_end,p_half_day);',
  'preview:=leave.request_preview_with_mapping(p_tenant,p_employment.employer_entity_id,p_employment.id,p_type,p_start,p_end,p_half_day,p_part);','submit preview');
 def:=leave.a1_replace_once(def,'start_date,end_date,is_half_day,request_source,state,version,current_preview_version,','start_date,end_date,is_half_day,half_day_part,request_source,state,version,current_preview_version,','request header columns');
 def:=leave.a1_replace_once(def,'p_half_day,p_source,''submitted'',1,1,p_actor,p_actor,','p_half_day,p_part,p_source,''submitted'',1,1,p_actor,p_actor,','request header values');
 def:=leave.a1_replace_once(def,'balance_mode,is_weekly_rest,holiday_name,eligible,units,is_half_day)',
  'balance_mode,is_weekly_rest,holiday_name,eligible,units,is_half_day,half_day_part,halfday_mapping_state,halfday_mapping_snapshot,halfday_policy_template_id,halfday_policy_version,halfday_algorithm_version)','day insert columns');
 def:=leave.a1_replace_once(def,'(day->>''units'')::numeric,(day->>''is_half_day'')::boolean);',
  '(day->>''units'')::numeric,(day->>''is_half_day'')::boolean,day->>''half_day_part'',day->>''halfday_mapping_state'',day->''halfday_mapping_snapshot'',nullif(day->>''halfday_policy_template_id'','''')::uuid,nullif(day->>''halfday_policy_version'','''')::int,day->>''halfday_algorithm_version'');','day insert values');
 EXECUTE def;
END $f$;

REVOKE ALL ON FUNCTION leave.create_submitted_request_halfday(uuid,uuid,people.employments,uuid,date,date,boolean,text,text,uuid,text,text,text) FROM PUBLIC,anon,authenticated,service_role;

DO $f$
DECLARE def text;
BEGIN
 def:=pg_get_functiondef('public.leave_submit_own_request(uuid,uuid,date,date,boolean,text,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'IF p_half_day_part IS NOT NULL THEN RAISE EXCEPTION ''leave_half_day_part_unavailable'' USING ERRCODE=''23514''; END IF;',
  'IF (NOT p_half_day AND p_half_day_part IS NOT NULL) OR (p_half_day_part IS NOT NULL AND p_half_day_part NOT IN (''first'',''second'')) THEN RAISE EXCEPTION ''leave_half_day_part_invalid'' USING ERRCODE=''22023''; END IF;','own part validation');
 def:=leave.a1_replace_once(def,'RETURN leave.create_submitted_request(p_tenant,employee,emp,p_type,p_start,p_end,p_half_day,',
  'RETURN leave.create_submitted_request_halfday(p_tenant,employee,emp,p_type,p_start,p_end,p_half_day,p_half_day_part,','own helper call');
 EXECUTE def;
 def:=pg_get_functiondef('public.leave_record_hr_request(uuid,uuid,uuid,uuid,date,date,boolean,text,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'IF p_half_day_part IS NOT NULL THEN RAISE EXCEPTION ''leave_half_day_part_unavailable'' USING ERRCODE=''23514''; END IF;',
  'IF (NOT p_half_day AND p_half_day_part IS NOT NULL) OR (p_half_day_part IS NOT NULL AND p_half_day_part NOT IN (''first'',''second'')) THEN RAISE EXCEPTION ''leave_half_day_part_invalid'' USING ERRCODE=''22023''; END IF;','HR part validation');
 def:=leave.a1_replace_once(def,'RETURN leave.create_submitted_request(p_tenant,p_employee,emp,p_type,p_start,p_end,p_half_day,',
  'RETURN leave.create_submitted_request_halfday(p_tenant,p_employee,emp,p_type,p_start,p_end,p_half_day,p_half_day_part,','HR helper call');
 EXECUTE def;
END $f$;

-- Request details and approval equality compare include the immutable mapping evidence.
DO $f$
DECLARE def text;
BEGIN
 def:=pg_get_functiondef('leave.request_preview_snapshot(uuid,uuid,integer)'::regprocedure);
 def:=leave.a1_replace_once(def,'''eligible'',d.eligible,''units'',d.units,''is_half_day'',d.is_half_day)',
  '''eligible'',d.eligible,''units'',d.units,''is_half_day'',d.is_half_day,''half_day_part'',d.half_day_part,''halfday_mapping_state'',d.halfday_mapping_state,''halfday_mapping_snapshot'',d.halfday_mapping_snapshot,''halfday_policy_template_id'',d.halfday_policy_template_id,''halfday_policy_version'',d.halfday_policy_version,''halfday_algorithm_version'',d.halfday_algorithm_version)','preview equality fields');
 EXECUTE def;
 def:=pg_get_functiondef('leave.request_json(uuid,uuid,integer)'::regprocedure);
 def:=leave.a1_replace_once(def,'''is_half_day'',r.is_half_day,''state'',r.state,''version'',r.version,',
  '''is_half_day'',r.is_half_day,''half_day_part'',r.half_day_part,''state'',r.state,''version'',r.version,','request header detail');
 def:=leave.a1_replace_once(def,'''eligible'',d.eligible,''units'',d.units,''is_half_day'',d.is_half_day) ORDER BY d.leave_date)',
  '''eligible'',d.eligible,''units'',d.units,''is_half_day'',d.is_half_day,''half_day_part'',d.half_day_part,''halfday_mapping_state'',d.halfday_mapping_state,''halfday_mapping_snapshot'',d.halfday_mapping_snapshot,''halfday_policy_template_id'',d.halfday_policy_template_id,''halfday_policy_version'',d.halfday_policy_version,''halfday_algorithm_version'',d.halfday_algorithm_version) ORDER BY d.leave_date)','request detail day mapping');
 EXECUTE def;
 def:=pg_get_functiondef('leave.request_summary(uuid,uuid)'::regprocedure);
 def:=leave.a1_replace_once(def,'''is_half_day'',r.is_half_day,''state'',r.state,''version'',r.version,',
  '''is_half_day'',r.is_half_day,''half_day_part'',r.half_day_part,''state'',r.state,''version'',r.version,','request summary header part');
 EXECUTE def;
END $f$;

-- Own mapping options always resolve the current live link. HR uses its separate leave.manage route.
CREATE FUNCTION public.leave_my_halfday_mapping_options(p_tenant uuid,p_operational_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=auth.uid(); employee uuid; employment uuid; policy jsonb; f jsonb; s jsonb;
BEGIN
 IF actor IS NULL OR p_operational_date IS NULL OR NOT leave.request_actor_allowed(p_tenant,actor,'leave.self.request') THEN RAISE EXCEPTION 'leave_self_forbidden' USING ERRCODE='42501'; END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.people',pg_catalog.now())
    OR NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.leave',pg_catalog.now()) THEN
  RAISE EXCEPTION 'leave_new_work_disabled' USING ERRCODE='55000'; END IF;
 SELECT employee_id INTO employee FROM people.employee_user_links WHERE tenant_id=p_tenant AND user_id=actor AND unlinked_at IS NULL;
 IF employee IS NULL THEN RAISE EXCEPTION 'leave_self_link_required' USING ERRCODE='42501'; END IF;
 SELECT id INTO employment FROM people.employments WHERE tenant_id=p_tenant AND employee_id=employee AND employment_status='active' AND start_date<=p_operational_date AND (end_date IS NULL OR end_date>=p_operational_date) ORDER BY id LIMIT 1;
 IF employment IS NULL THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',pg_catalog.now()) THEN RETURN jsonb_build_object('state','leave_only','attendance_enabled',false,'parts','[]'::jsonb); END IF;
 policy:=leave.halfday_policy_snapshot(p_tenant,employment,p_operational_date);
 IF policy IS NULL THEN RETURN jsonb_build_object('state','review_required','attendance_enabled',true,'reason','effective_policy_unavailable'); END IF;
 IF policy->'work_days' IS NULL OR NOT (extract(dow FROM p_operational_date)::int+1=ANY(ARRAY(SELECT jsonb_array_elements_text(policy->'work_days')::smallint))) THEN RETURN jsonb_build_object('state','review_required','attendance_enabled',true,'reason','not_scheduled_workday'); END IF;
 IF policy->>'schedule_kind'='fixed' THEN
  f:=time.leave_halfday_mapping(policy,p_operational_date,'first'); s:=time.leave_halfday_mapping(policy,p_operational_date,'second');
  RETURN jsonb_build_object('state','mapped_options','schedule_kind','fixed','parts',jsonb_build_array(jsonb_build_object('part','first','mapping',f),jsonb_build_object('part','second','mapping',s)),'attendance_enabled',true);
 END IF;
 IF policy->>'schedule_kind'<>'flexible' THEN RETURN jsonb_build_object('state','review_required','attendance_enabled',true,'reason','schedule_kind_unavailable'); END IF;
 RETURN jsonb_build_object('state','mapped_options','schedule_kind','flexible','part',NULL,'mapping',time.leave_halfday_mapping(policy,p_operational_date,NULL),'attendance_enabled',true);
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_halfday_mapping_options(uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_halfday_mapping_options(uuid,date) TO authenticated;
CREATE FUNCTION public.leave_hr_halfday_mapping_options(p_tenant uuid,p_employment uuid,p_operational_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid; policy jsonb; f jsonb; s jsonb;
BEGIN
 actor:=leave.authorized(p_tenant,'leave.manage',true);
 IF p_employment IS NULL OR p_operational_date IS NULL OR NOT EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND id=p_employment AND employment_status='active' AND start_date<=p_operational_date AND (end_date IS NULL OR end_date>=p_operational_date)) THEN RAISE EXCEPTION 'leave_employment_range_unavailable' USING ERRCODE='23514'; END IF;
 IF NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.attendance',pg_catalog.now()) THEN RETURN jsonb_build_object('state','leave_only','attendance_enabled',false,'parts','[]'::jsonb); END IF;
 policy:=leave.halfday_policy_snapshot(p_tenant,p_employment,p_operational_date);
 IF policy IS NULL THEN RETURN jsonb_build_object('state','review_required','attendance_enabled',true,'reason','effective_policy_unavailable'); END IF;
 IF policy->'work_days' IS NULL OR NOT (extract(dow FROM p_operational_date)::int+1=ANY(ARRAY(SELECT jsonb_array_elements_text(policy->'work_days')::smallint))) THEN RETURN jsonb_build_object('state','review_required','attendance_enabled',true,'reason','not_scheduled_workday'); END IF;
 IF policy->>'schedule_kind'='fixed' THEN f:=time.leave_halfday_mapping(policy,p_operational_date,'first'); s:=time.leave_halfday_mapping(policy,p_operational_date,'second'); RETURN jsonb_build_object('state','mapped_options','schedule_kind','fixed','parts',jsonb_build_array(jsonb_build_object('part','first','mapping',f),jsonb_build_object('part','second','mapping',s)),'attendance_enabled',true); END IF;
 IF policy->>'schedule_kind'<>'flexible' THEN RETURN jsonb_build_object('state','review_required','attendance_enabled',true,'reason','schedule_kind_unavailable'); END IF;
 RETURN jsonb_build_object('state','mapped_options','schedule_kind','flexible','part',NULL,'mapping',time.leave_halfday_mapping(policy,p_operational_date,NULL),'attendance_enabled',true);
END $f$;
REVOKE ALL ON FUNCTION public.leave_hr_halfday_mapping_options(uuid,uuid,date) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_hr_halfday_mapping_options(uuid,uuid,date) TO authenticated;

-- Existing refresh keeps the effective reviewed part; new own and HR supplements can refine it.
DO $f$
DECLARE def text;
BEGIN
 def:=pg_get_functiondef('public.leave_refresh_request_preview(uuid,uuid,integer,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'computed:=leave.request_preview(p_tenant,r.employer_entity_id,r.leave_type_id,' || E'\n' || '    r.start_date,r.end_date,r.is_half_day);',
  'PERFORM 1 FROM time.work_instances i WHERE i.tenant_id=p_tenant AND i.employment_id=r.employment_id AND i.operational_date BETWEEN r.start_date AND r.end_date AND EXISTS(SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id AND d.preview_version=r.current_preview_version AND d.leave_date=i.operational_date AND d.eligible AND d.units>0) ORDER BY i.operational_date,i.id FOR NO KEY UPDATE;' || E'\n' || 'computed:=leave.request_preview_with_mapping(p_tenant,r.employer_entity_id,r.employment_id,r.leave_type_id,r.start_date,r.end_date,r.is_half_day,(SELECT d.half_day_part FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id AND d.preview_version=r.current_preview_version AND d.is_half_day LIMIT 1));','legacy refresh lock and recompute');
 def:=leave.a1_replace_once(def,'balance_mode,is_weekly_rest,holiday_name,eligible,units,is_half_day)',
  'balance_mode,is_weekly_rest,holiday_name,eligible,units,is_half_day,half_day_part,halfday_mapping_state,halfday_mapping_snapshot,halfday_policy_template_id,halfday_policy_version,halfday_algorithm_version)','legacy refresh columns');
 def:=leave.a1_replace_once(def,'(x->>''units'')::numeric,(x->>''is_half_day'')::boolean',
  '(x->>''units'')::numeric,(x->>''is_half_day'')::boolean,x->>''half_day_part'',x->>''halfday_mapping_state'',x->''halfday_mapping_snapshot'',nullif(x->>''halfday_policy_template_id'','''')::uuid,nullif(x->>''halfday_policy_version'','''')::int,x->>''halfday_algorithm_version''','legacy refresh values');
 EXECUTE def;

 -- Employee-only clone forces current-link checks even for an actor with HR roles.
 def:=pg_get_functiondef('public.leave_refresh_request_preview(uuid,uuid,integer,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'CREATE OR REPLACE FUNCTION public.leave_refresh_request_preview(',
  'CREATE FUNCTION public.leave_my_refresh_halfday_preview(','own refresh name');
 def:=leave.a1_replace_once(def,'p_expected_version integer, p_reason text',
  'p_expected_version integer, p_half_day_part text, p_reason text','own refresh signature');
 def:=leave.a1_replace_once(def,'use_self:=NOT platform_private.has_tenant_permission(p_tenant,actor,''leave.approve'');','use_self:=true;','own refresh identity');
 def:=leave.a1_replace_once(def,'computed:=leave.request_preview_with_mapping(p_tenant,r.employer_entity_id,r.employment_id,r.leave_type_id,r.start_date,r.end_date,r.is_half_day,(SELECT d.half_day_part FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id AND d.preview_version=r.current_preview_version AND d.is_half_day LIMIT 1));',
  'IF NOT r.is_half_day OR (p_half_day_part IS NOT NULL AND p_half_day_part NOT IN (''first'',''second'')) THEN RAISE EXCEPTION ''leave_halfday_refresh_invalid'' USING ERRCODE=''22023''; END IF; computed:=leave.request_preview_with_mapping(p_tenant,r.employer_entity_id,r.employment_id,r.leave_type_id,r.start_date,r.end_date,r.is_half_day,p_half_day_part);','own refresh mapping');
 def:=leave.a1_replace_once(def,'''reason'',pg_catalog.btrim(p_reason));','''reason'',pg_catalog.btrim(p_reason),''half_day_part'',p_half_day_part);','own refresh payload');
 EXECUTE def;

 -- HR gets a distinct route, using the same CAS and idempotency key rules.
 def:=pg_get_functiondef('public.leave_my_refresh_halfday_preview(uuid,uuid,integer,text,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'CREATE OR REPLACE FUNCTION public.leave_my_refresh_halfday_preview(',
  'CREATE FUNCTION public.leave_hr_refresh_halfday_preview(','HR refresh name');
 def:=leave.a1_replace_once(def,'use_self:=true;','use_self:=false;','HR refresh identity');
 EXECUTE def;
END $f$;
REVOKE ALL ON FUNCTION public.leave_my_refresh_halfday_preview(uuid,uuid,integer,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_my_refresh_halfday_preview(uuid,uuid,integer,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.leave_hr_refresh_halfday_preview(uuid,uuid,integer,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_hr_refresh_halfday_preview(uuid,uuid,integer,text,text,text) TO authenticated;

-- Approval recomputes full mapping evidence before comparison and again after WorkInstance locks.
DO $f$
DECLARE def text;
BEGIN
 def:=pg_get_functiondef('public.leave_approve_request(uuid,uuid,integer,integer,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'computed:=leave.request_preview(p_tenant,r.employer_entity_id,r.leave_type_id,' || E'\n' || '    r.start_date,r.end_date,r.is_half_day);',
  'computed:=leave.request_preview_with_mapping(p_tenant,r.employer_entity_id,r.employment_id,r.leave_type_id,r.start_date,r.end_date,r.is_half_day,(SELECT d.half_day_part FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id AND d.preview_version=r.current_preview_version AND d.is_half_day LIMIT 1));','approval mapping recompute');
 def:=leave.a1_replace_once(def,'IF r.is_half_day AND platform_private.tenant_capability_is_enabled(p_tenant,''hr.attendance'',pg_catalog.now()) THEN',
  'IF r.is_half_day AND platform_private.tenant_capability_is_enabled(p_tenant,''hr.attendance'',pg_catalog.now()) AND EXISTS (SELECT 1 FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id AND d.preview_version=r.current_preview_version AND d.is_half_day AND d.eligible AND d.halfday_mapping_state IS DISTINCT FROM ''mapped'') THEN','approval mapped gate');
 EXECUTE def;
 def:=pg_get_functiondef('public.leave_approve_request(uuid,uuid,integer,integer,text,text)'::regprocedure);
 def:=leave.a1_replace_once(def,'ORDER BY i.operational_date,i.id FOR NO KEY UPDATE;',
  'ORDER BY i.operational_date,i.id FOR NO KEY UPDATE;' || E'\n' || '  computed:=leave.request_preview_with_mapping(p_tenant,r.employer_entity_id,r.employment_id,r.leave_type_id,r.start_date,r.end_date,r.is_half_day,(SELECT d.half_day_part FROM leave.request_days d WHERE d.tenant_id=p_tenant AND d.request_id=r.id AND d.preview_version=r.current_preview_version AND d.is_half_day LIMIT 1));' || E'\n' || '  stored:=leave.request_preview_snapshot(p_tenant,p_request,r.current_preview_version);' || E'\n' || '  IF computed IS DISTINCT FROM stored THEN RETURN pg_catalog.jsonb_build_object(''state'',''refresh_required'',''request_id'',p_request,''request_version'',r.version,''stored_preview_version'',r.current_preview_version,''stored_preview'',stored,''current_preview'',computed); END IF;','approval post-Time-lock refresh check');
 EXECUTE def;
END $f$;

DROP FUNCTION leave.a1_replace_once(text,text,text,text);
