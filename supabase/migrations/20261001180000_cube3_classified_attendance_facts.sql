CREATE TABLE "time".classification_evidence (
    tenant_id uuid NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    work_instance_id uuid NOT NULL,
    interpretation_id uuid NOT NULL,
    interpretation_version integer NOT NULL,
    plan jsonb NOT NULL CHECK (jsonb_typeof(plan)='object'),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, interpretation_id),
    FOREIGN KEY (tenant_id) REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
    FOREIGN KEY (tenant_id, work_instance_id) REFERENCES "time".work_instances(tenant_id, id) ON DELETE RESTRICT
);
CREATE TRIGGER classification_evidence_append_only BEFORE DELETE OR UPDATE ON "time".classification_evidence FOR EACH ROW EXECUTE FUNCTION "time".prevent_attendance_mutation();

REVOKE ALL ON TABLE "time".classification_evidence FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE "time".classification_evidence ENABLE ROW LEVEL SECURITY;

ALTER TABLE "time".interpretations ADD CONSTRAINT interpretations_q_identity_key UNIQUE (tenant_id, id, work_instance_id, version);
ALTER TABLE "time".classification_evidence ADD CONSTRAINT classification_evidence_q_fk FOREIGN KEY (tenant_id, interpretation_id, work_instance_id, interpretation_version) REFERENCES "time".interpretations(tenant_id, id, work_instance_id, version) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE "time".classification_operations (
    tenant_id uuid NOT NULL,
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    actor_user_id uuid NOT NULL,
    idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) BETWEEN 1 AND 120),
    action_intent_hash text NOT NULL CHECK (action_intent_hash ~ '^[a-f0-9]{64}$'),
    is_correction boolean NOT NULL,
    reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 3 AND 500),
    expected_tokens jsonb NOT NULL CHECK (jsonb_typeof(expected_tokens)='object'),
    result jsonb NOT NULL CHECK (jsonb_typeof(result)='object'),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id),
    UNIQUE (tenant_id, actor_user_id, idempotency_key),
    FOREIGN KEY (tenant_id) REFERENCES platform_core.tenants(id) ON DELETE RESTRICT,
    FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT
);
CREATE TRIGGER classification_operations_append_only BEFORE DELETE OR UPDATE ON "time".classification_operations FOR EACH ROW EXECUTE FUNCTION "time".prevent_attendance_mutation();

