from _suites import selected_suite


def load_tests(loader, tests, pattern):
    return selected_suite(loader, [
        (
            "test_basket_fallback",
            "LocalFallbackTests",
            [
                "test_local_review_recomputes_selection_and_does_not_auto_accept",
                "test_local_review_rejects_wrong_prices_and_over_budget_total",
            ],
        ),
        (
            "test_basket_fallback",
            "ProviderFallbackTests",
            [
                "test_failure_at_any_model_stage_preserves_a_valid_partial_basket",
                "test_invalid_model_output_is_not_trusted",
                "test_fallback_still_enforces_budget",
                "test_all_missing_has_no_orderable_items",
                "test_complex_request_gets_honest_failure_without_fabricated_data",
            ],
        ),
        (
            "test_optional_budget",
            "PartialProposalTests",
            [
                "test_available_items_survive_missing_item_with_or_without_budget",
                "test_all_missing_has_notices_and_no_orderable_proposal",
                "test_insufficient_stock_notice_does_not_replace_requested_product",
            ],
        ),
    ])
