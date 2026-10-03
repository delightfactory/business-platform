import fs from 'node:fs';

// Build the additive definitions from the exact checked-in predecessor anchors.
// This script does not access a database or mutate historical migrations.
const read = name => fs.readFileSync(`supabase/migrations/${name}`, 'utf8');
const replaceOnce = (text, before, after) => {
  if (text.split(before).length !== 2) throw new Error(`Unexpected anchor: ${before}`);
  return text.replace(before, () => after);
};
const targetMigration='20261003032000_cube4_review_contract_repairs.sql';
const migrationNames=fs.readdirSync('supabase/migrations').filter(name=>name.endsWith('.sql'));
const versions=new Set();
for(const name of migrationNames){
  const version=/^(\d{14})_/.exec(name)?.[1];
  if(!version||versions.has(version))throw new Error(`Invalid or duplicate migration version: ${name}`);
  versions.add(version);
  if(name!==targetMigration&&version>=targetMigration.slice(0,14))throw new Error(`Repair must follow existing migration: ${name}`);
}
let guard = read('20261003027000_cube4_source_correction_closure.sql');
guard = guard.slice(guard.indexOf('CREATE FUNCTION payroll.guard_unbound_leave_approval()'), guard.indexOf('CREATE CONSTRAINT TRIGGER payroll_guard_unbound_leave_approval_update'));
guard = guard.replace('CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
guard = replaceOnce(guard, "AND binding.source_date=day_row.leave_date AND binding.source_identity->>'request_id' IS NOT NULL)", `AND binding.source_date=day_row.leave_date
     AND ((binding.source_identity->>'request_id'=NEW.id::text
       AND binding.source_version->>'approved_preview_version'=NEW.approved_preview_version::text)
      OR EXISTS(SELECT 1 FROM leave.correction_events event
       JOIN leave.requests original ON original.tenant_id=event.tenant_id AND original.id=event.original_request_id
       WHERE event.tenant_id=NEW.tenant_id AND event.replacement_request_id=NEW.id
        AND event.original_request_id::text=binding.source_identity->>'request_id'
        AND event.event_key='hr.corrected' AND event.to_state='superseded'
        AND original.state='superseded')))`);
let report = read('20261002074500_cube4_payroll_reports.sql');
report = report.slice(report.indexOf('CREATE FUNCTION payroll.report_payslip_lines('), report.indexOf('CREATE FUNCTION payroll.report_rows('));
report = report.replace('CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
report = replaceOnce(report, 'ELSE COALESCE(metadata.known,false) END known,', 'ELSE COALESCE(statutory_metadata.known,metadata.known,false) END known,');
report = replaceOnce(report, 'ELSE metadata.visible END visible,', 'ELSE COALESCE(statutory_metadata.visible,metadata.visible) END visible,');
report = replaceOnce(report, 'ELSE COALESCE(metadata.display_order,999) END display_order', 'ELSE COALESCE(statutory_metadata.display_order,metadata.display_order,999) END display_order');
report = replaceOnce(report, ') metadata ON true)', `) metadata ON true
 LEFT JOIN LATERAL(
  SELECT count(*)=1 AND bool_and(
    raw_line->>'statutory'='true'
    AND raw_line->'presentation'->>'schema'='payroll-statutory-v1'
    AND raw_line->'presentation'->>'visible'='true'
    AND raw_line->'presentation'->>'order' ~ '^[0-9]{1,4}$'
    AND raw_line->>'amount'=l.line->>'amount'
    AND raw_line->>'name'=l.line->>'name'
    AND employee.e->'statutory_calculation'->>'adapter'='eg-employee-statutory-v1'
    AND raw_line->'presentation'->>'pack_id'=CASE WHEN l.line->>'component'='statutory:tax'
      THEN employee.e->'statutory_calculation'->>'pack_id'
      ELSE employee.e->'statutory_calculation'->>'insurance_pack_id' END
  ) known,
  bool_and(raw_line->>'classification'='deduction') visible,
  min(CASE WHEN raw_line->'presentation'->>'order' ~ '^[0-9]{1,4}$'
    THEN (raw_line->'presentation'->>'order')::integer END) display_order
  FROM employee CROSS JOIN LATERAL jsonb_array_elements(employee.e->'lines') raw_line
  WHERE raw_line->>'component'=l.line->>'component'
   AND raw_line->>'classification'=l.line->>'classification'
   AND ((l.line->>'component'='statutory:tax' AND l.line->>'classification'='deduction')
    OR (l.line->>'component' LIKE 'statutory:insurance:%' AND l.line->>'classification'='deduction')
    OR (l.line->>'component' LIKE 'statutory:employer:%' AND l.line->>'classification'='employer_cost'))
 ) statutory_metadata ON l.line->>'component' LIKE 'statutory:%')`);
// Historical output without the explicit versioned presentation remains blocked.
// Patch only the private adapter, with three checked anchors at migration time.
const patches = [
  ["'statutory',true,'amount',(branch->>'employee_amount')", "'statutory',true,'presentation',jsonb_build_object('schema','payroll-statutory-v1','visible',true,'order',1100,'pack_id',p_insurance_pack),'amount',(branch->>'employee_amount')"],
  ["'statutory',true,'amount',(branch->>'employer_amount')", "'statutory',true,'presentation',jsonb_build_object('schema','payroll-statutory-v1','visible',true,'order',1100,'pack_id',p_insurance_pack),'amount',(branch->>'employer_amount')"],
  ["'statutory',true,'amount',tax_delta::text", "'statutory',true,'presentation',jsonb_build_object('schema','payroll-statutory-v1','visible',true,'order',1200,'pack_id',p_tax_pack),'amount',tax_delta::text"],
  ["'pack_id',p_tax_pack,'facts',p_facts", "'pack_id',p_tax_pack,'insurance_pack_id',p_insurance_pack,'facts',p_facts"],
];
const literal = text => `'${text.replaceAll("'", "''")}'`;
const adapter = read('20261003022000_cube4_independent_statutory_pack_binding.sql');
for (const [before, after] of patches) replaceOnce(adapter, before, after);
const patchSql = `DO $patch$ DECLARE definition text;before text;after text;BEGIN
 definition:=pg_get_functiondef('payroll.calculate_statutory_employee(jsonb,uuid,jsonb,uuid,jsonb)'::regprocedure);
${patches.map(([before, after]) => ` before:=${literal(before)};after:=${literal(after)};
 IF (length(definition)-length(replace(definition,before,'')))/length(before)<>1 THEN
  RAISE EXCEPTION 'unexpected_statutory_presentation_anchor';END IF;
 definition:=replace(definition,before,after);`).join('\n')}
 EXECUTE definition;
END $patch$;
`;
fs.writeFileSync(`supabase/migrations/${targetMigration}`, `-- Additive review repairs; public financial release remains closed.
-- Exact request/preview or the existing authorized Leave replacement event only.
-- A cancelled unrelated request never licenses a new historical approval.
${guard}\n-- Versioned immutable statutory presentation, including a zero tax delta.
${patchSql}\n${report}`);
