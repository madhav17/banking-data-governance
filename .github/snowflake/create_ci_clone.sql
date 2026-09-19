-- CI-only helper. Render placeholders in GitHub Actions before execution.
-- Do not run this against production manually without reviewing rendered names.

CREATE DATABASE {{CI_DATABASE}} CLONE {{BASE_DATABASE}};

CREATE SCHEMA IF NOT EXISTS {{CI_DATABASE}}.{{CI_SCHEMA}};
