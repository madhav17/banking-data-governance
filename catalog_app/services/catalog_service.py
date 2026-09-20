from abc import ABC, abstractmethod


class CatalogService(ABC):
    """Interface for catalog metadata retrieval."""

    @abstractmethod
    def search_objects(self, query: str) -> list[dict]:
        """Return catalog objects matching the query."""

    @abstractmethod
    def get_object_details(self, object_fqn: str) -> dict:
        """Return object-level metadata for a fully qualified object name."""

    @abstractmethod
    def get_columns(self, object_fqn: str) -> list[dict]:
        """Return column-level metadata for a fully qualified object name."""

    @abstractmethod
    def get_upstream_sources(self, object_fqn: str) -> list[str]:
        """Return upstream source objects for a fully qualified object name."""


class SnowflakeCatalogService(CatalogService):
    """Snowpark-backed catalog service for Streamlit in Snowflake."""

    def __init__(self, session):
        self.session = session
        self._rows: list[dict] | None = None

    def _fetch_rows(self) -> list[dict]:
        if self._rows is None:
            rows = self.session.sql(
                """
                SELECT
                    DATABASE_NAME,
                    SCHEMA_NAME,
                    OBJECT_NAME,
                    OBJECT_TYPE,
                    OBJECT_FQN,
                    COLUMN_NAME,
                    DATA_TYPE,
                    DESCRIPTION,
                    OBJECT_DESCRIPTION,
                    DOMAIN,
                    DATA_OWNER,
                    DATA_STEWARD,
                    CERTIFICATION,
                    CDE_FLAG,
                    CDE_TIER,
                    CLASSIFICATION,
                    UPSTREAM_SOURCES,
                    LAST_REFRESH,
                    QUALITY_RESULT,
                    QUALITY_MEASURED_AT,
                    QUERY_COUNT_SINCE_CREATION,
                    DISTINCT_ROLES_SINCE_CREATION
                FROM GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG
                ORDER BY
                    DATABASE_NAME,
                    SCHEMA_NAME,
                    OBJECT_NAME,
                    COLUMN_NAME
                """
            ).collect()
            self._rows = [row.as_dict() for row in rows]

        return self._rows

    def _object_rows(self, object_fqn: str) -> list[dict]:
        return [row for row in self._fetch_rows() if row["OBJECT_FQN"] == object_fqn]

    @staticmethod
    def _display(value) -> str:
        if value is None:
            return "NOT AVAILABLE"
        return str(value)

    @staticmethod
    def _distinct_values(rows: list[dict], key: str) -> list[str]:
        values = {
            str(row.get(key))
            for row in rows
            if row.get(key) not in (None, "", "NOT AVAILABLE", "NOT CLASSIFIED")
        }
        return sorted(values)

    def _to_object_summary(self, rows: list[dict]) -> dict:
        first = rows[0]
        classifications = self._distinct_values(rows, "CLASSIFICATION")
        cde_count = sum(1 for row in rows if row.get("CDE_FLAG") == "YES")
        upstream_sources = self.get_upstream_sources(first["OBJECT_FQN"])

        return {
            "database": self._display(first.get("DATABASE_NAME")),
            "schema": self._display(first.get("SCHEMA_NAME")),
            "object_name": self._display(first.get("OBJECT_NAME")),
            "object_type": self._display(first.get("OBJECT_TYPE")),
            "object_fqn": self._display(first.get("OBJECT_FQN")),
            "description": self._display(first.get("OBJECT_DESCRIPTION")),
            "domain": self._display(first.get("DOMAIN")),
            "owner": self._display(first.get("DATA_OWNER")),
            "steward": self._display(first.get("DATA_STEWARD")),
            "certification": self._display(first.get("CERTIFICATION")),
            "cde": "YES" if cde_count > 0 else "NO",
            "classification": ", ".join(classifications) if classifications else "NOT CLASSIFIED",
            "last_refresh": self._display(first.get("LAST_REFRESH")),
            "quality_status": self._display(first.get("QUALITY_RESULT")),
            "usage_query_count": self._display(first.get("QUERY_COUNT_SINCE_CREATION")),
            "distinct_roles": self._display(first.get("DISTINCT_ROLES_SINCE_CREATION")),
            "upstream_sources": upstream_sources,
        }

    def search_objects(self, query: str) -> list[dict]:
        normalized_query = query.strip().lower()
        matched_rows = []

        for row in self._fetch_rows():
            searchable_text = " ".join(
                self._display(row.get(key))
                for key in
                (
                    "OBJECT_FQN",
                    "OBJECT_NAME",
                    "COLUMN_NAME",
                    "DESCRIPTION",
                    "OBJECT_DESCRIPTION",
                    "DOMAIN",
                    "CERTIFICATION",
                    "CLASSIFICATION",
                )
            ).lower()

            if not normalized_query or normalized_query in searchable_text:
                matched_rows.append(row)

        summaries = {}
        for row in matched_rows:
            object_fqn = row["OBJECT_FQN"]
            if object_fqn in summaries:
                continue

            object_rows = self._object_rows(object_fqn)
            classifications = self._distinct_values(object_rows, "CLASSIFICATION")
            summaries[object_fqn] = {
                "object_fqn": object_fqn,
                "object_name": row["OBJECT_NAME"],
                "database": row["DATABASE_NAME"],
                "schema": row["SCHEMA_NAME"],
                "domain": row["DOMAIN"],
                "certification": row["CERTIFICATION"],
                "classification": ", ".join(classifications) if classifications else "NOT CLASSIFIED",
                "quality_result": row["QUALITY_RESULT"],
                "description": row["OBJECT_DESCRIPTION"],
                "cde_columns": sum(1 for object_row in object_rows if object_row.get("CDE_FLAG") == "YES"),
            }

        return sorted(summaries.values(), key=lambda item: item["object_fqn"])

    def get_object_details(self, object_fqn: str) -> dict:
        rows = self._object_rows(object_fqn)
        if not rows:
            raise ValueError(f"Object not found in catalog view: {object_fqn}")

        return self._to_object_summary(rows)

    def get_columns(self, object_fqn: str) -> list[dict]:
        columns = []
        for row in self._object_rows(object_fqn):
            columns.append(
                {
                    "column_name": row["COLUMN_NAME"],
                    "data_type": row["DATA_TYPE"],
                    "description": row["DESCRIPTION"],
                    "cde_flag": row["CDE_FLAG"],
                    "classification": row["CLASSIFICATION"],
                }
            )

        return columns

    def get_upstream_sources(self, object_fqn: str) -> list[str]:
        rows = self._object_rows(object_fqn)
        if not rows:
            return []

        upstream_sources = rows[0].get("UPSTREAM_SOURCES")
        if upstream_sources in (None, "", "NOT AVAILABLE"):
            return []

        return [source.strip() for source in str(upstream_sources).split(",") if source.strip()]
