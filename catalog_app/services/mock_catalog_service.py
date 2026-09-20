from services.catalog_service import CatalogService


MOCK_OBJECTS = {
    "ANALYTICS.STAGING.STG_CUSTOMER": {
        "database": "ANALYTICS",
        "schema": "STAGING",
        "object_name": "STG_CUSTOMER",
        "object_type": "TABLE",
        "description": "Standardized customer profile data from the RAW customer feed.",
        "domain": "Customer",
        "owner": "DATA_OWNER",
        "steward": "DATA_STEWARD",
        "certification": "NOT CERTIFIED",
        "cde": "PARTIAL",
        "classification": "CONFIDENTIAL",
        "last_refresh": "NOT AVAILABLE",
        "quality_status": "NOT EVALUATED",
        "usage_query_count": "NOT AVAILABLE",
        "distinct_roles": "NOT AVAILABLE",
        "upstream_sources": ["RAW.BANKING.CUSTOMER"],
        "columns": [
            {
                "column_name": "CUSTOMER_ID",
                "data_type": "NUMBER",
                "description": "Internal customer identifier.",
                "cde_flag": "YES",
                "classification": "INTERNAL",
            },
            {
                "column_name": "CUSTOMER_TYPE",
                "data_type": "VARCHAR",
                "description": "Customer segment such as person or business.",
                "cde_flag": "NO",
                "classification": "INTERNAL",
            },
            {
                "column_name": "TAX_ID",
                "data_type": "VARCHAR",
                "description": "Tax identifier retained for governance testing.",
                "cde_flag": "YES",
                "classification": "RESTRICTED",
            },
            {
                "column_name": "EMAIL",
                "data_type": "VARCHAR",
                "description": "Customer email address.",
                "cde_flag": "NO",
                "classification": "CONFIDENTIAL",
            },
        ],
    },
    "ANALYTICS.STAGING.STG_ACCOUNT": {
        "database": "ANALYTICS",
        "schema": "STAGING",
        "object_name": "STG_ACCOUNT",
        "object_type": "TABLE",
        "description": "Standardized deposit account records used by downstream marts.",
        "domain": "Deposits",
        "owner": "DATA_OWNER",
        "steward": "DATA_STEWARD",
        "certification": "NOT CERTIFIED",
        "cde": "PARTIAL",
        "classification": "INTERNAL",
        "last_refresh": "NOT AVAILABLE",
        "quality_status": "NOT EVALUATED",
        "usage_query_count": "NOT AVAILABLE",
        "distinct_roles": "NOT AVAILABLE",
        "upstream_sources": ["RAW.BANKING.ACCOUNT", "RAW.BANKING.PRODUCT"],
        "columns": [
            {
                "column_name": "ACCOUNT_ID",
                "data_type": "NUMBER",
                "description": "Internal account identifier.",
                "cde_flag": "YES",
                "classification": "INTERNAL",
            },
            {
                "column_name": "CUSTOMER_ID",
                "data_type": "NUMBER",
                "description": "Customer associated with the account.",
                "cde_flag": "YES",
                "classification": "INTERNAL",
            },
            {
                "column_name": "ACCOUNT_STATUS",
                "data_type": "VARCHAR",
                "description": "Current operational status of the account.",
                "cde_flag": "NO",
                "classification": "INTERNAL",
            },
            {
                "column_name": "OPEN_DATE",
                "data_type": "DATE",
                "description": "Date the account was opened.",
                "cde_flag": "NO",
                "classification": "INTERNAL",
            },
        ],
    },
    "ANALYTICS.STAGING.STG_ACCOUNT_DAILY_BALANCE": {
        "database": "ANALYTICS",
        "schema": "STAGING",
        "object_name": "STG_ACCOUNT_DAILY_BALANCE",
        "object_type": "TABLE",
        "description": "Daily account balance snapshots prepared for deposits reporting.",
        "domain": "Deposits",
        "owner": "DATA_OWNER",
        "steward": "DATA_STEWARD",
        "certification": "NOT CERTIFIED",
        "cde": "PARTIAL",
        "classification": "INTERNAL",
        "last_refresh": "NOT AVAILABLE",
        "quality_status": "NOT EVALUATED",
        "usage_query_count": "NOT AVAILABLE",
        "distinct_roles": "NOT AVAILABLE",
        "upstream_sources": ["RAW.BANKING.ACCOUNT_DAILY_BALANCE"],
        "columns": [
            {
                "column_name": "ACCOUNT_ID",
                "data_type": "NUMBER",
                "description": "Account identifier for the balance snapshot.",
                "cde_flag": "YES",
                "classification": "INTERNAL",
            },
            {
                "column_name": "BALANCE_DATE",
                "data_type": "DATE",
                "description": "Business date for the balance snapshot.",
                "cde_flag": "YES",
                "classification": "INTERNAL",
            },
            {
                "column_name": "CURRENT_BALANCE",
                "data_type": "NUMBER",
                "description": "Current balance as of the snapshot date.",
                "cde_flag": "YES",
                "classification": "CONFIDENTIAL",
            },
            {
                "column_name": "AVAILABLE_BALANCE",
                "data_type": "NUMBER",
                "description": "Available balance as of the snapshot date.",
                "cde_flag": "YES",
                "classification": "CONFIDENTIAL",
            },
        ],
    },
}


class MockCatalogService(CatalogService):
    """Static catalog service used for local UI development."""

    def search_objects(self, query: str) -> list[dict]:
        normalized_query = query.strip().lower()
        results = []

        for object_fqn, details in MOCK_OBJECTS.items():
            searchable_values = [
                object_fqn,
                details["object_name"],
                details["description"],
                details["domain"],
            ]
            searchable_values.extend(column["column_name"] for column in details["columns"])
            searchable_values.extend(column["description"] for column in details["columns"])

            if not normalized_query or any(
                normalized_query in str(value).lower() for value in searchable_values
            ):
                results.append(
                    {
                        "object_fqn": object_fqn,
                        "object_name": details["object_name"],
                        "schema": details["schema"],
                        "domain": details["domain"],
                        "description": details["description"],
                    }
                )

        return results

    def get_object_details(self, object_fqn: str) -> dict:
        return MOCK_OBJECTS[object_fqn]

    def get_columns(self, object_fqn: str) -> list[dict]:
        return MOCK_OBJECTS[object_fqn]["columns"]

    def get_upstream_sources(self, object_fqn: str) -> list[str]:
        return MOCK_OBJECTS[object_fqn]["upstream_sources"]

    def get_scorecard(self) -> list[dict]:
        return []
