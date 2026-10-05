-- Payroll owns civil-date calendars; no money, source consumption or financial lock in Slice 1.
CREATE SCHEMA payroll;
REVOKE ALL ON SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE payroll.calendar_heads(
 tenant_id uuid NOT NULL, employer_id uuid NOT NULL, revision integer NOT NULL DEFAULT 0,
 PRIMARY KEY(tenant_id,employer_id), FOREIGN KEY(tenant_id,employer_id) REFERENCES platform_core.tenant_legal_entities(tenant_id,id));
CREATE TABLE payroll.calendar_versions(
 tenant_id uuid NOT NULL, employer_id uuid NOT NULL,id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),
 revision integer NOT NULL, effective_from date NOT NULL,effective_until date,
 cutoff_day integer CHECK(cutoff_day BETWEEN 1 AND 31),payment_day integer NOT NULL CHECK(payment_day BETWEEN 1 AND 31),
 payment_month text NOT NULL CHECK(payment_month IN('ending','following')), timezone text NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),reason text NOT NULL,
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,employer_id,revision),UNIQUE(tenant_id,employer_id,id),
 FOREIGN KEY(tenant_id,employer_id) REFERENCES payroll.calendar_heads(tenant_id,employer_id),
 CHECK(effective_until IS NULL OR effective_until>effective_from),
 EXCLUDE USING gist(tenant_id WITH =,employer_id WITH =,daterange(effective_from,effective_until,'[)') WITH &&));
CREATE TABLE payroll.periods(
 tenant_id uuid NOT NULL,employer_id uuid NOT NULL,id uuid NOT NULL DEFAULT pg_catalog.gen_random_uuid(),calendar_version_id uuid NOT NULL,
 starts_on date NOT NULL,ends_on date NOT NULL,payment_on date NOT NULL,timezone text NOT NULL,label text NOT NULL,is_transition boolean NOT NULL,
 created_by uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,id),UNIQUE(tenant_id,employer_id,starts_on),CHECK(ends_on>=starts_on AND payment_on>=ends_on),
 FOREIGN KEY(tenant_id,employer_id,calendar_version_id) REFERENCES payroll.calendar_versions(tenant_id,employer_id,id),
 EXCLUDE USING gist(tenant_id WITH =,employer_id WITH =,daterange(starts_on,ends_on,'[]') WITH &&));
CREATE TABLE payroll.audit_events(id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),tenant_id uuid NOT NULL,employer_id uuid NOT NULL,
 actor_id uuid NOT NULL REFERENCES auth.users(id),action text NOT NULL,details jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE payroll.command_receipts(tenant_id uuid NOT NULL,actor_id uuid NOT NULL,attempt_key uuid NOT NULL,intent jsonb NOT NULL,result jsonb NOT NULL,
 PRIMARY KEY(tenant_id,actor_id,attempt_key));
CREATE FUNCTION payroll.immutable() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $f$ BEGIN RAISE EXCEPTION 'payroll_immutable' USING ERRCODE='55000'; END $f$;
CREATE TRIGGER payroll_period_immutable BEFORE UPDATE OR DELETE ON payroll.periods FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
CREATE TRIGGER payroll_audit_immutable BEFORE UPDATE OR DELETE ON payroll.audit_events FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
CREATE TRIGGER payroll_receipt_immutable BEFORE UPDATE OR DELETE ON payroll.command_receipts FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
ALTER TABLE payroll.calendar_heads ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.calendar_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.command_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION payroll.authorized(p_tenant uuid,p_permission text,p_write boolean DEFAULT false) RETURNS uuid
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid(); BEGIN
 IF a IS NULL OR NOT platform_private.has_tenant_permission(p_tenant,a,p_permission) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 IF p_write AND NOT platform_private.tenant_capability_is_enabled(p_tenant,'hr.payroll',pg_catalog.clock_timestamp()) THEN RAISE EXCEPTION 'payroll_disabled' USING ERRCODE='55000'; END IF;
 RETURN a;
END $f$;
CREATE FUNCTION payroll.clamped_day(p_month date,p_day integer) RETURNS date LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
 SELECT (pg_catalog.date_trunc('month',p_month)::date + (LEAST(COALESCE(p_day,31),EXTRACT(day FROM(pg_catalog.date_trunc('month',p_month)+interval '1 month - 1 day'))::int)-1))::date
