import streamlit as st


def render_governance_cards(details: dict) -> None:
    st.subheader("Governance")

    owner_col, steward_col, cert_col, cde_col, class_col = st.columns(5)
    owner_col.metric("Owner", details["owner"])
    steward_col.metric("Steward", details["steward"])
    cert_col.metric("Certification", details["certification"])
    cde_col.metric("CDE", details["cde"])
    class_col.metric("Classification", details["classification"])


def render_operational_status(details: dict) -> None:
    st.subheader("Operational Status")

    refresh_col, dq_col, usage_col, roles_col = st.columns(4)
    refresh_col.metric("Last Refresh", details["last_refresh"])
    dq_col.metric("Quality Status", details["quality_status"])
    usage_col.metric("Usage / Queries", details["usage_query_count"])
    roles_col.metric("Distinct Roles", details["distinct_roles"])
