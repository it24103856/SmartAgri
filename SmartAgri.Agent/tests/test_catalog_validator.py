from _suites import selected_suite


def load_tests(loader, tests, pattern):
    return selected_suite(loader, [
        (
            "test_basket_fallback",
            "LocalFallbackTests",
            [
                "test_basket_agents_have_explicit_workflow_categories",
                "test_extra_separators_do_not_reject_a_valid_list",
                "test_empty_list_is_still_rejected",
                "test_logged_shopping_list_uses_catalog_ids_and_reports_cabbage",
                "test_explicit_selling_units_and_insufficient_stock",
                "test_ambiguous_constraints_or_quantities_never_become_success",
                "test_does_not_guess_weight_to_pack_or_multiple_catalog_matches",
                "test_explicit_exclusions_and_unapproved_products_are_not_selected",
            ],
        ),
        (
            "test_optional_budget",
            "OptionalBudgetTests",
            [
                "test_validator_enforces_stock_exclusions_and_optional_budget",
                "test_missing_items_do_not_bypass_unknown_id_or_exclusion_checks",
            ],
        ),
        (
            "test_optional_budget",
            "PartialProposalTests",
            [
                "test_selection_json_schema_keeps_numeric_ids_and_disables_afc",
                "test_sdk_sends_json_schema_on_the_wire",
            ],
        ),
    ])