$f$;
CREATE FUNCTION payroll.preview_dates(p_start date,p_cutoff integer,p_payment integer,p_month text,p_timezone text) RETURNS jsonb
 LANGUAGE plpgsql STABLE SET search_path='' AS $f$
DECLARE e date; pay date; BEGIN
 IF p_start IS NULL OR (p_cutoff IS NOT NULL AND p_cutoff NOT BETWEEN 1 AND 31) OR p_payment IS NULL OR p_payment NOT BETWEEN 1 AND 31 OR p_month IS NULL OR p_month NOT IN('ending','following') OR p_timezone IS NULL OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 IF p_month='ending' AND p_payment<COALESCE(p_cutoff,31) THEN RAISE EXCEPTION 'payroll_payment_before_end' USING ERRCODE='22023'; END IF;
 e:=payroll.clamped_day(p_start,p_cutoff);
 IF e<p_start THEN e:=payroll.clamped_day((pg_catalog.date_trunc('month',p_start)+interval '1 month')::date,p_cutoff); END IF;
 pay:=payroll.clamped_day((pg_catalog.date_trunc('month',e)+CASE WHEN p_month='following' THEN interval '1 month' ELSE interval '0 month' END)::date,p_payment);
 IF pay<e THEN RAISE EXCEPTION 'payroll_payment_before_end' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('starts_on',p_start,'ends_on',e,'payment_on',pay,'timezone',p_timezone,'label',pg_catalog.to_char(e,'YYYY-MM'));
END $f$;
CREATE FUNCTION public.payroll_access_snapshot(p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid:=auth.uid(); BEGIN
 IF a IS NULL OR NOT (platform_private.has_tenant_permission(p_tenant,a,'payroll.view') OR platform_private.has_tenant_permission(p_tenant,a,'payroll_config.manage')) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 RETURN pg_catalog.jsonb_build_object('can_view',platform_private.has_tenant_permission(p_tenant,a,'payroll.view'),'can_manage',platform_private.has_tenant_permission(p_tenant,a,'payroll_config.manage'),'enabled',platform_private.tenant_capability_is_enabled(p_tenant,'hr.payroll',pg_catalog.clock_timestamp()));
END $f$;
CREATE FUNCTION public.payroll_employers(p_tenant uuid,p_query text DEFAULT '',p_after_name text DEFAULT NULL,p_after_id uuid DEFAULT NULL,p_limit integer DEFAULT 30) RETURNS jsonb
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$ BEGIN
 PERFORM public.payroll_access_snapshot(p_tenant);
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 50 OR p_query IS NULL OR length(p_query)>120 OR (p_after_name IS NULL)<>(p_after_id IS NULL) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 RETURN pg_catalog.jsonb_build_object('items',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('id',e.id,'name',e.name) ORDER BY e.name,e.id) FROM(SELECT id,display_name AS name FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND is_active AND display_name ILIKE '%'||p_query||'%' AND (p_after_id IS NULL OR (display_name,id)>(p_after_name,p_after_id)) ORDER BY display_name,id LIMIT p_limit) e),'[]'::jsonb),'unique_employer', (SELECT CASE WHEN count(*)=1 THEN min(id::text) ELSE NULL END FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND is_active));
END $f$;
CREATE FUNCTION payroll.lock_scope(p_tenant uuid,p_employer uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$ BEGIN
 -- Same Tenant authority key as entitlement/membership writers; then Employer, then head.
 PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant::text,90427));
 PERFORM 1 FROM platform_core.tenants WHERE id=p_tenant FOR SHARE;
 PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_memberships WHERE tenant_id=p_tenant AND user_id=auth.uid() FOR SHARE;
 PERFORM 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_employer_unavailable' USING ERRCODE='42501'; END IF;