REVOKE ALL ON TABLE "time".classification_operations FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE "time".classification_operations ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION "time".classified_attendance_fact_payload(p_wi "time".work_instances, p_plan jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_input jsonb := p_plan->'input';
  v_class jsonb := p_plan->'classification';
  v_obs jsonb := v_class->'observations';
  v_absence numeric;
  v_leave numeric;
  v_worked integer;
BEGIN
  v_absence := (v_class->>'absence_units')::numeric;
  v_leave := (v_class->>'leave_units')::numeric;

  IF (v_obs->>'worked_minutes') IS NULL AND (v_obs->>'first_in') IS NULL THEN
    v_worked := 0;
  ELSE
    v_worked := (v_obs->>'worked_minutes')::integer;
  END IF;

  RETURN jsonb_build_object(
    'contract_version', 2,
    'outcome', v_class->>'kind',
    'employee_id', p_wi.employee_id,
    'employment_id', p_wi.employment_id,
    'employer_entity_id', (v_input->>'employer_id')::uuid,
    'operational_date', p_wi.operational_date,
    'assignment_id', p_wi.assignment_id,
    'site_id', p_wi.site_id,
    'timezone_name', p_wi.timezone_name,
    'policy_template_id', p_wi.policy_template_id,
    'policy_version', p_wi.policy_version,
    'absence_units', v_absence,
    'leave_units', v_leave,
    'leave_sources', COALESCE(v_class->'leave_sources', '[]'::jsonb),
    'classification', jsonb_build_object(
      'version', 1,
      'kind', v_class->>'kind',
      'diagnostics', v_class->'diagnostics',
      'context_hash', p_plan->>'context_hash'
    ),
    'observations', v_obs,
    'input_fingerprint', p_plan->>'input_fingerprint',
    'first_in', v_obs->'first_in',
    'last_out', v_obs->'last_out',
    'gross_worked_minutes', v_obs->'gross_worked_minutes',
    'worked_minutes', v_worked,
    'scheduled_break_minutes', v_obs->'scheduled_break_minutes',
    'applied_break_minutes', v_obs->'applied_break_minutes',
    'late_minutes', v_obs->'late_minutes',
    'early_leave_minutes', v_obs->'early_leave_minutes',
    'expected_start', p_wi.expected_start,
    'expected_end', p_wi.expected_end,
    'schedule_kind', p_wi.schedule_kind,
    'required_minutes', p_wi.required_minutes,
    'interpretation_exception', v_obs->'exception_code'
  );
END;
$$;
REVOKE ALL ON FUNCTION "time".classified_attendance_fact_payload FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION "time".attendance_classification_input(p_tenant_id uuid, p_work_instance_id uuid, p_as_of timestamp with time zone)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
    v_wi "time".work_instances%ROWTYPE;
    v_policy "time".work_policy_versions%ROWTYPE;
    v_emp people.employments%ROWTYPE;
    v_punches jsonb;
    v_context jsonb;
    v_fingerprint text;
    v_latest_q record;
    v_latest_fact record;
    v_class jsonb;
    v_input jsonb;
    v_plan jsonb;
BEGIN
    SELECT * INTO v_wi FROM "time".work_instances WHERE tenant_id = p_tenant_id AND id = p_work_instance_id;
    IF NOT FOUND THEN RETURN NULL; END IF;

    SELECT * INTO v_emp FROM people.employments WHERE tenant_id = p_tenant_id AND id = v_wi.employment_id;
    IF NOT FOUND OR v_emp.employee_id != v_wi.employee_id THEN RETURN NULL; END IF;

    SELECT * INTO v_policy FROM "time".work_policy_versions
    WHERE tenant_id = p_tenant_id AND template_id = v_wi.policy_template_id AND version = v_wi.policy_version;

    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'direction', p.direction,
        'happened_at', p.happened_at
      ) ORDER BY p.id
    ), '[]'::jsonb) INTO v_punches
    FROM (
        SELECT
            mp.id,
            COALESCE(pc.new_direction, mp.direction) AS direction,
            COALESCE(pc.new_happened_at, mp.happened_at) AS happened_at
        FROM "time".manual_punches mp
        LEFT JOIN LATERAL (
            SELECT action, new_direction, new_happened_at
            FROM "time".punch_corrections
            WHERE tenant_id = p_tenant_id AND punch_id = mp.id
            ORDER BY created_at DESC, id DESC LIMIT 1
        ) pc ON pc.action = 'replace'
        WHERE mp.tenant_id = p_tenant_id AND mp.work_instance_id = p_work_instance_id
          AND NOT EXISTS (
              SELECT 1 FROM "time".punch_corrections exc
              WHERE exc.tenant_id = p_tenant_id AND exc.punch_id = mp.id AND exc.action = 'exclude'
          )
    ) p;

    v_context := platform_private.approved_leave_classification_context(p_tenant_id, p_work_instance_id);
    v_fingerprint := "time".work_instance_interpretation_fingerprint(p_tenant_id, p_work_instance_id);

    v_input := jsonb_build_object(
        'instance', to_jsonb(v_wi),
        'policy', CASE WHEN v_policy.template_id IS NOT NULL THEN to_jsonb(v_policy) ELSE NULL END,
        'punches', v_punches,
        'context', v_context,
        'employer_id', v_emp.employer_entity_id,
        'as_of', p_as_of
    );

    IF v_policy.template_id IS NULL THEN
      RAISE EXCEPTION 'attendance_frozen_policy_missing' USING ERRCODE='P0002';
    END IF;

    v_class := "time".classify_attendance_values(
        to_jsonb(v_wi),
        v_input->'policy',
        v_punches,
        v_context,
        v_emp.employer_entity_id,
        p_as_of
    );

    SELECT id, version INTO v_latest_q FROM "time".interpretations
    WHERE tenant_id = p_tenant_id AND work_instance_id = p_work_instance_id
    ORDER BY version DESC LIMIT 1;

    SELECT id, version INTO v_latest_fact FROM "time".attendance_facts
    WHERE tenant_id = p_tenant_id AND work_instance_id = p_work_instance_id
    ORDER BY version DESC LIMIT 1;

    v_plan := jsonb_build_object(
        'input', v_input,
        'classification', v_class,
        'expected_q', CASE WHEN v_latest_q.id IS NOT NULL THEN jsonb_build_object('id', v_latest_q.id, 'version', v_latest_q.version) ELSE NULL END,
        'expected_fact', CASE WHEN v_latest_fact.id IS NOT NULL THEN jsonb_build_object('id', v_latest_fact.id, 'version', v_latest_fact.version) ELSE NULL END,
        'input_fingerprint', v_fingerprint,
        'context_hash', v_class->>'context_hash'
    );

    RETURN jsonb_build_object(
        'plan', v_plan,
        'plan_hash', pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to((v_plan #- '{input,as_of}')::text, 'UTF8')), 'hex')
    );
END;
$$;
REVOKE ALL ON FUNCTION "time".attendance_classification_input FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION "time".validate_attendance_fact_contract()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_evid "time".classification_evidence%ROWTYPE;
  v_q "time".interpretations%ROWTYPE;
  v_latest_fact "time".attendance_facts%ROWTYPE;
  v_wi "time".work_instances%ROWTYPE;
  v_recomputed_class jsonb;
  v_payload jsonb;
  v_absence numeric;
  v_leave numeric;
  v_source_sum numeric;
BEGIN
  IF jsonb_typeof(NEW.fact) = 'object' AND NEW.fact->>'contract_version' = '2' THEN
    SELECT * INTO v_wi FROM "time".work_instances WHERE tenant_id = NEW.tenant_id AND id = NEW.work_instance_id;

    SELECT * INTO v_q FROM "time".interpretations WHERE tenant_id = NEW.tenant_id AND id = NEW.interpretation_id;
    IF NOT FOUND OR v_q.work_instance_id IS DISTINCT FROM NEW.work_instance_id THEN
      RAISE EXCEPTION 'invalid_interpretation' USING ERRCODE='23514';
    END IF;

    SELECT * INTO v_evid FROM "time".classification_evidence WHERE tenant_id = NEW.tenant_id AND interpretation_id = v_q.id;
    IF NOT FOUND OR v_evid.work_instance_id IS DISTINCT FROM NEW.work_instance_id OR v_evid.interpretation_version IS DISTINCT FROM v_q.version THEN
      RAISE EXCEPTION 'missing_evidence' USING ERRCODE='23514';
    END IF;

    v_recomputed_class := "time".classify_attendance_values(
        to_jsonb(v_wi),
        v_evid.plan->'input'->'policy',
        v_evid.plan->'input'->'punches',
        v_evid.plan->'input'->'context',
        (v_evid.plan->'input'->>'employer_id')::uuid,
        (v_evid.plan->'input'->>'as_of')::timestamp with time zone
    );

    IF v_evid.plan->'classification' IS DISTINCT FROM v_recomputed_class THEN
      RAISE EXCEPTION 'evidence_classification_mismatch' USING ERRCODE='23514';
    END IF;

    IF v_recomputed_class->>'kind' IS NULL OR v_recomputed_class->>'kind' NOT IN ('absence', 'leave_covered')
       OR (v_recomputed_class->>'approval_eligible')::boolean IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'invalid_kind_or_ineligible' USING ERRCODE='23514';
    END IF;

    v_absence := (v_recomputed_class->>'absence_units')::numeric;
    v_leave := (v_recomputed_class->>'leave_units')::numeric;

    IF v_absence IS DISTINCT FROM 0 AND v_absence IS DISTINCT FROM 0.5 AND v_absence IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION 'invalid_absence_units' USING ERRCODE='23514';
    END IF;
    IF v_leave IS DISTINCT FROM 0 AND v_leave IS DISTINCT FROM 0.5 AND v_leave IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION 'invalid_leave_units' USING ERRCODE='23514';
    END IF;

    SELECT COALESCE(SUM((s->>'units')::numeric), 0) INTO v_source_sum FROM jsonb_array_elements(v_recomputed_class->'leave_sources') s;
    IF v_source_sum IS DISTINCT FROM v_leave THEN
      RAISE EXCEPTION 'source_units_mismatch' USING ERRCODE='23514';
    END IF;
    IF v_absence+v_leave<>1 OR (v_recomputed_class->>'kind'='leave_covered' AND (v_leave<>1 OR v_absence<>0))
       OR (v_recomputed_class->>'kind'='absence' AND v_absence=0) THEN
      RAISE EXCEPTION 'nominal_coverage_mismatch' USING ERRCODE='23514';
    END IF;

    IF v_evid.plan->>'context_hash' IS DISTINCT FROM v_recomputed_class->>'context_hash' THEN
      RAISE EXCEPTION 'context_hash_mismatch' USING ERRCODE='23514';
    END IF;
    IF v_evid.plan->>'input_fingerprint' IS NULL THEN
      RAISE EXCEPTION 'missing_fingerprint' USING ERRCODE='23514';
    END IF;

    SELECT * INTO v_latest_fact FROM "time".attendance_facts
      WHERE tenant_id=NEW.tenant_id AND work_instance_id=NEW.work_instance_id ORDER BY version DESC LIMIT 1;
    IF NEW.version IS DISTINCT FROM coalesce(v_latest_fact.version,0)+1
       OR NEW.corrects_fact_id IS DISTINCT FROM v_latest_fact.id THEN
      RAISE EXCEPTION 'invalid_predecessor' USING ERRCODE='23514';
    END IF;
    IF (SELECT id FROM "time".interpretations WHERE tenant_id=NEW.tenant_id AND work_instance_id=NEW.work_instance_id ORDER BY version DESC LIMIT 1)
         IS DISTINCT FROM NEW.interpretation_id
       OR EXISTS(SELECT 1 FROM "time".attendance_facts WHERE tenant_id=NEW.tenant_id AND interpretation_id=NEW.interpretation_id)
       OR v_q.input_fingerprint IS DISTINCT FROM v_evid.plan->>'input_fingerprint' THEN
      RAISE EXCEPTION 'classified_interpretation_not_current' USING ERRCODE='23514';
    END IF;

    v_payload := "time".classified_attendance_fact_payload(v_wi, v_evid.plan);
    IF NEW.fact IS DISTINCT FROM v_payload THEN
      RAISE EXCEPTION 'fact_payload_mismatch' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION "time".validate_attendance_fact_contract FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER validate_attendance_fact_before_insert BEFORE INSERT ON "time".attendance_facts FOR EACH ROW EXECUTE FUNCTION "time".validate_attendance_fact_contract();

CREATE OR REPLACE FUNCTION "time".snapshot_approved_leave_on_interpretation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  wi "time".work_instances%ROWTYPE;
  policy "time".work_policy_versions%ROWTYPE;
  context jsonb;
  attendance_enabled boolean;
  evid "time".classification_evidence%ROWTYPE;
  evid_context jsonb;
  limited_context jsonb;
BEGIN
  SELECT * INTO evid FROM "time".classification_evidence
  WHERE tenant_id = NEW.tenant_id AND interpretation_id = NEW.id
    AND work_instance_id = NEW.work_instance_id AND interpretation_version = NEW.version;

  IF FOUND THEN
    IF (evid.plan->'input'->'instance'->>'id')::uuid IS DISTINCT FROM NEW.work_instance_id
       OR (evid.plan->'input'->'instance'->>'tenant_id')::uuid IS DISTINCT FROM NEW.tenant_id THEN
      RAISE EXCEPTION 'evidence_wi_mismatch' USING ERRCODE='23514';
    END IF;

    evid_context := evid.plan->'input'->'context';

    SELECT COALESCE(jsonb_agg(
      elem - 'tenant_id' - 'employer_entity_id' - 'pay_effect' - 'reference_only'
    ), '[]'::jsonb) INTO limited_context
    FROM jsonb_array_elements(evid_context) AS elem;

    wi := jsonb_populate_record(NULL::"time".work_instances, evid.plan->'input'->'instance');
    policy := jsonb_populate_record(NULL::"time".work_policy_versions, evid.plan->'input'->'policy');
    attendance_enabled := true;

    NEW := "time".apply_leave_context_to_interpretation(NEW, wi, policy, limited_context, attendance_enabled);
    RETURN NEW;
  END IF;

  SELECT * INTO wi FROM "time".work_instances WHERE tenant_id=NEW.tenant_id AND id=NEW.work_instance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'attendance_instance_missing' USING ERRCODE='P0002'; END IF;
  context:=platform_private.approved_leave_context(NEW.tenant_id,NEW.work_instance_id);
  attendance_enabled:=platform_private.tenant_capability_is_enabled(NEW.tenant_id,'hr.attendance',pg_catalog.now());
  SELECT * INTO policy FROM "time".work_policy_versions v
   WHERE v.tenant_id=NEW.tenant_id AND v.template_id=wi.policy_template_id AND v.version=wi.policy_version;
  NEW:="time".apply_leave_context_to_interpretation(NEW,wi,policy,context,attendance_enabled);
  RETURN NEW;
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow
   OR numeric_value_out_of_range THEN
 NEW.leave_compatibility_state:='review_required'; NEW.state:='needs_review';
 NEW.exception_code:='leave_mapping_review_required'; NEW.owner_permission:='attendance.correct';
 RETURN NEW;
END $function$;
REVOKE ALL ON FUNCTION "time".snapshot_approved_leave_on_interpretation FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION "time".append_classified_attendance_fact(
  p_tenant_id uuid,
  p_work_instance_id uuid,
  p_plan jsonb,
  p_expected_fact_id uuid,
  p_expected_fact_version int,
  p_expected_q_id uuid,
  p_expected_q_version int,
  p_actor_user_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_wi "time".work_instances%ROWTYPE;
  v_latest_fact "time".attendance_facts%ROWTYPE;
  v_latest_q "time".interpretations%ROWTYPE;
  v_new_q_id uuid := gen_random_uuid();
  v_new_q_version int;
  v_new_fact_id uuid := gen_random_uuid();
  v_new_fact_version int;
  v_class jsonb;
  v_recomputed_class jsonb;
  v_input jsonb;
  v_obs jsonb;
  v_fact_json jsonb;
BEGIN
  SELECT * INTO v_wi FROM "time".work_instances WHERE tenant_id = p_tenant_id AND id = p_work_instance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'instance_not_found' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_latest_fact FROM "time".attendance_facts
  WHERE tenant_id = p_tenant_id AND work_instance_id = p_work_instance_id
  ORDER BY version DESC LIMIT 1;

  IF v_latest_fact.id IS DISTINCT FROM p_expected_fact_id OR v_latest_fact.version IS DISTINCT FROM p_expected_fact_version THEN
    RAISE EXCEPTION 'fact_concurrent_modification' USING ERRCODE = 'PT409';
  END IF;

  IF (p_plan->'expected_fact'->>'id')::uuid IS DISTINCT FROM p_expected_fact_id OR (p_plan->'expected_fact'->>'version')::int IS DISTINCT FROM p_expected_fact_version THEN
    RAISE EXCEPTION 'plan_fact_mismatch' USING ERRCODE = 'PT409';
  END IF;

  SELECT * INTO v_latest_q FROM "time".interpretations
  WHERE tenant_id = p_tenant_id AND work_instance_id = p_work_instance_id
  ORDER BY version DESC LIMIT 1;

  IF v_latest_q.id IS DISTINCT FROM p_expected_q_id OR v_latest_q.version IS DISTINCT FROM p_expected_q_version THEN
    RAISE EXCEPTION 'q_concurrent_modification' USING ERRCODE = 'PT409';
  END IF;

  IF (p_plan->'expected_q'->>'id')::uuid IS DISTINCT FROM p_expected_q_id OR (p_plan->'expected_q'->>'version')::int IS DISTINCT FROM p_expected_q_version THEN
    RAISE EXCEPTION 'plan_q_mismatch' USING ERRCODE = 'PT409';
  END IF;

  v_input := p_plan->'input';

  IF (to_jsonb(v_wi) - 'status') IS DISTINCT FROM ((v_input->'instance') - 'status') THEN
    RAISE EXCEPTION 'physical_wi_mismatch' USING ERRCODE = 'PT409';
  END IF;

  IF v_input->'policy' IS NOT NULL THEN
    IF (v_input->'policy'->>'tenant_id')::uuid IS DISTINCT FROM p_tenant_id OR
       (v_input->'policy'->>'template_id')::uuid IS DISTINCT FROM v_wi.policy_template_id OR
       (v_input->'policy'->>'version')::int IS DISTINCT FROM v_wi.policy_version THEN
      RAISE EXCEPTION 'physical_policy_mismatch' USING ERRCODE = 'PT409';
    END IF;
  ELSE
    RAISE EXCEPTION 'missing_policy' USING ERRCODE = '23514';
  END IF;

  IF p_plan->>'input_fingerprint' IS NULL THEN
    RAISE EXCEPTION 'missing_fingerprint' USING ERRCODE = '23514';
  END IF;

  v_class := p_plan->'classification';

  v_recomputed_class := "time".classify_attendance_values(
      to_jsonb(v_wi),
      v_input->'policy',
      v_input->'punches',
      v_input->'context',
      (v_input->>'employer_id')::uuid,
      (v_input->>'as_of')::timestamp with time zone
  );

  IF v_class IS DISTINCT FROM v_recomputed_class THEN
    RAISE EXCEPTION 'classification_mismatch' USING ERRCODE = 'PT409';
  END IF;

  IF (p_plan->>'context_hash') IS DISTINCT FROM (v_class->>'context_hash') THEN
    RAISE EXCEPTION 'context_hash_mismatch' USING ERRCODE = 'PT409';
  END IF;

  IF v_class->>'kind' IS NULL OR v_class->>'kind' NOT IN ('absence', 'leave_covered')
     OR (v_class->>'approval_eligible')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'unsupported_outcome' USING ERRCODE = '23514';
  END IF;

  v_new_q_version := COALESCE(v_latest_q.version, 0) + 1;
  v_new_fact_version := COALESCE(v_latest_fact.version, 0) + 1;

  INSERT INTO "time".classification_evidence (
    tenant_id, work_instance_id, interpretation_id, interpretation_version, plan
  ) VALUES (
    p_tenant_id, p_work_instance_id, v_new_q_id, v_new_q_version, p_plan
  );

  v_obs := v_class->'observations';

  INSERT INTO "time".interpretations (
    tenant_id, id, work_instance_id, version, state,
    first_in, last_out, worked_minutes,
    exception_code, input_fingerprint, created_by,
    owner_permission, gross_worked_minutes, late_minutes,
    early_leave_minutes, scheduled_break_minutes, applied_break_minutes,
    leave_evidence, leave_units, leave_compatibility_state
  ) VALUES (
    p_tenant_id, v_new_q_id, p_work_instance_id, v_new_q_version, v_obs->>'state',
    (v_obs->>'first_in')::timestamp with time zone,
    (v_obs->>'last_out')::timestamp with time zone,
    (v_obs->>'worked_minutes')::integer,
    v_obs->>'exception_code',
    p_plan->>'input_fingerprint',
    p_actor_user_id,
    v_obs->>'owner_permission',
    (v_obs->>'gross_worked_minutes')::integer,
    (v_obs->>'late_minutes')::integer,
    (v_obs->>'early_leave_minutes')::integer,
    (v_obs->>'scheduled_break_minutes')::integer,
    (v_obs->>'applied_break_minutes')::integer,
    '[]'::jsonb,
    0,
    'none'
  );

  v_fact_json := "time".classified_attendance_fact_payload(v_wi, p_plan);

  INSERT INTO "time".attendance_facts (
    tenant_id, id, work_instance_id, version, interpretation_id,
    corrects_fact_id, reason, fact, actor_user_id
  ) VALUES (
    p_tenant_id, v_new_fact_id, p_work_instance_id, v_new_fact_version, v_new_q_id,
    v_latest_fact.id, p_reason, v_fact_json, p_actor_user_id
  );

  UPDATE "time".work_instances
  SET status = 'approved'
  WHERE tenant_id = p_tenant_id AND id = p_work_instance_id;

  INSERT INTO "time".attendance_audit_events (
    tenant_id, actor_user_id, event_key, work_instance_id, details
  ) VALUES (
    p_tenant_id, p_actor_user_id, 'attendance_fact_classified', p_work_instance_id,
    jsonb_build_object('fact_id', v_new_fact_id, 'reason', p_reason, 'fact_version', v_new_fact_version)
  );

  RETURN jsonb_build_object(
    'fact_id', v_new_fact_id,
    'version', v_new_fact_version,
    'corrects_fact_id', v_latest_fact.id,
    'interpretation_id', v_new_q_id,
    'absence_units', (v_class->>'absence_units')::numeric,
    'leave_units', (v_class->>'leave_units')::numeric,
    'classification_version', 1,
    'state', CASE WHEN v_class->>'kind' = 'absence' THEN 'approved_absence' ELSE 'approved_leave_covered' END
  );
END;
$$;
REVOKE ALL ON FUNCTION "time".append_classified_attendance_fact FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.attendance_review_classification(p_tenant_id uuid, p_work_instance_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_plan_res jsonb;
  v_plan jsonb;
  v_has_view_leave boolean;
  v_has_admin boolean;
  v_has_attendance boolean;
  v_has_approve boolean;
  v_has_correct boolean;
  v_latest_fact record;
  v_class jsonb;
  v_perms jsonb;
  v_actor uuid := auth.uid();
BEGIN
  IF p_tenant_id IS NULL OR p_work_instance_id IS NULL OR v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501';
  END IF;

  v_has_attendance := COALESCE(platform_private.tenant_capability_is_enabled(p_tenant_id, 'hr.attendance', pg_catalog.now()), false);
  IF NOT v_has_attendance THEN RAISE EXCEPTION 'attendance_disabled' USING ERRCODE='42501'; END IF;

  v_has_approve := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'attendance.approve'), false);
  v_has_correct := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'attendance.correct'), false);
  v_has_admin := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'tenant.administer'), false);
  v_has_view_leave := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'leave.view'), false);

  IF v_has_admin THEN
    v_has_approve := true;
    v_has_correct := true;
  END IF;

  IF NOT v_has_approve THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;

  SELECT id INTO v_latest_fact FROM "time".attendance_facts
  WHERE tenant_id = p_tenant_id AND work_instance_id = p_work_instance_id
  ORDER BY version DESC LIMIT 1;

  IF v_latest_fact.id IS NOT NULL THEN
    IF NOT (v_has_approve AND v_has_correct) THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
  END IF;

  v_plan_res := "time".attendance_classification_input(p_tenant_id, p_work_instance_id, pg_catalog.now());
  IF v_plan_res IS NULL THEN RAISE EXCEPTION 'instance_not_found' USING ERRCODE='P0002'; END IF;

  v_plan := v_plan_res->'plan';
  v_class := v_plan->'classification';

  IF NOT (v_has_view_leave OR v_has_admin) THEN
    v_class := jsonb_set(
      v_class,
      '{leave_sources}',
      (SELECT COALESCE(jsonb_agg(elem - 'pay_effect'), '[]'::jsonb)
       FROM jsonb_array_elements(v_class->'leave_sources') AS elem)
    );
  END IF;

  v_perms := jsonb_build_object(
    'can_approve', v_has_approve,
    'can_correct', v_has_correct
  );

  RETURN jsonb_build_object(
    'expected_fact_id', (v_plan->'expected_fact'->>'id')::uuid,
    'expected_fact_version', (v_plan->'expected_fact'->>'version')::int,
    'expected_interpretation_id', (v_plan->'expected_q'->>'id')::uuid,
    'expected_interpretation_version', (v_plan->'expected_q'->>'version')::int,
    'input_fingerprint', v_plan->>'input_fingerprint',
    'context_hash', v_plan->>'context_hash',
    'plan_hash', v_plan_res->>'plan_hash',
    'classification', v_class,
    'permissions', v_perms
  );
