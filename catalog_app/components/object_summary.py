import streamlit as st


def render_object_summary(details: dict) -> None:
    st.subheader("Object Summary")

    database_col, schema_col, object_col, type_col, domain_col = st.columns(5)
    database_col.metric("Database", details["database"])
    schema_col.metric("Schema", details["schema"])
    object_col.metric("Object", details["object_name"])
    type_col.metric("Type", details["object_type"])
    domain_col.metric("Domain", details["domain"])

    st.markdown("**Description**")
    st.write(details["description"])
