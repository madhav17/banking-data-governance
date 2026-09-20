import streamlit as st

from components.column_table import render_column_table
from components.header import render_header
from components.object_summary import render_object_summary
from components.status_cards import render_governance_cards, render_operational_status
from services.catalog_service import SnowflakeCatalogService


@st.cache_resource
def get_catalog_service() -> SnowflakeCatalogService:
    from snowflake.snowpark.context import get_active_session

    return SnowflakeCatalogService(get_active_session())


def render_search_results(search_results: list[dict]) -> None:
    if not search_results:
        st.info("No matching objects found.")
        return

    st.caption(f"{len(search_results)} object(s) found in governance catalog metadata.")
    st.dataframe(
        search_results,
        use_container_width=True,
        hide_index=True,
        column_config={
            "object_fqn": "Object",
            "object_name": "Name",
            "database": "Database",
            "schema": "Schema",
            "domain": "Domain",
            "certification": "Certification",
            "classification": "Classification",
            "quality_result": "Quality",
            "cde_columns": "CDE Columns",
            "description": "Description",
        },
    )


def render_upstream_sources(upstream_sources: list[str]) -> None:
    st.subheader("Upstream Sources")

    if not upstream_sources:
        st.write("NOT AVAILABLE")
        return

    for source in upstream_sources:
        st.markdown(f"- `{source}`")


def main() -> None:
    st.set_page_config(page_title="Avidia Data Catalog", layout="wide")

    render_header()

    try:
        service = get_catalog_service()
        all_objects = service.search_objects("")
    except Exception as exc:
        st.error("Unable to load GOVERNANCE.CATALOG.V_STREAMLIT_CATALOG.")
        st.caption(
            "Run catalog_app/sql/00_permissions.sql and "
            "catalog_app/sql/01_create_catalog_view.sql, then redeploy the app."
        )
        st.exception(exc)
        st.stop()

    search_query = st.text_input(
        "Search catalog",
        placeholder="Search by table, column, description, or domain",
    )

    search_results = service.search_objects(search_query)

    filter_col_1, filter_col_2, filter_col_3, filter_col_4 = st.columns(4)
    database_filter = filter_col_1.selectbox(
        "Database",
        ["All"] + sorted({row["database"] for row in all_objects}),
    )
    schema_filter = filter_col_2.selectbox(
        "Schema",
        ["All"] + sorted({row["schema"] for row in all_objects}),
    )
    certification_filter = filter_col_3.selectbox(
        "Certification",
        ["All"] + sorted({row["certification"] for row in all_objects}),
    )
    classification_filter = filter_col_4.selectbox(
        "Classification",
        ["All"] + sorted({row["classification"] for row in all_objects}),
    )

    filtered_results = [
        row
        for row in search_results
        if (database_filter == "All" or row["database"] == database_filter)
        and (schema_filter == "All" or row["schema"] == schema_filter)
        and (certification_filter == "All" or row["certification"] == certification_filter)
        and (classification_filter == "All" or row["classification"] == classification_filter)
    ]

    with st.expander("Search Results", expanded=bool(search_query)):
        render_search_results(filtered_results)

    selectable_objects = [result["object_fqn"] for result in filtered_results]
    if not selectable_objects:
        st.info("No objects match the current search and filters.")
        st.stop()

    selected_object = st.selectbox(
        "Object",
        selectable_objects,
        help="Select a governed MART object from the live catalog view.",
    )

    details = service.get_object_details(selected_object)
    columns = service.get_columns(selected_object)
    upstream_sources = service.get_upstream_sources(selected_object)

    st.divider()
    render_object_summary(details)

    st.divider()
    render_governance_cards(details)
    render_operational_status(details)

    st.divider()
    render_column_table(columns)

    st.divider()
    render_upstream_sources(upstream_sources)


if __name__ == "__main__":
    main()
