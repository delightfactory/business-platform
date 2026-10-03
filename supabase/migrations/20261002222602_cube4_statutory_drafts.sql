-- Nonfinancial Compliance dossiers stay separate from calculation packs.
-- Saving a draft must not alter run manifests or qualify any legal constant.
CREATE TABLE payroll.statutory_draft_heads(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),version text NOT NULL UNIQUE,
 revision integer NOT NULL CHECK(revision>0),created_by uuid NOT NULL REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE TABLE payroll.statutory_draft_versions(
 head_id uuid NOT NULL REFERENCES payroll.statutory_draft_heads(id),revision integer NOT NULL CHECK(revision>0),
 effective_from date NOT NULL,effective_until date,source_references jsonb NOT NULL,
 reason text NOT NULL,actor_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(head_id,revision),CHECK(effective_from BETWEEN date '1900-01-01' AND date '2200-12-31'),
 CHECK(effective_until IS NULL OR effective_until>effective_from AND effective_until<=date '2200-12-31'));
CREATE TABLE payroll.statutory_draft_receipts(
 actor_id uuid NOT NULL REFERENCES auth.users(id),attempt uuid NOT NULL,intent jsonb NOT NULL,result jsonb NOT NULL,
 PRIMARY KEY(actor_id,attempt));
ALTER TABLE payroll.statutory_draft_heads ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.statutory_draft_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll.statutory_draft_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON payroll.statutory_draft_heads,payroll.statutory_draft_versions,payroll.statutory_draft_receipts FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER statutory_draft_versions_immutable BEFORE UPDATE OR DELETE ON payroll.statutory_draft_versions FOR EACH ROW EXECUTE FUNCTION payroll.immutable();
CREATE TRIGGER statutory_draft_receipts_immutable BEFORE UPDATE OR DELETE ON payroll.statutory_draft_receipts FOR EACH ROW EXECUTE FUNCTION payroll.immutable();

CREATE FUNCTION payroll.statutory_draft_actor() RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
BEGIN
 IF NOT public.current_operator_can_manage_statutory_rules() THEN RAISE EXCEPTION 'statutory_draft_forbidden' USING ERRCODE='42501';END IF;
 RETURN auth.uid();
