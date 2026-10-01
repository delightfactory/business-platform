-- Accepted V1 employer-policy arithmetic, with bounded company settings.
-- This calculator does not infer protected categories or settle/expire balances.
CREATE TABLE leave.annual_policies (
 tenant_id uuid NOT NULL, id uuid NOT NULL DEFAULT gen_random_uuid(), employer_entity_id uuid NOT NULL,
 leave_type_id uuid NOT NULL, version integer NOT NULL CHECK(version>0),
 first_year_days numeric(6,2) NOT NULL CHECK(first_year_days BETWEEN 15 AND 366),
 later_year_days numeric(6,2) NOT NULL CHECK(later_year_days BETWEEN 21 AND 366 AND later_year_days>=first_year_days),
 minimum_service_days integer NOT NULL CHECK(minimum_service_days BETWEEN 0 AND 180),
 year_days integer NOT NULL CHECK(year_days BETWEEN 360 AND 365),
 source text NOT NULL, reason text NOT NULL, created_by uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,id),
 UNIQUE(tenant_id,employer_entity_id,leave_type_id,version),
 FOREIGN KEY(tenant_id,leave_type_id,employer_entity_id) REFERENCES leave.types(tenant_id,id,employer_entity_id)
);
CREATE TABLE leave.annual_calculations (
 tenant_id uuid NOT NULL, id uuid NOT NULL DEFAULT gen_random_uuid(), employee_id uuid NOT NULL,
 employer_entity_id uuid NOT NULL, leave_type_id uuid NOT NULL, year_period_id uuid NOT NULL,
 actor_user_id uuid NOT NULL REFERENCES auth.users(id), operation_key text NOT NULL,
 payload jsonb NOT NULL, result jsonb NOT NULL, granted_total numeric(10,2) NOT NULL CHECK(granted_total>=0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(), PRIMARY KEY(tenant_id,id),
 UNIQUE(tenant_id,actor_user_id,operation_key),
 FOREIGN KEY(tenant_id,employee_id) REFERENCES people.employees(tenant_id,id),
 FOREIGN KEY(tenant_id,leave_type_id,employer_entity_id) REFERENCES leave.types(tenant_id,id,employer_entity_id),
 FOREIGN KEY(tenant_id,year_period_id,employer_entity_id) REFERENCES leave.year_periods(tenant_id,id,employer_entity_id)
);
CREATE INDEX leave_annual_calculation_account ON leave.annual_calculations(tenant_id,employee_id,employer_entity_id,leave_type_id,year_period_id);
ALTER TABLE leave.annual_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave.annual_calculations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON leave.annual_policies,leave.annual_calculations FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER leave_annual_policy_immutable BEFORE UPDATE OR DELETE ON leave.annual_policies
 FOR EACH ROW EXECUTE FUNCTION leave.reject_snapshot_mutation();
CREATE TRIGGER leave_annual_calculation_immutable BEFORE UPDATE OR DELETE ON leave.annual_calculations
 FOR EACH ROW EXECUTE FUNCTION leave.reject_snapshot_mutation();

CREATE FUNCTION leave.annual_policy_json(p_tenant uuid,p_employer uuid,p_type uuid) RETURNS jsonb
 LANGUAGE sql STABLE SET search_path='' AS $f$
 SELECT coalesce((SELECT jsonb_build_object('version',version,'first_year_days',first_year_days,
  'later_year_days',later_year_days,'minimum_service_days',minimum_service_days,'year_days',year_days,
  'source',source,'reason',reason) FROM leave.annual_policies WHERE tenant_id=p_tenant
  AND employer_entity_id=p_employer AND leave_type_id=p_type ORDER BY version DESC LIMIT 1),
  jsonb_build_object('version',0,'first_year_days',15,'later_year_days',21,'minimum_service_days',180,
   'year_days',365,'source','V1 accepted employer policy 2026-10-01','reason','Accepted V1 default'));
$f$;
REVOKE ALL ON FUNCTION leave.annual_policy_json(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_save_annual_policy(p_tenant uuid,p_employer uuid,p_type uuid,p_expected_version integer,
 p_first_year_days numeric,p_later_year_days numeric,p_minimum_service_days integer,p_year_days integer,
 p_source text,p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=leave.authorized(p_tenant,'leave.manage',true); current_version integer;
BEGIN
 IF p_expected_version IS NULL OR p_expected_version<0 OR p_first_year_days IS NULL OR p_later_year_days IS NULL
  OR p_first_year_days::text IN('NaN','Infinity','-Infinity') OR p_later_year_days::text IN('NaN','Infinity','-Infinity')
  OR p_first_year_days NOT BETWEEN 15 AND 366 OR p_later_year_days NOT BETWEEN 21 AND 366
  OR p_later_year_days<p_first_year_days OR p_first_year_days<>round(p_first_year_days,2)
  OR p_later_year_days<>round(p_later_year_days,2) OR p_minimum_service_days IS NULL
  OR p_minimum_service_days NOT BETWEEN 0 AND 180 OR p_year_days IS NULL OR p_year_days NOT BETWEEN 360 AND 365
  OR length(btrim(coalesce(p_source,''))) NOT BETWEEN 3 AND 300
  OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 THEN
  RAISE EXCEPTION 'leave_annual_input_invalid' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM leave.types WHERE tenant_id=p_tenant AND id=p_type AND employer_entity_id=p_employer AND is_active) THEN
  RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='P0002'; END IF;
 PERFORM leave.authorized(p_tenant,'leave.manage',true);
 current_version:=(leave.annual_policy_json(p_tenant,p_employer,p_type)->>'version')::integer;
 IF current_version<>p_expected_version THEN RAISE EXCEPTION 'leave_annual_review_conflict' USING ERRCODE='PT409'; END IF;
 INSERT INTO leave.annual_policies(tenant_id,employer_entity_id,leave_type_id,version,first_year_days,later_year_days,
  minimum_service_days,year_days,source,reason,created_by) VALUES(p_tenant,p_employer,p_type,current_version+1,
  p_first_year_days,p_later_year_days,p_minimum_service_days,p_year_days,btrim(p_source),btrim(p_reason),actor);
 RETURN leave.annual_policy_json(p_tenant,p_employer,p_type);
END $f$;
REVOKE ALL ON FUNCTION public.leave_save_annual_policy(uuid,uuid,uuid,integer,numeric,numeric,integer,integer,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_save_annual_policy(uuid,uuid,uuid,integer,numeric,numeric,integer,integer,text,text) TO authenticated;

CREATE FUNCTION leave.annual_quote(p_tenant uuid,p_employee uuid,p_employer uuid,p_type uuid,p_period uuid,
 p_as_of date,p_rates jsonb,p_source text) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE employment people.employments%ROWTYPE; period leave.year_periods%ROWTYPE; policy jsonb; tv leave.type_versions%ROWTYPE;
 account uuid; already numeric:=0; target numeric:=0; raw_total numeric:=0; segments jsonb; result jsonb; eligible boolean; today date:=(now() AT TIME ZONE 'Africa/Cairo')::date;
BEGIN
 IF p_as_of IS NULL OR p_as_of>today OR p_rates IS NULL OR jsonb_typeof(p_rates)<>'array'
  OR jsonb_array_length(p_rates)>32 OR length(btrim(coalesce(p_source,''))) NOT BETWEEN 3 AND 300 THEN
  RAISE EXCEPTION 'leave_annual_input_invalid' USING ERRCODE='22023'; END IF;
 SELECT * INTO employment FROM people.employments WHERE tenant_id=p_tenant AND employee_id=p_employee
  AND employer_entity_id=p_employer AND employment_status='active' AND start_date<=today AND (end_date IS NULL OR end_date>=today);
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_active_employment_required' USING ERRCODE='23514'; END IF;
 SELECT * INTO period FROM leave.year_periods WHERE tenant_id=p_tenant AND id=p_period AND employer_entity_id=p_employer;
 IF NOT FOUND OR p_as_of<period.starts_on OR p_as_of>period.ends_on OR period.ends_on-period.starts_on>365 THEN
  RAISE EXCEPTION 'leave_annual_period_invalid' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM people.employments WHERE tenant_id=p_tenant AND employee_id=p_employee
  AND employer_entity_id=p_employer AND id<>employment.id AND start_date<=p_as_of
  AND (end_date IS NULL OR end_date>=period.starts_on)) THEN
  RAISE EXCEPTION 'leave_annual_employment_history_requires_review' USING ERRCODE='23514'; END IF;
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active)
  OR NOT EXISTS(SELECT 1 FROM leave.types WHERE tenant_id=p_tenant AND id=p_type AND employer_entity_id=p_employer AND is_active) THEN
  RAISE EXCEPTION 'leave_type_unavailable' USING ERRCODE='P0002'; END IF;
 SELECT * INTO tv FROM leave.type_versions WHERE tenant_id=p_tenant AND leave_type_id=p_type AND effective_from<=today
  AND (effective_until IS NULL OR effective_until>today);
 IF NOT FOUND OR tv.balance_mode<>'tracked' OR tv.pay_effect<>'paid' OR tv.day_count_basis<>'working_days' THEN
  RAISE EXCEPTION 'leave_annual_type_requires_paid_working_days' USING ERRCODE='23514'; END IF;
 policy:=leave.annual_policy_json(p_tenant,p_employer,p_type);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_rates) x WHERE jsonb_typeof(x)<>'object'
  OR NOT (x ?& ARRAY['from','annual_days','source']) OR jsonb_typeof(x->'annual_days')<>'number'
  OR jsonb_typeof(x->'from')<>'string' OR coalesce(x->>'from','') !~ '^\d{4}-\d{2}-\d{2}$'
  OR (x->>'annual_days')::numeric NOT BETWEEN 15 AND 366 OR (x->>'annual_days')::numeric<>round((x->>'annual_days')::numeric,2)
  OR (x->>'from')::date<employment.start_date OR (x->>'from')::date>p_as_of
  OR length(btrim(coalesce(x->>'source',''))) NOT BETWEEN 3 AND 300)
  OR (SELECT count(*) FROM jsonb_array_elements(p_rates))<>(SELECT count(DISTINCT (x->>'from')::date) FROM jsonb_array_elements(p_rates)x) THEN
  RAISE EXCEPTION 'leave_annual_rates_invalid' USING ERRCODE='22023'; END IF;
 SELECT id INTO account FROM leave.accounts WHERE tenant_id=p_tenant AND employee_id=p_employee AND employer_entity_id=p_employer
  AND leave_type_id=p_type AND year_period_id=p_period;
 SELECT coalesce(max(granted_total),0) INTO already FROM leave.annual_calculations WHERE tenant_id=p_tenant AND employee_id=p_employee
  AND employer_entity_id=p_employer AND leave_type_id=p_type AND year_period_id=p_period;
 IF account IS NOT NULL AND EXISTS(SELECT 1 FROM leave.ledger_entries WHERE tenant_id=p_tenant AND account_id=account
  AND (entry_kind='opening' OR (entry_kind='annual_grant' AND NOT EXISTS(SELECT 1 FROM leave.annual_calculations
   WHERE tenant_id=p_tenant AND employee_id=p_employee AND employer_entity_id=p_employer AND leave_type_id=p_type AND year_period_id=p_period AND granted_total>0)))) THEN
  RAISE EXCEPTION 'leave_annual_manual_balance_requires_review' USING ERRCODE='23514'; END IF;
 eligible:=p_as_of-employment.start_date+1 >= (policy->>'minimum_service_days')::integer;
 WITH daily AS (
  SELECT day::date AS date, coalesce((SELECT (x->>'annual_days')::numeric FROM jsonb_array_elements(p_rates)x
    WHERE (x->>'from')::date<=day::date ORDER BY (x->>'from')::date DESC LIMIT 1),
    CASE WHEN day::date-employment.start_date < (policy->>'year_days')::integer
     THEN (policy->>'first_year_days')::numeric ELSE (policy->>'later_year_days')::numeric END) AS rate,
   coalesce((SELECT x->>'source' FROM jsonb_array_elements(p_rates)x WHERE (x->>'from')::date<=day::date
    ORDER BY (x->>'from')::date DESC LIMIT 1),btrim(p_source)) AS source,
   CASE WHEN day::date-employment.start_date < (policy->>'year_days')::integer
    THEN (policy->>'first_year_days')::numeric ELSE (policy->>'later_year_days')::numeric END AS minimum_rate
  FROM generate_series(greatest(period.starts_on,employment.start_date)::timestamp,p_as_of::timestamp,interval '1 day') day
 ), islands AS (SELECT *,date-(row_number() OVER(PARTITION BY rate,source ORDER BY date))::integer AS island FROM daily),
 grouped AS (SELECT rate,source,count(*) AS days,min(date) AS starts_on,max(date) AS ends_on,
   bool_and(rate>=minimum_rate) AS valid FROM islands GROUP BY rate,source,island)
 SELECT coalesce(sum(rate*days),0)/(policy->>'year_days')::numeric,coalesce(jsonb_agg(jsonb_build_object(
  'from',starts_on,'to',ends_on,'days',days,'annual_days',rate,'source',source,'valid',valid) ORDER BY starts_on),'[]'::jsonb)
 INTO raw_total,segments FROM grouped;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(segments)x WHERE x->>'valid'='false') THEN
  RAISE EXCEPTION 'leave_annual_rate_below_policy' USING ERRCODE='23514'; END IF;
 target:=CASE WHEN eligible THEN ceil(raw_total*100)/100 ELSE 0 END;
 IF target<already THEN RAISE EXCEPTION 'leave_annual_reduction_requires_review' USING ERRCODE='23514'; END IF;
 result:=jsonb_build_object('employee_id',p_employee,'employee_name',(SELECT full_name FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee),
  'employer_id',p_employer,'type_id',p_type,'period_id',p_period,'employment_id',employment.id,'service_start',employment.start_date,
  'as_of',p_as_of,'policy',policy,'type_version',tv.id,'eligible',eligible,'service_days',greatest(p_as_of-employment.start_date+1,0),
  'raw_total',raw_total,'target_total',target,'already_granted',already,'delta',target-already,'segments',segments,'rates',p_rates,
  'source',btrim(p_source),'algorithm','v1-progressive-up-0.01');
 RETURN result||jsonb_build_object('review_hash',encode(extensions.digest(result::text,'sha256'),'hex'));
