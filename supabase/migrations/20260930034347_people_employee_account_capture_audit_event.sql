ALTER TABLE people.employee_account_provision_audit_events
  DROP CONSTRAINT employee_account_provision_audit_events_event_key_check;
ALTER TABLE people.employee_account_provision_audit_events
  ADD CONSTRAINT employee_account_provision_audit_events_event_key_check CHECK (event_key IN (
    'employee.account_requested','employee.account_created','employee.account_delivery',
    'employee.account_manual_review','employee.account_activation_deferred','employee.account_activated',
    'employee.account_auth_user_captured'));
