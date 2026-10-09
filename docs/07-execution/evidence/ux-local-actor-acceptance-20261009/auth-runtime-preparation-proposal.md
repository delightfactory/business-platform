# Local Auth preparation after permission refusal

Status: PROPOSED / NOT EXECUTED. Applies only to empty business_platform_ux_c93f09f_qa, never the shared development database.

The first temporary GoTrue attempt refused init migration00 with SQLSTATE42501, must be owner of table users. It did not reach health, create a synthetic user, launch Next or open a browser. No ownership correction, privileged restart or bypass was attempted. Two task roles returned to NOLOGIN/password disabled, containers stopped/removed, generated private environment values erased, all four owned ports have zero listeners, QA users/sessions/refresh tokens/tenants zero.

Proposed concrete scope: execute the adjacent guarded SQL to assign only Auth schema/table/view/sequence/function/enum ownership to the task Auth role in this named empty disconnected QA database. Keep the role disabled during preparation; no global settings, existing roles or application objects change. No superuser/createdb/createrole. Then create a fresh synthetic loopback-only Auth/REST/Next test runtime, valid no more than two hours, and qualify the five approved D8 self-service returns. Retire its access/services at completion. Current expired Cube5 access remains untouched.

This requires a new owner decision because the owner explicitly said to stop any refused permission operation. It is local test infrastructure preparation, not a feature, provider substitution or production deployment. Verify source/schema Auth contracts after authorized service migration; do not assume stored migration labels mean a service will perform no DDL. Existing 36 bounded supplied-claim SQL checks remain evidence at their original scope; real browser login still unverified.
