USE ROLE SECURITYADMIN;

-- Business governance
CREATE ROLE IF NOT EXISTS DATA_OWNER
    COMMENT = 'Business accountability for governed banking data';

CREATE ROLE IF NOT EXISTS DATA_STEWARD
    COMMENT = 'Business stewardship, metadata definitions and classification review';

-- Consumers
CREATE ROLE IF NOT EXISTS DEPOSITS_ANALYST
    COMMENT = 'Read-only consumer of governed deposit data products';

CREATE ROLE IF NOT EXISTS BRANCH_HUDSON
    COMMENT = 'Branch-scoped consumer role for row-level security demonstration';

-- Engineering / Governance
CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Builds and operates governed data pipelines and models';

CREATE ROLE IF NOT EXISTS DATA_GOVERNANCE_ADMIN
    COMMENT = 'Administers governance metadata, tags, classification and data-protection policies';

CREATE ROLE IF NOT EXISTS DATA_PLATFORM_ADMIN
    COMMENT = 'Administers Snowflake platform infrastructure and shared technical objects';

-- Automation
CREATE ROLE IF NOT EXISTS SVC_PIPELINE
    COMMENT = 'Non-human role for CI/CD, automated pipeline execution and metadata harvesting';