END $f$;
REVOKE ALL ON FUNCTION leave.annual_quote(uuid,uuid,uuid,uuid,uuid,date,jsonb,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.leave_annual_context(p_tenant uuid,p_employee uuid,p_employer uuid,p_type uuid,p_period uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE employment people.employments%ROWTYPE; period leave.year_periods%ROWTYPE; name text; type_name text;
BEGIN
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',true);
 SELECT * INTO employment FROM people.employments WHERE tenant_id=p_tenant AND employee_id=p_employee
  AND employer_entity_id=p_employer AND employment_status='active' AND start_date<=(now() AT TIME ZONE 'Africa/Cairo')::date
  AND (end_date IS NULL OR end_date>=(now() AT TIME ZONE 'Africa/Cairo')::date);
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_active_employment_required' USING ERRCODE='23514'; END IF;
 SELECT * INTO period FROM leave.year_periods WHERE tenant_id=p_tenant AND id=p_period AND employer_entity_id=p_employer;
 SELECT t.name INTO type_name FROM leave.types t WHERE tenant_id=p_tenant AND id=p_type AND employer_entity_id=p_employer AND is_active;
 IF period.id IS NULL OR type_name IS NULL THEN RAISE EXCEPTION 'leave_account_scope_invalid' USING ERRCODE='P0002'; END IF;
 SELECT full_name INTO name FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee;
 RETURN jsonb_build_object('policy',leave.annual_policy_json(p_tenant,p_employer,p_type),'employee_name',name,
  'type_name',type_name,'period_name',period.label,'starts_on',period.starts_on,'ends_on',period.ends_on,
  'service_start',employment.start_date,'today',(now() AT TIME ZONE 'Africa/Cairo')::date,
  'last_calculation',(SELECT result FROM leave.annual_calculations WHERE tenant_id=p_tenant AND employee_id=p_employee
   AND employer_entity_id=p_employer AND leave_type_id=p_type AND year_period_id=p_period ORDER BY granted_total DESC,created_at DESC,id DESC LIMIT 1));
END $f$;
REVOKE ALL ON FUNCTION public.leave_annual_context(uuid,uuid,uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_annual_context(uuid,uuid,uuid,uuid,uuid) TO authenticated;

CREATE FUNCTION public.leave_preview_annual_entitlement(p_tenant uuid,p_employee uuid,p_employer uuid,p_type uuid,p_period uuid,
 p_as_of date,p_rates jsonb,p_source text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
BEGIN
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',true);
 RETURN leave.annual_quote(p_tenant,p_employee,p_employer,p_type,p_period,p_as_of,p_rates,p_source);
END $f$;
REVOKE ALL ON FUNCTION public.leave_preview_annual_entitlement(uuid,uuid,uuid,uuid,uuid,date,jsonb,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_preview_annual_entitlement(uuid,uuid,uuid,uuid,uuid,date,jsonb,text) TO authenticated;

CREATE FUNCTION public.leave_post_annual_entitlement(p_tenant uuid,p_employee uuid,p_employer uuid,p_type uuid,p_period uuid,
 p_as_of date,p_rates jsonb,p_source text,p_review_hash text,p_reason text,p_key text) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid:=leave.authorized(p_tenant,'leave_balance.adjust',true); quote jsonb; payload jsonb; prior leave.annual_calculations%ROWTYPE;
 posted jsonb; result jsonb; receipt uuid:=gen_random_uuid(); kind text;
BEGIN
 IF length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 OR length(coalesce(p_key,'')) NOT BETWEEN 1 AND 100
  OR coalesce(p_review_hash,'') !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'leave_annual_input_invalid' USING ERRCODE='22023'; END IF;
 PERFORM 1 FROM people.employees WHERE tenant_id=p_tenant AND id=p_employee FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'leave_employee_unavailable' USING ERRCODE='P0002'; END IF;
 PERFORM 1 FROM people.employments WHERE tenant_id=p_tenant AND employee_id=p_employee ORDER BY id FOR UPDATE;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer FOR UPDATE;
 PERFORM leave.authorized(p_tenant,'leave_balance.adjust',true);
 payload:=jsonb_build_object('employee',p_employee,'employer',p_employer,'type',p_type,'period',p_period,
  'as_of',p_as_of,'rates',p_rates,'source',p_source,'review_hash',p_review_hash,'reason',btrim(p_reason));
 SELECT * INTO prior FROM leave.annual_calculations WHERE tenant_id=p_tenant AND actor_user_id=actor AND operation_key=p_key;
 IF FOUND THEN
  IF prior.payload IS DISTINCT FROM payload THEN RAISE EXCEPTION 'leave_idempotency_conflict' USING ERRCODE='23505'; END IF;
  RETURN prior.result||jsonb_build_object('replay',true);
 END IF;
 quote:=leave.annual_quote(p_tenant,p_employee,p_employer,p_type,p_period,p_as_of,p_rates,p_source);
 IF quote->>'review_hash'<>p_review_hash THEN RAISE EXCEPTION 'leave_annual_review_conflict' USING ERRCODE='PT409'; END IF;
 IF NOT (quote->>'eligible')::boolean THEN RAISE EXCEPTION 'leave_annual_not_eligible' USING ERRCODE='23514'; END IF;
 IF (quote->>'delta')::numeric>0 THEN
  kind:=CASE WHEN (quote->>'already_granted')::numeric=0 THEN 'annual_grant' ELSE 'adjustment' END;
  posted:=public.leave_post_balance(p_tenant,p_employee,p_employer,p_type,p_period,kind,(quote->>'delta')::numeric,
   (quote->>'type_version')::uuid,'annual:'||receipt::text,'leave.annual_calculation:'||receipt::text,btrim(p_reason));
 END IF;
 result:=jsonb_build_object('state',CASE WHEN posted IS NULL THEN 'up_to_date' ELSE 'posted' END,
  'calculation_id',receipt,'account_id',posted->'account_id','entry_id',posted->'entry_id','quote',quote,'replay',false);
 INSERT INTO leave.annual_calculations(tenant_id,id,employee_id,employer_entity_id,leave_type_id,year_period_id,
  actor_user_id,operation_key,payload,result,granted_total) VALUES(p_tenant,receipt,p_employee,p_employer,p_type,p_period,
  actor,p_key,payload,result,(quote->>'target_total')::numeric);
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION public.leave_post_annual_entitlement(uuid,uuid,uuid,uuid,uuid,date,jsonb,text,text,text,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.leave_post_annual_entitlement(uuid,uuid,uuid,uuid,uuid,date,jsonb,text,text,text,text) TO authenticated;
