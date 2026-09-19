import streamlit as st

from components.column_table import render_column_table
from components.header import render_header
from components.object_summary import render_object_summary
from components.status_cards import render_governance_cards, render_operational_status
from services.mock_catalog_service import MockCatalogService


def get_catalog_service() -> MockCatalogService:
    return MockCatalogService()


def render_search_results(search_results: list[dict]) -> None:
    if not search_results:
        st.info("No matching objects found.")
        return

    st.caption(f"{len(search_results)} object(s) found in mock catalog data.")
    st.dataframe(
        search_results,
        use_container_width=True,
        hide_index=True,
        column_config={
            "object_fqn": "Object",
            "object_name": "Name",
            "schema": "Schema",
            "domain": "Domain",
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

    service = get_catalog_service()
    render_header()

    search_query = st.text_input(
        "Search catalog",
        placeholder="Search by table, column, description, or domain",
    )
    search_results = service.search_objects(search_query)

    with st.expander("Search Results", expanded=bool(search_query)):
        render_search_results(search_results)

    selectable_objects = [result["object_fqn"] for result in service.search_objects("")]

    selected_object = st.selectbox(
        "Object",
        selectable_objects,
        help="Select an example STAGING object from the mock catalog.",
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