END $f$;
CREATE FUNCTION public.payroll_calendar_preview(p_tenant uuid,p_employer uuid,p_start date,p_cutoff integer,p_payment integer,p_month text,p_timezone text) RETURNS jsonb
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE last_end date; rev integer; result jsonb; BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true);
 IF NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 SELECT max(ends_on) INTO last_end FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer;
 SELECT revision INTO rev FROM payroll.calendar_heads WHERE tenant_id=p_tenant AND employer_id=p_employer;
 IF last_end IS NOT NULL AND p_start<>last_end+1 THEN RAISE EXCEPTION 'payroll_transition_required' USING ERRCODE='22023'; END IF;
 IF COALESCE(rev,0)>0 AND p_start<=(pg_catalog.clock_timestamp() AT TIME ZONE p_timezone)::date THEN RAISE EXCEPTION 'payroll_future_required' USING ERRCODE='22023'; END IF;
 result:=payroll.preview_dates(p_start,p_cutoff,p_payment,p_month,p_timezone);
 RETURN result||pg_catalog.jsonb_build_object('revision',COALESCE(rev,0),'last_generated_end',last_end,'is_transition',last_end IS NOT NULL);
END $f$;
CREATE FUNCTION public.payroll_save_calendar(p_tenant uuid,p_employer uuid,p_start date,p_cutoff integer,p_payment integer,p_month text,p_timezone text,p_expected integer,p_attempt uuid,p_reviewed jsonb,p_reason text) RETURNS jsonb
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid; rev integer; quote jsonb; intent jsonb; receipt payroll.command_receipts%ROWTYPE; v uuid; period uuid; result jsonb; BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true);
 PERFORM payroll.lock_scope(p_tenant,p_employer);
 a:=payroll.authorized(p_tenant,'payroll_config.manage',true);
 IF p_attempt IS NULL OR p_expected IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 3 AND 500 OR p_reviewed IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 intent:=pg_catalog.jsonb_build_object('operation','calendar_save','employer',p_employer,'start',p_start,'cutoff',p_cutoff,'payment',p_payment,'month',p_month,'timezone',p_timezone,'expected',p_expected,'reviewed',p_reviewed,'reason',btrim(p_reason));
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 INSERT INTO payroll.calendar_heads(tenant_id,employer_id) VALUES(p_tenant,p_employer) ON CONFLICT DO NOTHING;
 SELECT revision INTO rev FROM payroll.calendar_heads WHERE tenant_id=p_tenant AND employer_id=p_employer FOR UPDATE;
 IF rev<>p_expected THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
 quote:=public.payroll_calendar_preview(p_tenant,p_employer,p_start,p_cutoff,p_payment,p_month,p_timezone);
 IF quote<>p_reviewed THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
 IF EXISTS(SELECT 1 FROM payroll.calendar_versions WHERE tenant_id=p_tenant AND employer_id=p_employer AND effective_from>=p_start) THEN RAISE EXCEPTION 'payroll_future_version_exists' USING ERRCODE='PT409'; END IF;
 UPDATE payroll.calendar_versions SET effective_until=p_start WHERE tenant_id=p_tenant AND employer_id=p_employer AND effective_until IS NULL;
 INSERT INTO payroll.calendar_versions(tenant_id,employer_id,revision,effective_from,cutoff_day,payment_day,payment_month,timezone,created_by,reason) VALUES(p_tenant,p_employer,rev+1,p_start,p_cutoff,p_payment,p_month,p_timezone,a,btrim(p_reason)) RETURNING id INTO v;
 INSERT INTO payroll.periods(tenant_id,employer_id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES(p_tenant,p_employer,v,p_start,(quote->>'ends_on')::date,(quote->>'payment_on')::date,p_timezone,quote->>'label',(quote->>'is_transition')::boolean,a) RETURNING id INTO period;
 UPDATE payroll.calendar_heads SET revision=rev+1 WHERE tenant_id=p_tenant AND employer_id=p_employer;
 result:=pg_catalog.jsonb_build_object('revision',rev+1,'period_id',period,'dates',quote);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'calendar_saved',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true);
 RETURN result;