END;
$$;
REVOKE ALL ON FUNCTION public.attendance_review_classification FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.attendance_review_classification TO authenticated;

CREATE OR REPLACE FUNCTION public.attendance_commit_classification(
  p_tenant_id uuid,
  p_work_instance_id uuid,
  p_expected_fact_id uuid,
  p_expected_fact_version int,
  p_expected_interpretation_id uuid,
  p_expected_interpretation_version int,
  p_expected_input_fingerprint text,
  p_expected_context_hash text,
  p_reviewed_plan_hash text,
  p_reason text,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_reason text := btrim(COALESCE(p_reason, ''));
  v_key text := btrim(COALESCE(p_idempotency_key, ''));
  v_actor uuid := auth.uid();
  v_has_approve boolean;
  v_has_correct boolean;
  v_has_admin boolean;
  v_receipt "time".classification_operations%ROWTYPE;
  v_intent_hash text;
  v_plan_res jsonb;
  v_plan jsonb;
  v_emp_id uuid;
  v_latest_fact_id uuid;
  v_is_correction boolean;
  v_append_res jsonb;
  v_intent_obj jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_work_instance_id IS NULL OR v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501';
  END IF;

  IF length(v_reason) < 3 OR length(v_reason) > 500 THEN RAISE EXCEPTION 'malformed_reason' USING ERRCODE='22023'; END IF;
  IF length(v_key) < 1 OR length(v_key) > 120 THEN RAISE EXCEPTION 'malformed_key' USING ERRCODE='22023'; END IF;
  IF (p_expected_fact_id IS NULL) IS DISTINCT FROM (p_expected_fact_version IS NULL)
     OR (p_expected_interpretation_id IS NULL) IS DISTINCT FROM (p_expected_interpretation_version IS NULL)
     OR p_expected_fact_version<=0 OR p_expected_interpretation_version<=0
     OR p_expected_input_fingerprint IS NULL OR p_expected_input_fingerprint !~ '^[a-f0-9]{32}$'
     OR p_expected_context_hash IS NULL OR p_expected_context_hash !~ '^[a-f0-9]{32}$'
     OR p_reviewed_plan_hash IS NULL OR p_reviewed_plan_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'attendance_review_tokens_invalid' USING ERRCODE='22023';
  END IF;

  v_has_approve := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'attendance.approve'), false);
  v_has_correct := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'attendance.correct'), false);
  v_has_admin := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'tenant.administer'), false);
  IF v_has_admin THEN
    v_has_approve := true;
    v_has_correct := true;
  END IF;

  IF NOT v_has_approve THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;

  IF NOT COALESCE(platform_private.tenant_capability_is_enabled(p_tenant_id, 'hr.attendance', pg_catalog.now()), false) THEN
    RAISE EXCEPTION 'attendance_disabled' USING ERRCODE='42501';
  END IF;

  SELECT employment_id INTO v_emp_id FROM "time".work_instances WHERE tenant_id = p_tenant_id AND id = p_work_instance_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'instance_not_found' USING ERRCODE='P0002'; END IF;

  PERFORM 1 FROM people.employments WHERE tenant_id = p_tenant_id AND id = v_emp_id FOR NO KEY UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'attendance_employment_missing' USING ERRCODE='P0002'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text||':'||v_actor::text||':'||v_key,187904));
  PERFORM 1 FROM "time".work_instances WHERE tenant_id = p_tenant_id AND id = p_work_instance_id FOR UPDATE;

  IF NOT COALESCE(platform_private.tenant_capability_is_enabled(p_tenant_id, 'hr.attendance', pg_catalog.now()), false) THEN
    RAISE EXCEPTION 'attendance_disabled' USING ERRCODE='42501';
  END IF;

  v_has_approve := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'attendance.approve'), false);
  v_has_correct := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'attendance.correct'), false);
  v_has_admin := COALESCE(platform_private.has_tenant_permission(p_tenant_id, v_actor, 'tenant.administer'), false);
  IF v_has_admin THEN v_has_approve := true; v_has_correct := true; END IF;

  IF NOT EXISTS (SELECT 1 FROM "time".work_instances WHERE tenant_id = p_tenant_id AND id = p_work_instance_id AND employment_id = v_emp_id) THEN
     RAISE EXCEPTION 'instance_not_found' USING ERRCODE='P0002';
  END IF;

  v_intent_obj := jsonb_build_object(
    'action', 'attendance.classification.committed',
    'tenant', p_tenant_id,
    'actor', v_actor,
    'instance', p_work_instance_id,
    'expected_fact_id', p_expected_fact_id,
    'expected_fact_version', p_expected_fact_version,
    'expected_q_id', p_expected_interpretation_id,
    'expected_q_version', p_expected_interpretation_version,
    'expected_input_fingerprint', p_expected_input_fingerprint,
    'expected_context_hash', p_expected_context_hash,
    'reviewed_plan_hash', p_reviewed_plan_hash,
    'reason', v_reason
  );

  v_intent_hash := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(v_intent_obj::text, 'UTF8')), 'hex');

  SELECT * INTO v_receipt FROM "time".classification_operations
  WHERE tenant_id = p_tenant_id AND actor_user_id = v_actor AND idempotency_key = v_key;

  IF FOUND THEN
    IF v_receipt.is_correction THEN
      IF NOT (v_has_approve AND v_has_correct) THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
    ELSE
      IF NOT v_has_approve THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
    END IF;

    IF v_receipt.action_intent_hash IS DISTINCT FROM v_intent_hash THEN
      RAISE EXCEPTION 'altered_idempotency_payload' USING ERRCODE='23505';
    END IF;

    RETURN v_receipt.result;
  END IF;

  SELECT id INTO v_latest_fact_id FROM "time".attendance_facts WHERE tenant_id = p_tenant_id AND work_instance_id = p_work_instance_id ORDER BY version DESC LIMIT 1;
  v_is_correction := (v_latest_fact_id IS NOT NULL);

  IF v_is_correction THEN
    IF NOT (v_has_approve AND v_has_correct) THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
  ELSE
    IF NOT v_has_approve THEN RAISE EXCEPTION 'unauthorized' USING ERRCODE='42501'; END IF;
  END IF;

  v_plan_res := "time".attendance_classification_input(p_tenant_id, p_work_instance_id, pg_catalog.now());
  v_plan := v_plan_res->'plan';

  IF (v_plan->'expected_fact'->>'id')::uuid IS DISTINCT FROM p_expected_fact_id OR
     (v_plan->'expected_fact'->>'version')::int IS DISTINCT FROM p_expected_fact_version OR
     (v_plan->'expected_q'->>'id')::uuid IS DISTINCT FROM p_expected_interpretation_id OR
     (v_plan->'expected_q'->>'version')::int IS DISTINCT FROM p_expected_interpretation_version OR
     (v_plan->>'input_fingerprint' IS DISTINCT FROM p_expected_input_fingerprint) OR
     (v_plan->>'context_hash' IS DISTINCT FROM p_expected_context_hash) OR
     (v_plan_res->>'plan_hash' IS DISTINCT FROM p_reviewed_plan_hash) THEN
    RAISE EXCEPTION 'token_mismatch' USING ERRCODE='PT409';
  END IF;

  v_append_res := "time".append_classified_attendance_fact(
    p_tenant_id, p_work_instance_id, v_plan, p_expected_fact_id, p_expected_fact_version,
    p_expected_interpretation_id, p_expected_interpretation_version, v_actor, v_reason
  );

  v_append_res := jsonb_set(v_append_res, '{operation_id}', to_jsonb(gen_random_uuid()));

  INSERT INTO "time".classification_operations (
    tenant_id, id, actor_user_id, idempotency_key, action_intent_hash, is_correction, reason, expected_tokens, result
  ) VALUES (
    p_tenant_id, (v_append_res->>'operation_id')::uuid, v_actor, v_key, v_intent_hash, v_is_correction, v_reason,
    v_intent_obj - 'reason' - 'action' - 'tenant' - 'actor' - 'instance',
    v_append_res
  );

  RETURN v_append_res;
