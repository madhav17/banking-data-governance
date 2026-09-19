-- CI-only helper. Render placeholders in GitHub Actions before execution.

DROP DATABASE IF EXISTS {{CI_DATABASE}};