END $f$;
CREATE FUNCTION public.payroll_generate_next_period(p_tenant uuid,p_employer uuid,p_expected integer,p_attempt uuid,p_reviewed jsonb) RETURNS jsonb
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE a uuid; rev integer; start_day date; v payroll.calendar_versions%ROWTYPE; quote jsonb; result jsonb; intent jsonb; receipt payroll.command_receipts%ROWTYPE; period uuid; BEGIN
 PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true); PERFORM payroll.lock_scope(p_tenant,p_employer); a:=payroll.authorized(p_tenant,'payroll_config.manage',true);
 IF p_attempt IS NULL OR p_expected IS NULL OR p_reviewed IS NULL THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 intent:=pg_catalog.jsonb_build_object('operation','generate','employer',p_employer,'expected',p_expected,'reviewed',p_reviewed);
 SELECT * INTO receipt FROM payroll.command_receipts WHERE tenant_id=p_tenant AND actor_id=a AND attempt_key=p_attempt;
 IF FOUND THEN IF receipt.intent<>intent THEN RAISE EXCEPTION 'payroll_attempt_conflict' USING ERRCODE='PT409'; END IF; RETURN receipt.result; END IF;
 SELECT revision INTO rev FROM payroll.calendar_heads WHERE tenant_id=p_tenant AND employer_id=p_employer FOR UPDATE;
 IF rev IS NULL OR rev<>p_expected THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
 SELECT max(ends_on)+1 INTO start_day FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer;
 SELECT * INTO v FROM payroll.calendar_versions WHERE tenant_id=p_tenant AND employer_id=p_employer AND effective_from<=start_day AND (effective_until IS NULL OR effective_until>start_day);
 IF NOT FOUND THEN RAISE EXCEPTION 'payroll_calendar_missing' USING ERRCODE='55000'; END IF;
 quote:=payroll.preview_dates(start_day,v.cutoff_day,v.payment_day,v.payment_month,v.timezone);
 IF quote<>p_reviewed THEN RAISE EXCEPTION 'payroll_stale' USING ERRCODE='PT409'; END IF;
 INSERT INTO payroll.periods(tenant_id,employer_id,calendar_version_id,starts_on,ends_on,payment_on,timezone,label,is_transition,created_by) VALUES(p_tenant,p_employer,v.id,start_day,(quote->>'ends_on')::date,(quote->>'payment_on')::date,v.timezone,quote->>'label',false,a) RETURNING id INTO period;
 UPDATE payroll.calendar_heads SET revision=rev+1 WHERE tenant_id=p_tenant AND employer_id=p_employer;
 result:=pg_catalog.jsonb_build_object('period_id',period,'revision',rev+1);
 INSERT INTO payroll.audit_events(tenant_id,employer_id,actor_id,action,details) VALUES(p_tenant,p_employer,a,'period_generated',intent||result);
 INSERT INTO payroll.command_receipts VALUES(p_tenant,a,p_attempt,intent,result);
 PERFORM payroll.authorized(p_tenant,'payroll_config.manage',true); RETURN result;
END $f$;
CREATE FUNCTION public.payroll_workspace(p_tenant uuid,p_employer uuid,p_before date DEFAULT NULL,p_limit integer DEFAULT 12) RETURNS jsonb
 LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path='' AS $f$
