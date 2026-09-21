import streamlit as st

from components.column_table import render_column_table
from components.header import render_header
from components.object_summary import render_object_summary
from components.status_cards import render_governance_cards, render_operational_status
from services.catalog_service import SnowflakeCatalogService


SCORECARD_DETAILS = {
    "OWNED": {
        "evidence": "Owner and steward metadata from GOVERNANCE.TAGS and the catalog view.",
        "passing": "Every catalog object in scope has both DATA_OWNER and DATA_STEWARD.",
        "gap_action": "Apply or repair owner/steward tag assignments for the affected object.",
    },
    "DEFINED": {
        "evidence": "Object and column comments exposed through ANALYTICS.INFORMATION_SCHEMA.",
        "passing": "Every catalog column in scope has a non-empty approved description.",
        "gap_action": "Add missing column comments through the metadata dictionary/comment process.",
    },
    "TRACEABLE": {
        "evidence": "Latest native lineage snapshot in GOVERNANCE.CATALOG.LINEAGE_EDGE.",
        "passing": "Certified marts have upstream lineage evidence.",
        "gap_action": "Run the lineage snapshot scripts and confirm GET_LINEAGE reaches upstream sources.",
    },
    "TRUSTED": {
        "evidence": "Latest six-dimension results in GOVERNANCE.DQ.DQ_RESULT.",
        "passing": "All six DQ dimensions pass for each evaluated certified mart.",
        "gap_action": "Run the DQ block and remediate any failed or missing quality dimension.",
    },
    "SECURE": {
        "evidence": "Confirmed classification plus active masking policy coverage.",
        "passing": "Every confirmed sensitive column in scope has required protection coverage.",
        "gap_action": "Review confirmed classification tags and rerun the protection gap report.",
    },
    "ADOPTED": {
        "evidence": "ACCESS_HISTORY and QUERY_HISTORY usage summarized in the catalog view.",
        "passing": "Published certified objects have at least one observed usage event.",
        "gap_action": "Query the published object or wait for ACCOUNT_USAGE latency to clear.",
    },
    "RECONCILED": {
        "evidence": "ACCURACY / GL reconciliation result in GOVERNANCE.DQ.DQ_RESULT.",
        "passing": "The reconciliation check passes within the implemented $1 tolerance.",
        "gap_action": "Inspect the ACCURACY DQ result and compare mart balances to GL control totals.",
    },
}


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


def render_scorecard(service: SnowflakeCatalogService) -> None:
    st.subheader("Governance Scorecard")
    st.caption(
        "Seven governance dimensions scored from live Snowflake metadata and evidence. "
        "A dimension passes only when its numerator equals its denominator and the denominator is greater than zero."
    )

    try:
        scorecard = service.get_scorecard()
    except Exception as exc:
        st.error("Unable to load GOVERNANCE.CATALOG.CATALOG_SCORECARD.")
        st.caption(
            "Run scorecard/00_create_catalog_scorecard_view.sql and "
            "scorecard/01_validate_scorecard.sql, then refresh the app."
        )
        st.exception(exc)
        return

    if not scorecard:
        st.info("No scorecard rows found. Run scorecard/00_create_catalog_scorecard_view.sql.")
        return

    total_dimensions = len(scorecard)
    passing_dimensions = sum(1 for row in scorecard if row.get("STATUS") == "PASS")
    gap_dimensions = total_dimensions - passing_dimensions
    average_score = round(
        sum(float(row.get("SCORE_PCT") or 0) for row in scorecard) / total_dimensions,
        2,
    )

    total_col, pass_col, gap_col, avg_col = st.columns(4)
    total_col.metric("Dimensions", total_dimensions)
    pass_col.metric("Passing", passing_dimensions)
    gap_col.metric("Gaps", gap_dimensions)
    avg_col.metric("Average Score", f"{average_score}%")

    detailed_rows = []
    for row in scorecard:
        dimension = str(row.get("DIMENSION") or "")
        details = SCORECARD_DETAILS.get(dimension, {})
        detailed_rows.append(
            {
                "Dimension": dimension,
                "Status": row.get("STATUS"),
                "Score %": row.get("SCORE_PCT"),
                "Numerator": row.get("NUMERATOR"),
                "Denominator": row.get("DENOMINATOR"),
                "Measures": row.get("DESCRIPTION"),
                "Evidence": details.get("evidence", "Defined in GOVERNANCE.CATALOG.CATALOG_SCORECARD."),
                "Gap Action": details.get("gap_action", "Inspect the scorecard validation SQL."),
            }
        )

    st.dataframe(
        detailed_rows,
        use_container_width=True,
        hide_index=True,
        column_config={
            "Dimension": "Dimension",
            "Status": "Status",
            "Score %": st.column_config.NumberColumn("Score %", format="%.2f"),
            "Numerator": "Numerator",
            "Denominator": "Denominator",
            "Measures": "Measures",
            "Evidence": "Evidence",
            "Gap Action": "Gap Action",
        },
    )

    with st.expander("Dimension Details", expanded=True):
        for row in scorecard:
            dimension = str(row.get("DIMENSION") or "")
            details = SCORECARD_DETAILS.get(dimension, {})

            st.markdown(f"**{dimension}**")
            score_col, ratio_col, status_col = st.columns(3)
            score_col.metric("Score", f"{row.get('SCORE_PCT')}%")
            ratio_col.metric("Coverage", f"{row.get('NUMERATOR')} / {row.get('DENOMINATOR')}")
            status_col.metric("Status", row.get("STATUS"))

            st.write(row.get("DESCRIPTION"))
            st.caption(f"Evidence: {details.get('evidence', 'Scorecard view evidence')}")
            st.caption(f"Passing condition: {details.get('passing', 'Numerator equals denominator')}")

            if row.get("STATUS") != "PASS":
                st.warning(details.get("gap_action", "Inspect the scorecard validation SQL."))


def matches_certification_filter(row: dict, selected_filter: str) -> bool:
    certification = str(row.get("certification") or "").strip().upper()

    if selected_filter == "All":
        return True

    if selected_filter == "Certified":
        return certification == "CERTIFIED"

    return certification != "CERTIFIED"


def matches_classification_filter(row: dict, selected_filter: str) -> bool:
    classification = str(row.get("classification") or "").strip().upper()
    is_classified = classification not in ("", "NOT CLASSIFIED", "NOT AVAILABLE")

    if selected_filter == "All":
        return True

    if selected_filter == "Classified":
        return is_classified

    return not is_classified


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

    catalog_tab, scorecard_tab = st.tabs(["Data Catalog", "Governance Scorecard"])

    with catalog_tab:
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
            ["All", "Certified", "Not Certified"],
        )
        classification_filter = filter_col_4.selectbox(
            "Classification",
            ["All", "Classified", "Not Classified"],
        )

        filtered_results = [
            row
            for row in search_results
            if (database_filter == "All" or row["database"] == database_filter)
            and (schema_filter == "All" or row["schema"] == schema_filter)
            and matches_certification_filter(row, certification_filter)
            and matches_classification_filter(row, classification_filter)
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

    with scorecard_tab:
        render_scorecard(service)


if __name__ == "__main__":
    main()
