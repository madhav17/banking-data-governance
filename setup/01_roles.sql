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


-- Bootstrap access for the user running the setup scripts.
-- Without this, later scripts cannot activate project roles such as DATA_ENGINEER.
SET DEPLOYMENT_USER = (SELECT CURRENT_USER());

GRANT ROLE DATA_OWNER             TO USER IDENTIFIER($DEPLOYMENT_USER);
GRANT ROLE DATA_STEWARD           TO USER IDENTIFIER($DEPLOYMENT_USER);
GRANT ROLE DEPOSITS_ANALYST       TO USER IDENTIFIER($DEPLOYMENT_USER);
GRANT ROLE BRANCH_HUDSON          TO USER IDENTIFIER($DEPLOYMENT_USER);
GRANT ROLE DATA_ENGINEER          TO USER IDENTIFIER($DEPLOYMENT_USER);
GRANT ROLE DATA_GOVERNANCE_ADMIN  TO USER IDENTIFIER($DEPLOYMENT_USER);
GRANT ROLE DATA_PLATFORM_ADMIN    TO USER IDENTIFIER($DEPLOYMENT_USER);
