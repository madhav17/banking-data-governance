!source metadata/permissions.sql
!source metadata/01_create_governance_schemas.sql
!source metadata/02_create_tag_taxonomy.sql
!source metadata/03_create_tag_assignment.sql
!source metadata/04_seed_base_tag_assignments.sql
!source metadata/05_sync_cde_tags.sql
!source metadata/06_create_apply_tag_procedure.sql
!source metadata/07_apply_tags.sql
!source metadata/08_validate_tags.sql
!source metadata/09_create_metadata_harvest_procedure.sql
!source metadata/10_validate_metadata_harvest.sql
!source metadata/11_create_metadata_harvest_task.sql
!source metadata/12_validate_metadata_harvest_task.sql
!source metadata/13_load_data_dictionary.sql
!source metadata/14_validate_data_dictionary.sql
!source metadata/15_create_apply_dictionary_comments_procedure.sql
!source metadata/16_apply_dictionary_comments.sql
!source metadata/17_validate_description_coverage.sql
!source metadata/18_seed_banking_glossary.sql
!source metadata/19_link_glossary_columns.sql
!source metadata/20_validate_banking_glossary.sql
!source metadata/21_seed_cde_registry.sql
!source metadata/22_validate_cde_registry.sql
-- Re-synchronize the newly populated CDE registry into desired tag state.
!source metadata/05_sync_cde_tags.sql
-- Deploy the new CDE / owner / steward assignments.
!source metadata/07_apply_tags.sql
!source metadata/23_validate_cde_tags.sql
!source metadata/24_validate_metadata_foundation.sql
-- run after once mart layer is created
--!source metadata/25_seed_mart_tag_assignments.sql
--!source metadata/07_apply_tags.sql
--!source metadata/26_verify_mart_metadata.sql