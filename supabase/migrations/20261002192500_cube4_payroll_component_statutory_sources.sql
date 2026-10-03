-- Preserve effective component declarations in ACTUAL candidate monetary parts.
-- These are source facts for legal treatment, not a qualified tax decision.
DO $f$ DECLARE definition text;anchor text;replacement text;BEGIN
 definition:=pg_get_functiondef('payroll.build_review_before_advances(jsonb)'::regprocedure);
 IF strpos(definition,'declared_taxable')<>0 THEN RAISE EXCEPTION 'component_statutory_sources_already_present'; END IF;
 anchor:='''component_version'',component->''version''->>''id''))';
 replacement:='''component_version'',component->''version''->>''id'',
 ''declared_taxable'',CASE component_data->>''taxable'' WHEN ''true'' THEN true WHEN ''false'' THEN false END,
 ''declared_social'',CASE component_data->>''social'' WHEN ''true'' THEN true WHEN ''false'' THEN false END,
 ''declared_visible'',CASE component_data->>''visible'' WHEN ''true'' THEN true WHEN ''false'' THEN false END))';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
   RAISE EXCEPTION 'unexpected_recurring_statutory_source_anchor';
 END IF;
 definition:=replace(definition,anchor,replacement);
 anchor:='''input_version'',approved_input->''version''->>''id''))';
 replacement:='''input_version'',approved_input->''version''->>''id'',
 ''component_head'',component->''head''->>''id'',''component_version'',component->''version''->>''id'',
 ''declared_taxable'',CASE component_data->>''taxable'' WHEN ''true'' THEN true WHEN ''false'' THEN false END,
 ''declared_social'',CASE component_data->>''social'' WHEN ''true'' THEN true WHEN ''false'' THEN false END,
 ''declared_visible'',CASE component_data->>''visible'' WHEN ''true'' THEN true WHEN ''false'' THEN false END))';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
   RAISE EXCEPTION 'unexpected_adjustment_statutory_source_anchor';
 END IF;
 EXECUTE replace(definition,anchor,replacement);
 -- Retain declaration provenance when the existing detail endpoint condenses an adjustment.
 definition:=pg_get_functiondef('payroll.review_employee_detail(jsonb)'::regprocedure);
 anchor:='''reason'',l->''details''->0->>''reason'',''approved_amount'',l->>''amount''';
 replacement:=anchor||',''component_head'',l->''details''->0->''component_head'',
 ''component_version'',l->''details''->0->''component_version'',
 ''declared_taxable'',l->''details''->0->''declared_taxable'',
 ''declared_social'',l->''details''->0->''declared_social'',
 ''declared_visible'',l->''details''->0->''declared_visible''';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
   RAISE EXCEPTION 'unexpected_adjustment_statutory_detail_anchor';
 END IF;
 EXECUTE replace(definition,anchor,replacement);
 -- A changed output contract invalidates already reviewed candidates through
 -- the existing engine freshness check. Preserve the advances wrapper.
 definition:=pg_get_functiondef('payroll.run_manifest(uuid,uuid,uuid)'::regprocedure);
 anchor:='''-advances-v1''';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
   RAISE EXCEPTION 'unexpected_component_statutory_engine_anchor';
 END IF;
 EXECUTE replace(definition,anchor,'''-advances-v1-statutory-sources-v1''');
END $f$;
