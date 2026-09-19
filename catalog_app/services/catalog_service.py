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
    """Future Snowpark-backed catalog service.

    This placeholder is intentionally not implemented in this phase. Later it
    will use snowflake.snowpark.context.get_active_session() inside Streamlit in
    Snowflake and query GOVERNANCE, ANALYTICS, and ACCOUNT_USAGE metadata.
    """

    def __init__(self, session):
        self.session = session

    def search_objects(self, query: str) -> list[dict]:
        raise NotImplementedError("SnowflakeCatalogService is planned for a later phase.")

    def get_object_details(self, object_fqn: str) -> dict:
        raise NotImplementedError("SnowflakeCatalogService is planned for a later phase.")

    def get_columns(self, object_fqn: str) -> list[dict]:
        raise NotImplementedError("SnowflakeCatalogService is planned for a later phase.")

    def get_upstream_sources(self, object_fqn: str) -> list[str]:
        raise NotImplementedError("SnowflakeCatalogService is planned for a later phase.")
