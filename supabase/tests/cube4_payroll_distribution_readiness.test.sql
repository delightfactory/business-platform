-- Uses actual authenticated reads of the existing NONLEGAL frozen fixture.
-- No real rules are inserted or qualified.
SET LOCAL ROLE authenticated;
SELECT is(pg_temp.report('sheet')->>'report','sheet','unqualified historical sheet stays readable for review');
SELECT ok(pg_temp.report('sheet')->'issues' @> '["statutory_pack_unqualified"]','sheet reports missing frozen qualification');
SELECT ok(pg_temp.report('payslip')->'issues' @> '["statutory_pack_unqualified"]','payslip reports missing frozen qualification');
SELECT throws_ok($$SELECT pg_temp.report('sheet',exporting=>true)$$,'23514','payroll_report_incomplete','unqualified sheet cannot be distributed');
SELECT throws_ok($$SELECT pg_temp.report('payslip',exporting=>true)$$,'23514','payroll_report_incomplete','unqualified payslip cannot be distributed');
RESET ROLE;
SELECT * FROM finish();