DECLARE access jsonb; result jsonb; next_start date; v payroll.calendar_versions%ROWTYPE; BEGIN
 access:=public.payroll_access_snapshot(p_tenant);
 IF NOT (access->>'can_view')::boolean AND NOT (access->>'can_manage')::boolean THEN RAISE EXCEPTION 'payroll_forbidden' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 24 OR NOT EXISTS(SELECT 1 FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer AND is_active) THEN RAISE EXCEPTION 'payroll_invalid' USING ERRCODE='22023'; END IF;
 SELECT max(ends_on)+1 INTO next_start FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer;
 SELECT * INTO v FROM payroll.calendar_versions WHERE tenant_id=p_tenant AND employer_id=p_employer AND effective_from<=COALESCE(next_start,(pg_catalog.clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date) AND (effective_until IS NULL OR effective_until>COALESCE(next_start,(pg_catalog.clock_timestamp() AT TIME ZONE 'Africa/Cairo')::date));
 result:=pg_catalog.jsonb_build_object('access',access,'employer_name',(SELECT display_name FROM platform_core.tenant_legal_entities WHERE tenant_id=p_tenant AND id=p_employer),'revision',COALESCE((SELECT revision FROM payroll.calendar_heads WHERE tenant_id=p_tenant AND employer_id=p_employer),0),'next_start',next_start,
 'versions',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x) ORDER BY x.effective_from DESC) FROM(SELECT revision,effective_from,effective_until,cutoff_day,payment_day,payment_month,timezone FROM payroll.calendar_versions WHERE tenant_id=p_tenant AND employer_id=p_employer ORDER BY effective_from DESC LIMIT 24)x),'[]'::jsonb),
 'periods',COALESCE((SELECT pg_catalog.jsonb_agg(pg_catalog.to_jsonb(x) ORDER BY x.starts_on DESC) FROM(SELECT starts_on,ends_on,payment_on,timezone,label,is_transition FROM payroll.periods WHERE tenant_id=p_tenant AND employer_id=p_employer AND(p_before IS NULL OR starts_on<p_before) ORDER BY starts_on DESC LIMIT p_limit)x),'[]'::jsonb));
 IF v.id IS NOT NULL AND next_start IS NOT NULL THEN result:=result||pg_catalog.jsonb_build_object('next_preview',payroll.preview_dates(next_start,v.cutoff_day,v.payment_day,v.payment_month,v.timezone)); END IF;
 RETURN result||pg_catalog.jsonb_build_object('readiness',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object('source','calendar','state',CASE WHEN v.id IS NULL THEN 'block' ELSE 'ready' END),pg_catalog.jsonb_build_object('source','people','state','not_checked'),pg_catalog.jsonb_build_object('source','time','state','not_checked'),pg_catalog.jsonb_build_object('source','leave','state','not_checked'),pg_catalog.jsonb_build_object('source','finance','state','not_checked'),pg_catalog.jsonb_build_object('source','calculation','state','block')));
END $f$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA payroll FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.payroll_access_snapshot(uuid),public.payroll_employers(uuid,text,text,uuid,integer),public.payroll_workspace(uuid,uuid,date,integer),public.payroll_calendar_preview(uuid,uuid,date,integer,integer,text,text),public.payroll_save_calendar(uuid,uuid,date,integer,integer,text,text,integer,uuid,jsonb,text),public.payroll_generate_next_period(uuid,uuid,integer,uuid,jsonb) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.payroll_access_snapshot(uuid),public.payroll_employers(uuid,text,text,uuid,integer),public.payroll_workspace(uuid,uuid,date,integer),public.payroll_calendar_preview(uuid,uuid,date,integer,integer,text,text),public.payroll_save_calendar(uuid,uuid,date,integer,integer,text,text,integer,uuid,jsonb,text),public.payroll_generate_next_period(uuid,uuid,integer,uuid,jsonb) TO authenticated;
-- Extend the supported bounded role catalog without changing any existing bundle snapshot.
DO $f$
DECLARE definition text;
BEGIN
 definition:=pg_catalog.pg_get_functiondef('platform_private.people_role_bundle_catalog()'::regprocedure);
 IF definition NOT LIKE '%leave.balance.manager.v1%' OR definition LIKE '%payroll.reader.v1%' THEN RAISE EXCEPTION 'unexpected_role_catalog'; END IF;
 definition:=replace(definition,'''leave.balance.manager.v1''::text,ARRAY[''leave.view'',''leave_balance.adjust'']::text[])','''leave.balance.manager.v1''::text,ARRAY[''leave.view'',''leave_balance.adjust'']::text[]),
 (''payroll.reader.v1''::text,ARRAY[''payroll.view'']::text[]),
 (''payroll.preparer.v1''::text,ARRAY[''payroll.view'',''payroll.prepare'']::text[]),
 (''payroll.calendar.manager.v1''::text,ARRAY[''payroll.view'',''payroll_config.manage'']::text[])');
 EXECUTE definition;
 definition:=pg_catalog.pg_get_functiondef('public.set_tenant_member_people_bundles(uuid,uuid,text[])'::regprocedure);
 IF definition NOT LIKE '%cardinality(p_bundle_keys) > 14%' THEN RAISE EXCEPTION 'unexpected_role_bundle_limit'; END IF;
 EXECUTE replace(definition,'cardinality(p_bundle_keys) > 14','cardinality(p_bundle_keys) > 17');
END $f$;
