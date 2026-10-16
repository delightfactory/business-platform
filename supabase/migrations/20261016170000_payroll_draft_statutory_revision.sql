-- Initial preparation must allow completing the same draft at its existing date.
-- Append a new immutable revision; keep published/frozen contexts on correction paths.
DO $patch$
DECLARE definition text;anchor text;replacement text;
BEGIN
 definition:=pg_get_functiondef('public.payroll_save_input_before_recurring_debts(uuid,uuid,text,uuid,uuid,uuid,integer,date,date,jsonb,text,uuid)'::regprocedure);
 anchor:='(p_from<=current.effective_from OR p_kind NOT IN(''component'',''statutory_context'')';
 replacement:='((p_from<=current.effective_from AND NOT (p_from=current.effective_from AND p_operation=''save'' AND current.status=''draft'' AND p_kind IN(''opening_ytd'',''statutory_context''))) OR p_kind NOT IN(''component'',''statutory_context'')';
 IF (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_draft_revision_guard';END IF;
 EXECUTE replace(definition,anchor,replacement);
END $patch$;
