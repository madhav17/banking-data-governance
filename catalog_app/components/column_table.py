import streamlit as st


def render_column_table(columns: list[dict]) -> None:
    st.subheader("Columns")
    st.dataframe(
        columns,
        use_container_width=True,
        hide_index=True,
        column_config={
            "column_name": "Column Name",
            "data_type": "Data Type",
            "description": "Description",
            "cde_flag": "CDE",
            "classification": "Classification",
        },
    )
