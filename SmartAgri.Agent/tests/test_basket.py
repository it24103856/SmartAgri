from _suites import selected_suite


def load_tests(loader, tests, pattern):
    return selected_suite(loader, [
        (
            "test_optional_budget",
            "OptionalBudgetTests",
            [
                "test_missing_budget_and_single_short_product_name",
                "test_invalid_supplied_budgets_are_still_rejected",
                "test_list_without_budget_uses_requested_quantities_not_all_stock",
                "test_fixed_list_does_not_add_unrequested_eligible_products",
                "test_general_basket_without_budget_never_fills_stock",
                "test_mixed_basket_with_required_item_still_includes_other_products",
                "test_existing_budget_basket_still_fills_within_limit",
                "test_requested_quantities_must_fit_supplied_budget_and_stock",
            ],
        ),
        (
            "test_basket_editing",
            "BasketEditingTests",
            [
                "test_editing_includes_unselected_eligible_products_and_exclusions",
                "test_failed_response_has_no_editing_choices",
            ],
        ),
    ])