END $f$;
REVOKE ALL ON FUNCTION payroll.statutory_draft_actor() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.statutory_draft_save(p_head uuid,p_expected integer,p_attempt uuid,p_version text,p_from date,p_until date,p_sources jsonb,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE actor uuid;head payroll.statutory_draft_heads;receipt payroll.statutory_draft_receipts;item jsonb;
 version_label text:=btrim(p_version);reason text:=btrim(p_reason);sources jsonb:='[]';intent jsonb;result jsonb;
BEGIN
 actor:=payroll.statutory_draft_actor();
 IF p_attempt IS NULL OR p_expected IS NULL OR p_expected<0 OR version_label IS NULL OR length(version_label) NOT BETWEEN 3 AND 100
  OR reason IS NULL OR length(reason) NOT BETWEEN 3 AND 500 OR p_from IS NULL
  OR NOT(p_from BETWEEN date '1900-01-01' AND date '2200-12-31')
  OR(p_until IS NOT NULL AND (p_until<=p_from OR p_until>date '2200-12-31'))
  OR jsonb_typeof(p_sources) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 IF jsonb_array_length(p_sources) NOT BETWEEN 1 AND 6 THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_sources) LOOP
  IF jsonb_typeof(item) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  IF NOT(item ?& ARRAY['title','url']) OR(SELECT count(*) FROM jsonb_object_keys(item))<>2
   OR jsonb_typeof(item->'title') IS DISTINCT FROM 'string' OR jsonb_typeof(item->'url') IS DISTINCT FROM 'string'
   OR length(btrim(item->>'title')) NOT BETWEEN 3 AND 160 OR length(btrim(item->>'url'))>2048
   OR btrim(item->>'url') !~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(/[^[:space:]<>"\\]*)?$'
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(sources)s WHERE s->>'url'=btrim(item->>'url')) THEN
   RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  sources:=sources||jsonb_build_array(jsonb_build_object('title',btrim(item->>'title'),'url',btrim(item->>'url')));
 END LOOP;
 intent:=jsonb_build_object('head',p_head,'expected',p_expected,'version',version_label,'from',p_from,'until',p_until,'sources',sources,'reason',reason);
 -- Same authority lock as grant/revoke; account changes serialize through row lock.
 PERFORM pg_advisory_xact_lock(772412,115991);
 PERFORM 1 FROM auth.users WHERE id=actor FOR SHARE;
 PERFORM 1 FROM platform_private.platform_operator_grants WHERE user_id=actor FOR SHARE;
 actor:=payroll.statutory_draft_actor();
 SELECT * INTO receipt FROM payroll.statutory_draft_receipts WHERE actor_id=actor AND attempt=p_attempt;
 IF FOUND THEN
  IF receipt.intent<>intent THEN RAISE EXCEPTION 'statutory_draft_attempt_conflict' USING ERRCODE='PT409';END IF;
  RETURN receipt.result;
 END IF;
 IF p_head IS NULL THEN
  IF p_expected<>0 THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
  IF EXISTS(SELECT 1 FROM payroll.statutory_draft_heads WHERE statutory_draft_heads.version=version_label) THEN
   -- Qualified column avoids variable-name ambiguity in the identity lookup.
   RAISE EXCEPTION 'statutory_draft_exists' USING ERRCODE='PT409';END IF;
  INSERT INTO payroll.statutory_draft_heads(version,revision,created_by)VALUES(version_label,1,actor) RETURNING * INTO head;
 ELSE
  SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=p_head FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'statutory_draft_not_found' USING ERRCODE='22023';END IF;
  IF head.revision<>p_expected OR head.version<>version_label THEN RAISE EXCEPTION 'statutory_draft_stale' USING ERRCODE='PT409';END IF;
  UPDATE payroll.statutory_draft_heads SET revision=revision+1 WHERE id=head.id RETURNING * INTO head;
 END IF;
 INSERT INTO payroll.statutory_draft_versions(head_id,revision,effective_from,effective_until,source_references,reason,actor_id)
 VALUES(head.id,head.revision,p_from,p_until,sources,reason,actor);
 result:=jsonb_build_object('head',head.id,'revision',head.revision,'state','unqualified');
 INSERT INTO payroll.statutory_draft_receipts VALUES(actor,p_attempt,intent,result);
 RETURN result;
END $f$;

CREATE FUNCTION public.statutory_draft_workspace(p_head uuid DEFAULT NULL,p_after_created timestamptz DEFAULT NULL,p_after_id uuid DEFAULT NULL,p_before_revision integer DEFAULT NULL,p_limit integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE head payroll.statutory_draft_heads;items jsonb;history jsonb;more boolean;last_item jsonb;
BEGIN
 PERFORM payroll.statutory_draft_actor();
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 OR(p_after_created IS NULL)<>(p_after_id IS NULL)
  OR(p_after_created IS NOT NULL AND NOT isfinite(p_after_created))
  OR(p_head IS NOT NULL AND p_after_id IS NOT NULL) OR(p_head IS NULL AND p_before_revision IS NOT NULL)
  OR(p_before_revision IS NOT NULL AND p_before_revision<1) THEN RAISE EXCEPTION 'statutory_draft_invalid' USING ERRCODE='22023';END IF;
 IF p_head IS NOT NULL THEN
  SELECT * INTO head FROM payroll.statutory_draft_heads WHERE id=p_head;
  IF NOT FOUND THEN RAISE EXCEPTION 'statutory_draft_not_found' USING ERRCODE='22023';END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY revision DESC),'[]') INTO history FROM(
   SELECT * FROM payroll.statutory_draft_versions WHERE head_id=p_head AND revision<coalesce(p_before_revision,2147483647) ORDER BY revision DESC LIMIT p_limit)v;
  last_item:=history->(jsonb_array_length(history)-1);
  SELECT EXISTS(SELECT 1 FROM payroll.statutory_draft_versions WHERE head_id=p_head AND revision<(last_item->>'revision')::integer) INTO more;
  RETURN jsonb_build_object('head',to_jsonb(head),'current',(SELECT to_jsonb(v) FROM payroll.statutory_draft_versions v WHERE head_id=head.id AND revision=head.revision),
   'history',history,'next_before_revision',CASE WHEN more THEN(last_item->>'revision')::integer END,'state','unqualified');
 END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY created_at DESC,id DESC),'[]') INTO items FROM(
  SELECT h.*,v.effective_from,v.effective_until FROM payroll.statutory_draft_heads h JOIN payroll.statutory_draft_versions v ON v.head_id=h.id AND v.revision=h.revision
  WHERE p_after_id IS NULL OR(h.created_at,h.id)<(p_after_created,p_after_id) ORDER BY h.created_at DESC,h.id DESC LIMIT p_limit+1)v;
 more:=jsonb_array_length(items)>p_limit;
 IF more THEN items:=items-p_limit;END IF;last_item:=items->(jsonb_array_length(items)-1);
 RETURN jsonb_build_object('items',items,'next',CASE WHEN more THEN jsonb_build_object('created',last_item->>'created_at','id',last_item->>'id') END,'state','unqualified');
END $f$;
REVOKE ALL ON FUNCTION public.statutory_draft_save(uuid,integer,uuid,text,date,date,jsonb,text),public.statutory_draft_workspace(uuid,timestamptz,uuid,integer,integer) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.statutory_draft_save(uuid,integer,uuid,text,date,date,jsonb,text),public.statutory_draft_workspace(uuid,timestamptz,uuid,integer,integer) TO authenticated;