END;
$$;
REVOKE ALL ON FUNCTION public.attendance_commit_classification FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.attendance_commit_classification TO authenticated;

-- Apply the same Leave disclosure rule to current facts and their immutable history.
CREATE FUNCTION time.attendance_visible_json(p_value jsonb, p_reveal_leave boolean)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = '' AS $function$
 SELECT CASE jsonb_typeof(p_value)
 WHEN 'object' THEN coalesce((SELECT jsonb_object_agg(k,time.attendance_visible_json(v,p_reveal_leave))
   FROM jsonb_each(p_value) AS obj(k,v)
   WHERE coalesce(p_reveal_leave,false) OR k <> 'pay_effect'),'{}'::jsonb)
 WHEN 'array' THEN coalesce((SELECT jsonb_agg(time.attendance_visible_json(v,p_reveal_leave) ORDER BY ordinal)
   FROM jsonb_array_elements(p_value) WITH ORDINALITY AS arr(v,ordinal)),'[]'::jsonb)
 ELSE p_value END
$function$;
REVOKE ALL ON FUNCTION time.attendance_visible_json(jsonb,boolean) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION time.attendance_fact_context_status(p_tenant uuid,p_instance uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $function$
 SELECT jsonb_build_object(
   'current_classification',e.plan->'classification',
   'classification_reconciliation_required',
     coalesce(f.fact->>'input_fingerprint',q.input_fingerprint)
       IS DISTINCT FROM time.work_instance_interpretation_fingerprint(p_tenant,p_instance))
 FROM time.attendance_facts f
 JOIN time.interpretations q ON q.tenant_id=f.tenant_id AND q.id=f.interpretation_id
 LEFT JOIN time.classification_evidence e ON e.tenant_id=q.tenant_id AND e.interpretation_id=q.id
 WHERE f.tenant_id=p_tenant AND f.work_instance_id=p_instance
 ORDER BY f.version DESC LIMIT 1
$function$;
REVOKE ALL ON FUNCTION time.attendance_fact_context_status(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Preserve existing scoped readers and pagination; fail closed if their anchors drift.
DO $patch$
DECLARE source text; anchor text; replacement text;
BEGIN
 source:=pg_get_functiondef('public.attendance_instance_detail(uuid,uuid)'::regprocedure);
 anchor:=' RETURN result;';
 IF (length(source)-length(replace(source,anchor,'')))/length(anchor) <> 1 THEN
   RAISE EXCEPTION 'attendance_detail_source_drift';
 END IF;
 replacement:=$text$ RETURN time.attendance_visible_json(
   result || coalesce(time.attendance_fact_context_status(p_tenant_id,p_instance_id),'{}'::jsonb),
   platform_private.has_tenant_permission(p_tenant_id,actor,'leave.view')
     OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer'));$text$;
 EXECUTE replace(source,anchor,replacement);

 source:=pg_get_functiondef('public.attendance_payroll_input_projection(uuid,date,date,date,text,uuid,integer)'::regprocedure);
 anchor:=$text$AND f.fact->>'outcome' IN('worked','absence')$text$;
 IF (length(source)-length(replace(source,anchor,'')))/length(anchor) <> 1 THEN
   RAISE EXCEPTION 'attendance_projection_outcome_source_drift';
 END IF;
 source:=replace(source,anchor,$text$AND f.fact->>'outcome' IN('worked','absence','leave_covered')$text$);
 anchor:=$text$'consumed',false) ORDER BY operational_date$text$;
 IF (length(source)-length(replace(source,anchor,'')))/length(anchor) <> 1 THEN
   RAISE EXCEPTION 'attendance_projection_item_source_drift';
 END IF;
 replacement:=$text$'consumed',false,
   'leave_units',fact->'leave_units','leave_sources',time.attendance_visible_json(fact->'leave_sources',
     platform_private.has_tenant_permission(p_tenant_id,actor,'leave.view')
       OR platform_private.has_tenant_permission(p_tenant_id,actor,'tenant.administer')),
   'observations',fact->'observations',
   'classification_reconciliation_required',coalesce((time.attendance_fact_context_status(p_tenant_id,work_instance_id)->>'classification_reconciliation_required')::boolean,false)) ORDER BY operational_date$text$;
 EXECUTE replace(source,anchor,replacement);
END $patch$;
